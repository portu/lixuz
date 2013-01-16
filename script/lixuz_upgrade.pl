#!/usr/bin/perl
use strict;
use warnings;
use File::Copy;
use Fatal qw(open opendir);
use File::Path qw(mkpath rmtree);
use File::Temp qw(tempdir);
use File::Basename qw(dirname);
use File::stat;
use Cwd qw(realpath);
use Getopt::Long;
use Config::Any;

use constant {
    true => 1,
    false => undef,
};

my %upgradePaths = (
);

my %upgradeVersions = (
);

my $chained = false;
my $prevLen = 0;
my $prevIprintText = '';
my $logfile = './lixuzUpgrade.log';
my $loghandle;
my $origDataBackup;
my $installTarget;
my $performingRestoration = false;

GetOptions(
    'chained' => \$chained,
    'logfile=s' => \$logfile,
) or die();

if (@ARGV > 1)
{
    print "Running in multi-install mode. Will do one full pass over each supplied\n";
    print "installation\n";
    foreach my $inst (@ARGV)
    {
        print "\n";
        print "---- $inst : ----\n";
        system($0,'--chained',$inst);
    }
    exit(0);
}

if (@ARGV == 0)
{
    die('Requires at least one argument: Path to an existing Lixuz installation that you want to upgrade'."\n");
}

main(@ARGV);

# ---
# Core functions
# ---

# Summary: Main body
sub main
{
    $| = 1;
    my $dataTarget = shift;
    my $oTarget = $dataTarget;
    my $dataLocation = locateInstallData();
    startLog($dataTarget,$dataLocation);
    my $tempDir = getTempDir(undef,'Merge location');
    $dataTarget = realpath($dataTarget);
    $installTarget = $dataTarget;
    preUpgradeSanity($dataLocation,$dataTarget,$oTarget);
    my $oldVer = getLixuzVersion($installTarget);
    my $newVer = getLixuzVersion($dataLocation);
    if ($oldVer eq $newVer)
    {
        dualPrint("$installTarget: is the same version ($oldVer) as it is being upgraded to\n");
        dualPrint("Assuming git snapshot update.\n");
    }
    else
    {
        dualPrint("Upgrading $installTarget from Lixuz version $oldVer to $newVer\n");
    }
    my $packup = getTempDir(undef,'Package packup directory');
    if (-x $installTarget.'/tools/lixuzctl')
    {
        print 'Repackaging installed packages...';
        if(lixuzctl($installTarget,'packup',$packup) == 0)
        {
            print "done\n";
            logAction('Repackaged packages');
        }
        else
        {
            print "no packages found\n";
            logAction('Installation has no packages');
            $packup = undef;
        }
    }
    else
    {
        dualPrint('(upgrading from packageless Lixuz, skipping package tasks)'."\n");
        $packup = undef;
    }
    createMergeDirectory($dataLocation,$tempDir);
    mergeData($tempDir,$dataTarget);
    backupOldData($dataTarget);
    installNewData($tempDir,$dataTarget);
    upgradeConfig($dataTarget);
    print 'Running lixuzctl upgrade..';
    lixuzctl($installTarget,'upgrade');
    print "done\n";
    if ($packup)
    {
        print 'Re-injecting packages...';
        my @packages = ( glob($packup.'/*.lpp'), glob($packup.'/*.lpk') );
        if(lixuzctl($installTarget,'reinject',@packages) == 0)
        {
            print "done\n";
        }
        else
        {
            print "error\n";
            move(@packages,$installTarget);
            dualPrint("Something went wrong during re-injection of packages\n");
            dualPrint("You may wish to check the logfile for errors.\n");
            dualPrint("The packages have all been moved to $installTarget\n");
            dualPrint("for manual processing\n\n");
        }
    }
    dualPrint("All is done and appears to have gone well.\n\n");
    dualPrint("Note that you may need to upgrade the database. The recommended way to do this\n");
    dualPrint("is to stop the FastCGI instance, run the sql/upgradeDB script from the installed\n");
    dualPrint("Lixuz tree, and then start the FastCGI instance again.\n");
    exit(0);
}

# Summary: Copy new data to replace old data
sub installNewData
{
    my $new = shift;
    my $target = shift;
    print "Removing old files...";
    logAction('Recursively removing '.$target);
    rmtree($target);
    mkpath($target);
    print "done\n";
    print "Installing upgraded Lixuz files...";
    logAction('Copying new Lixuz installation files to '.$target);
    copyRecursive($new,$new,$target,true);
    iprint('');
    print "done\n";
}

# Summary: Run the config file upgrader
sub upgradeConfig
{
    my $target = shift;
    my $conf = $target.'/lixuz.yml';
    if(not -e $conf)
    {
        logAction('upgradeConfig(): Very confused, '.$conf.' doesn\'t exist. No clue what to do, giving up.');
        iDie('Unknown error: '. $conf .' is missing!');
    }
    my @command = ($target.'/script/upgradeConfig',$conf,$conf.'.tpl');
    logAction('Will now run the following command to upgrade the config file: system(\''.join('\',\'',@command).'\')');
    my $r = system(@command);
    if ($r != 0)
    {
        iDie('Config file upgrade failed');
    }
}

# Summary: Create a backup of the old data
sub backupOldData
{
    my $path = shift;
    $origDataBackup = getTempDir('lixuz_upgrade_origdata','Backup of the old install');
    logAction('Creating backup of old install (to '.$origDataBackup.')');
    print "Backing up old install...";
    copyRecursive($path,$path,$origDataBackup,true);
    iprint('');
    print "done\n";
}

# Summary: Locate the installation data that we are being run from
sub locateInstallData
{
    my $path = dirname(realpath($0));
    if(_isLixuzDataDir($path))
    {
        return $path;
    }
    $path = realpath($path.'/../');
    if(_isLixuzDataDir($path))
    {
        return $path;
    }
    $path = getcwd();
    if(_isLixuzDataDir($path))
    {
        return $path;
    }
    $path = realpath($path.'/../');
    if(_isLixuzDataDir($path))
    {
        return $path;
    }
    iDie('Failed to locate new Lixuz data directory.');
}

# Summary: Checks if the path supplied is a Lixuz data dir
sub _isLixuzDataDir
{
    my $dir = shift;
    if (-e $dir.'/lixuz.yml.tpl' && -e $dir.'/lib/LIXUZ')
    {
        return true;
    }
    return false;
}

# Summary: Copy data to a temporary merge directory
sub createMergeDirectory
{
    my ($source,$target) = @_;
    logAction('Creating merge directory from "'.$source.'" at "'.$target.'"');
    print "Creating merge directory... ";
    copyRecursive($source,$source,$target);
    iprint('');
    print "done\n";
}

# Summary: Merge old data with new data
sub mergeData
{
    my($newData,$oldData) = @_;
    logAction('Beginning merge of installation settings from '.$oldData.' to '.$newData);
    print "Copying SiteHacks*, config and live data...";
    if (-e $oldData.'/lib/LIXUZ/Controller/SiteHacks.pm')
    {
        logAction('Copying '.$oldData.'/lib/LIXUZ/Controller/SiteHacks.pm');
        copyFile($oldData, $oldData.'/lib/LIXUZ/Controller/SiteHacks.pm', $newData.'/lib/LIXUZ/Controller/SiteHacks.pm');
    }
    if (-d $oldData.'/lib/LIXUZ/Controller/SiteHacks')
    {
        logAction('Copying SiteHacks directory (from '.$oldData.'/lib/LIXUZ/Controller/)');
        mkpath($newData.'/lib/LIXUZ/Controller/SiteHacks');
        copyRecursive($oldData,$oldData.'/lib/LIXUZ/Controller/SiteHacks',$newData.'/lib/LIXUZ/Controller/SiteHacks');
    }
    if (-e $oldData.'/root/livedata')
    {
        logAction('Copying livedata directory (from '.$oldData.'/root/livedata)');
        mkpath($newData.'/root/livedata');
        copyRecursive($oldData,$oldData.'/root/livedata',$newData.'/root/livedata');
    }
    copyFile($oldData, $oldData.'/lixuz.yml',$newData.'/lixuz.yml');
    iprint('');
    print "done\n";
}

# Summary: Get a Lixuz version number from a directory
sub getLixuzVersion
{
    my $dir = shift;
    if(not -r $dir.'/lib/LIXUZ.pm')
    {
        iDie('Unable to locate or read lib/LIXUZ.pm in dir '.$dir);
    }
    open(my $i,'<',$dir.'/lib/LIXUZ.pm');
    my $v;
    while(<$i>)
    {
        if(not /my\s*\$VERSION_NO\s*=\s*/)
        {
            next;
        }
        $v = $_;
        last;
    }
    if(not $v)
    {
        iDie('Unable to locate version number from '.$dir);
    }
    chomp($v);
    $v =~ s/.*my\s+[^=]+=\s*//;
    $v =~ s/^\s+//g;
    $v =~ s/\s*;*\s*$//g;
    $v =~ s/^['"]*(.+)['"]$/$1/g;
    return $v;
}

# Summary: Pre-upgrade sanity check
sub preUpgradeSanity
{
    # NOTE: This sub is the only one that should use die() instead of iDie().
    my ($dataSource,$dataTarget,$origSuppliedTarget) = @_;
    my $sanityFailure = 'Pre-upgrade sanity check failed: ';
    my $die = 'failed. Please check the logfile for more information.';
    dualPrint("Running pre-upgrade sanity check...");
    if(not defined $dataSource or not length $dataSource)
    {
        logAction($sanityFailure.' dataSource is missing');
        die($die);
    }
    if(not defined $dataTarget or not length $dataTarget)
    {
        if(not -e $origSuppliedTarget)
        {
            logAction($sanityFailure.$origSuppliedTarget.': does not exist');
            die('failed. '.$origSuppliedTarget.': does not exist');
        }
        logAction($sanityFailure.' dataTarget is missing');
        die($die);
    }
    if(not -r $dataSource)
    {
        logAction($sanityFailure.$dataSource.': missing read permission');
        die($die);
    }
    if(not -r $dataTarget)
    {
        logAction($sanityFailure.$dataTarget.': missing read permission');
        die($die);
    }
    if(not -w $dataTarget)
    {
        logAction($sanityFailure.$dataTarget.': missing write permission');
        die($die);
    }
    if(not -r $dataSource)
    {
        logAction($sanityFailure.$dataSource.': is not a directory');
        die($die);
    }
    if(not -d $dataTarget)
    {
        logAction($sanityFailure.$dataTarget.': is not a directory');
        die($die);
    }
    if(not -e $dataTarget.'/lixuz.yml')
    {
        logAction($sanityFailure.$dataTarget.': no lixuz.yml file. Does not look like a Lixuz install.');
        die($die);
    }
    if(not -w $dataTarget.'/lixuz.yml')
    {
        logAction($sanityFailure.$dataTarget.': lixuz.yml is not writable. Confused and refusing to continue.');
        die($die);
    }
    if(not -e $dataTarget.'/lib/LIXUZ.pm')
    {
        logAction($sanityFailure.$dataTarget.': no lib/LIXUZ.pm file. Does not look like a Lixuz install.');
        die($die);
    }
    if(not -e $dataTarget.'/root')
    {
        logAction($sanityFailure.$dataTarget.': no root/ directory. Does not look like a Lixuz install.');
        die($die);
    }
    if (-e $dataTarget.'/.git')
    {
        logAction($sanityFailure.$dataTarget.': looks like a git repository');
        logAction('Refusing to process git repository. Any changes that have not been pushed upstream or only exists in the working tree would have been lost');
        logAction('If this is really what you want to do, remove the .git directory and then re-run this script.');
        die('failed. '.$dataTarget.': looks like a git repository. See the logfile for more information'."\n");
    }
    print "done - everything looks good.\n";
    logAction('Pre-upgrade sanity check successful. Everything looks good');
}

# Summary: Attempt to restore the system back to how it was before the upgrade
sub checkRestoreInstall
{
    $performingRestoration = true;
    my $changeMade = 0;
    logAction('A fatal error has occurred - restoration of previous install requested');
    print "Failure.\n";
    print "Something went very wrong, will now attempt to restore old setup.\n";
    if ($origDataBackup and -e $origDataBackup)
    {
        print "Removing upgraded files...";
        logAction('Recursively removing '.$installTarget);
        rmtree($installTarget);
        mkpath($installTarget);
        print "done\n";
        print "Installing old files...";
        logAction('Copying old files to '.$installTarget);
        copyRecursive($origDataBackup,$origDataBackup,$installTarget,true);
        iprint('');
        print "done\n";
        $changeMade = true;
    }
    elsif ($origDataBackup)
    {
        print "FATAL: THE BACKUP OF THE OLD INSTALL HAS DISAPPEARED!\n";
        print "LIXUZ WILL USE THE NEW DATA, THIS MAY NOT WORK.\n";
        $changeMade = true;
    }
    else
    {
        logAction('Looks like we did not make it as far as to install upgrades, not restoring backup data.');
        print "Looks like we did not make any changes, no restoration appears to be needed.\n";
    }
    if ($changeMade)
    {
        logAction('Some restoration action has been run.');
        print "You will want to study the logfile at $logfile\n";
    }
    else
    {
        logAction('Nope, no changes at all were made. All is well');
    }
}

# ---
# Various helper and wrapper functions
# ---


# Summary: Run a lixuzctl command
# Usage: lixuzctl(/lixuz/path,plumbingCommand,args);
# This wraps lixuzctl. It will check which version of the lixuzctl api we're
# dealing with, and adapt which parameters are used to fit that version.
sub lixuzctl
{
    return _lixuzctl(undef,@_);
}

# Summary: Run a lixuzctl command
# Usage: _lixuzctl(pathToBinary,/lixuz/path,plumbingCommand,args);
# This wraps lixuzctl. It will check which version of the lixuzctl api we're
# dealing with, and adapt which parameters are used to fit that version.
#
# Should never be called directly.
sub _lixuzctl
{
    my $pathToBinary = shift;
    my $lixuzPath = shift;
    my $command = shift;
    my @params;

    if (!defined($pathToBinary))
    {
        $pathToBinary = $lixuzPath.'/tools/lixuzctl';
    }

    my ($apilevel,$minapilevel);

    open(my $apiIN,'-|',$pathToBinary,qw(plumbing getlevel));
    my $apiinfo = <$apiIN>;
    close($apiIN);
    no warnings;
    $apilevel = int($apiinfo);
    use warnings;
    $apilevel ||= 1;
    if ($apilevel >= 3)
    {
        $apilevel = $apiinfo;
        $minapilevel = $apiinfo;

        $apilevel =~ s{^(\d+)/.+$}{$1};
        $minapilevel =~ s{^\d+/(\d+)(\D+.*)?}{$1};
        $apilevel = int($apilevel);
        $minapilevel = int($minapilevel);
    }

    # Versions of lixuzctl with an API level below 3 are known to be buggy, so
    # we execute our own instead.
    if ($apilevel < 3)
    {
        logAction('Lixuzctl in target tree is too old (apilevel '.$apilevel.'), using our shipped version instead');
        return _lixuzctl(locateInstallData().'/tools/lixuzctl',$lixuzPath,$command,@_);
    }

    push(@params,'v'.$apilevel,
        '--logfile',$logfile,
        '--lixuzdir',$lixuzPath,
        qw(--lixuz-upgrade --quiet),
    );

    my @command = ($pathToBinary,'plumbing',@params,$command,@_);
    logAction('Running lixuzctl action: '.join(' ',@command));
    return system(@command);
}

# Summary: Open the logfile and output initial messages
sub startLog
{
    my($dataTarget,$dataLocation) = @_;
    my $existed = false;
    $logfile = realpath($logfile);
    if (-e $logfile)
    {
        $existed = true;
    }
    open($loghandle,'>>',$logfile);
    if ($existed)
    {
        print {$loghandle} "\n";
    }
    print "Logging to $logfile\n";
    logAction('Starting Lixuz upgrade of installation located at '.$dataTarget);
    logAction('Data source is '.$dataLocation);
    logAction('Running as uid '.$>);
    if ($chained)
    {
        logAction('Running in chained mode');
    }
}

# Summary: Get a suitable temporary directory, and log its creation
sub getTempDir
{
    my $name = shift;
    my $purpose = shift;
    $name = $name ? $name : 'lixuz_upgrade';
    my $d = tempdir($name.'.XXXXXXXXXXX', CLEANUP => true, TMPDIR => true);
    logAction('Created temporary directory "'.$d.'". Purpose: '.$purpose);
    return $d;
}

# Summary: Safe die() wrapper. Will call cehckRestoreInstall() before exiting.
sub iDie
{
    my $message = shift;
    logAction($message);
    if ($performingRestoration)
    {
        warn($message);
        return;
    }
    checkRestoreInstall();
    if ($chained)
    {
        warn($message);
        print "(chained mode - press enter to continue)\n";
        <STDIN>;
        exit(1);
    }
    else
    {
        die($message);
    }
}

# Summary: Recursively copy a tree
sub copyRecursive
{
    my $baseSource = shift;
    my $source = shift;
    my $target = shift;
    my $disableSkipping = shift;
    opendir(my $sd,$source);
    while(my $f = readdir($sd))
    {
        if ($f eq '.' or
            $f eq '..' or
            $f eq '.git')
        {
            next;
        }
        if(not $disableSkipping)
        {
            if (
                $f =~ /~$/ or
                $f =~ /\.(swp)$/ or
                $f =~ /livedummy\.sql/ or
                $f =~ /lixuz-dbupgrade-dump.*sql/
            )
            {
                next;
            }
        }

        if (-d $source.'/'.$f)
        {
            my $nice = $source;
            $baseSource =~ s{/+}{/}g;
            $nice =~ s{/+}{/}g;
            $nice =~ s{^$baseSource/?}{}g;
            iprint('creating: '.$nice);
            mkpath($target.'/'.$f);
            copyRecursive($baseSource,$source.'/'.$f,$target.'/'.$f,$disableSkipping);
        }
        else
        {
            copyFile($baseSource,$source.'/'.$f,$target.'/'.$f);
        }
    }
}

# Summary: Copy a single file
sub copyFile
{
    my ($baseSource,$source,$target) = @_;
    my $nice = $source;
    if ($baseSource)
    {
        $baseSource =~ s{/+}{/}g;
        $nice =~ s{/+}{/}g;
        $nice =~ s{^$baseSource/?}{}g;
    }
    iprint('copying: '.$nice);
    $| = 1;
    my $st = stat($source);
    copy($source,$target) or iDie("FATAL: Failed to copy($source,$target): $!\n");
    if ($st)
    {
        chmod($st->mode,$target);
    }
    else
    {
        logAction('Strange, stat('.$source.') appears to have failed, no $st');
    }
}

# Summary: A print that removes previous text before printing. Used for status Information messages.
sub iprint
{
    my $data = shift;
    if ($data eq $prevIprintText)
    {
        return;
    }
    $| = 0;
    if ($prevLen)
    {
        for(my $i = 0; $i < $prevLen; $i++)
        {
            print "\b \b";
        }
    }
    $prevLen = length($data);
    $prevIprintText = $data;
    print $data;
    $| = 1;
    return;
}

# Log something
sub logAction
{
    my $msg = shift;
    my ($lsec,$lmin,$lhour,$lmday,$lmon,$lyear,$lwday,$lyday,$lisdst) = localtime(time());
    $lmon++;
    $lhour = "0$lhour" if not $lhour >= 10;
    $lmin = "0$lmin" if not $lmin >= 10;
    $lsec = "0$lsec" if not $lsec >= 10;
    $lmon = "0$lmon" if not $lmon >= 10;
    $lmday = "0$lmday" if not $lmday >= 10;
    $lyear += 1900;
    print {$loghandle} "[$lmday/$lmon/$lyear $lhour:$lmin:$lsec ($$)] ".$msg."\n";
}

# Both log and print to STDOUT
sub dualPrint
{
    my $msg = shift;
    print $msg;
    chomp($msg);
    logAction($msg);
}
