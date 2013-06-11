#!/usr/bin/perl
# TODO: Prompt for indexer language
use strict;
use warnings;
use Term::ReadLine;
use File::Copy;
use Fatal qw(open opendir);
use File::Path qw(mkpath);
use File::Basename qw(dirname basename);
use Cwd;
use DBI;
use Try::Tiny;
use 5.010;

use constant {
    true => 1,
    false => undef,
};

my $term = Term::ReadLine->new('lixuzinstall');
my $prevLen = 0;
my $prevIprintText = '';
my $stepNo = 0;
my $totalSteps = 0;
my $prevStatus = undef;
my @createUsers;

newStep('Welcome');
print "Welcome to the Lixuz installer. This script will help you create\n";
print "the initial Lixuz database along with the initial admin user, as well\n";
print "as creating a usable initial config file.\n\n";
print "Note that this is not an upgrade script, and you should use the separate\n";
print "lixuz_upgrade.pl script if you are upgrading an existing install.\n\n";
print "On some prompts you will see a value in [], that value is the default\n";
print "value for that prompt. Simply pressing enter is the same as entering that\n";
print "value\n\n";
print "Type //quit on any prompt to abort the installation\n\n";
print "Press enter to continue...";
while(1)
{
    my $in = <STDIN>;
    if ($in && $in =~ m{^\s*//})
    {
        promptCommand($in);
    }
    else
    {
        last;
    }
}
newStep('Advanced directory prompt');
print "First, the script needs to know if you want to use normal or advanced mode.\n";
print "Advanced configuration lets you manually change the paths of all\n";
print "Lixuz data directories. Normal configuration simply lets you set a\n";
print "primary path for the container of the data directory, then Lixuz will\n";
print "create the additional directories itself.\n";
print "\nIn general, the normal configuration is more than sufficient\n";
print "(and faster, as there are fewer questions)\n";
my $useAdv = getBool('Do you want to use advanced configuration?','No');
if ($useAdv)
{
    $totalSteps = 9+4;
}
else
{
    $totalSteps = 9;
}
my $path;

my %settings;
if (@ARGV)
{
    $settings{installPath} = shift(@ARGV);
    $stepNo++;
}
else
{
    newStep('Install directory');

    $settings{installPath} = getPath('Where do you want to install Lixuz?','Are you sure you want to install Lixuz there anyway?');
}

if ( -e $settings{installPath}.'/lixuz.yml')
{
    die($settings{installPath}.'/lixuz.yml: exists. Use lixuz_upgrade.pl if you want to upgrade an existing install.'."\n");
}

print "\n";
if($useAdv)
{
    my $instPath = $settings{installPath}.'/';
    $instPath =~ s{/+}{/}g;

    newStep('Advanced: File directory');
    while(1)
    {
        print "The Lixuz file directory must be outside of Lixuz' install path\n";
        $settings{file_path} = getPath('Where should Lixuz save its files?');
        $settings{file_path} =~ s{/+}{/}g;
        if ($settings{file_path} =~ /^$instPath/)
        {
            print "Invalid selection. ";
        }
        elsif(-e $settings{file_path})
        {
            print "$settings{file_path}: Already exists\n";
        }
        else
        {
            last;
        }
    }

    newStep('Advanced: Template directory');
    while(1)
    {
        print "The Lixuz template directory must be outside of Lixuz' install path\n";
        $settings{template_path} = getPath('Where should Lixuz save its templates?');
        $settings{template_path} =~ s{/+}{/}g;
        if ($settings{template_path} =~ /^$instPath/)
        {
            print "Invalid selection. ";
        }
        elsif($settings{template_path} =~ /^$settings{file_path}/)
        {
            print "Can not be shared with the files directory.\n";
        }
        elsif(-e $settings{template_path})
        {
            print "$settings{template_path}: Already exists\n";
        }
        else
        {
            last;
        }
    }

    newStep('Advanced: Temporary directory');
    while(1)
    {
        print "The Lixuz temporary directory must be outside of Lixuz' install path\n";
        $settings{temp_path} = getPath('Where should Lixuz save its temporary files?');
        $settings{temp_path} =~ s{/+}{/}g;
        if ($settings{temp_path} =~ /^$instPath/)
        {
            print "Invalid selection. ";
        }
        elsif($settings{temp_path} =~ /^$settings{file_path}/)
        {
            print "Can not be shared with the files directory.\n";
        }
        elsif($settings{temp_path} =~ /^$settings{template_path}/)
        {
            print "Can not be shared with the templates directory.\n";
        }
        elsif(-e $settings{temp_path})
        {
            print "$settings{temp_path}: Already exists\n";
        }
        else
        {
            last;
        }
    }

    newStep('Advanced: Indexer directory');
    while(1)
    {
        print "The Lixuz indexer directory must be outside of Lixuz' install path\n";
        $settings{indexFiles} = getPath('Where should Lixuz save its indexer files?');
        $settings{indexFiles} =~ s{/+}{/}g;
        if ($settings{indexFiles} =~ /^$instPath/)
        {
            print "Invalid selection. ";
        }
        elsif($settings{indexFiles} =~ /^$settings{file_path}/)
        {
            print "Can not be shared with the files directory.\n";
        }
        elsif($settings{indexFiles} =~ /^$settings{template_path}/)
        {
            print "Can not be shared with the templates directory.\n";
        }
		elsif($settings{indexFiles} =~ /^$settings{temp_path}/)
		{
			print "Can not be shared with the temporary files directory.\n";
		}
        elsif(-e $settings{indexFiles})
        {
            print "$settings{indexFiles}: Already exists\n";
        }
        else
        {
            last;
        }
    }
}
else
{
    newStep('Data directory');
    print "The Lixuz data directory must be outside of Lixuz' install path\n";
    my $coreData;
    my $default = '/var/lixuz.data/'.basename($settings{installPath});
    while(1)
    {
        $coreData = getPath('Where should Lixuz save its data?',undef,$default);
        $coreData .= '/';
        $coreData =~ s{/+}{/}g;
        my $instPath = $settings{installPath}.'/';
        $instPath =~ s{/+}{/}g;
        if ($coreData =~ /^$instPath/)
        {
            print "Must not be within the target install path.\n";
            next;
        }
        if (-e $coreData.'/files' || -e $coreData.'/templates' || -e $coreData.'/tmp')
        {
            print "$coreData: Is not empty.\n";
        }
        last;
    }
    $coreData =~ s{/+$}{}g;
    $settings{file_path} = $coreData.'/files';
    $settings{template_path} = $coreData.'/templates';
    $settings{temp_path} = $coreData.'/tmp';
	$settings{indexFiles} = $coreData.'/searchIndex';
}

newStep('Initial user');
print "Lixuz will create at least one initial administrative user that you can use\n";
print "to log in to Lixuz\n";
addUser();

# If we have a valid hostname, use that as a default for e-mail
my $defaultEmail;
my $hostname = $ENV{HOSTNAME};
if (not defined $hostname and eval('use Sys::Hostname;1;'))
{
    $hostname = hostname();
}
if(defined $hostname && $hostname =~ /\.\w+$/)
{
    $defaultEmail = 'lixuz@'.$hostname;
}

newStep('From e-mail');
print "Lixuz regulary sends e-mails to users for various reasons.\n";
my $email = getInput('What do you want to be the From: e-mail in emails sent by Lixuz?',$defaultEmail);
$settings{from_email} = $email;

my $dbsuccess = 0;
newStep('Database configuration');
print "WARNING: If there is any Lixuz data already in the database\n";
print "         you supply here, that data will be DELETED.\n";
print "         Please use caution (and backups).\n";
my($dbnam,$dbuser,$dbpwd) = (basename($settings{installPath}), undef,getRndPwd());
$dbnam =~ s/\W//g;
print "\nUse the following in a mysql console if you just want to create a new\nuser and database:\n";
print "CREATE DATABASE $dbnam; CREATE USER '$dbnam'\@'localhost' IDENTIFIED BY '$dbpwd';\n";
print "GRANT ALL ON $dbnam.* TO '$dbnam'\@'localhost;\n";
while(1)
{
    $dbnam = getInput('What is the name of the database Lixuz should use?',$dbnam);
    $dbuser //= $dbnam;
    $dbuser = getInput('What is the username for it?',$dbuser);
    $dbpwd = getInput('What is the password for it?',$dbpwd);

    print "Testing database connection...";
	my $fail = 0;
	eval
	{
        local *STDERR;
        local *STDOUT;
        open(STDERR,'>','/dev/null');
        open(STDOUT,'>','/dev/null');
        my $dbi = DBI->connect('dbi:mysql:dbname='.$dbnam,$dbuser,$dbpwd);
		if(not $dbi)
		{
			no warnings;
			$fail = $DBI::errstr;
		}
    };
	if ($@)
	{
		$fail = $@;
	}
	last if not $fail;
	print 'failed: '.$fail."\n\n";
}

newStep('Memcached configuration');
$settings{memcached} = getInput('What is the hostname:port that memcached listens to?','127.0.0.1:11211');
print "\n";
print "The memcached namespace is used so that keys are unique, and to ensure that\n";
print "there are no conflicts between Lixuz instances. A namespace MUST therefore\n";
print "be unique. A good name can for instance be the domain without the dot.\n";
print "Ie. example.org => exampleorg\n";
$settings{memcached_namespace} = getInput('What should the namespace be?');
newStep('Summary');
print "Lixuz is now ready to be installed. Please check that the following settings\n";
print "are correct.\n";
my $fmt = '%-32s : %s'."\n";
printf($fmt,'Install path',$settings{installPath});
printf($fmt,'Uploaded file storage',$settings{file_path});
printf($fmt,'Template storage',$settings{template_path});
printf($fmt,'Various semi-temporary storage',$settings{temp_path});
printf($fmt,'Database string','dbi:mysql:dbname='.$dbnam);
printf($fmt,'Database user',$dbuser);
if(not getBool('Are these correct?'))
{
    print "Aborting.\n";
    exit(0);
}

newStep('Installing and configuring');

copyRecursive(cwd(), cwd(),$settings{installPath});
iprint('');
print "Copying...done\n";
print "Configuring...";
createConfigFile();
print "done - wrote $settings{installPath}/lixuz.yml\n";
print "Creating database (might take a little while)...";
mysql_exec('source '.$settings{installPath}.'/sql/lixuz_schema.sql',true);
print "done\n";
chdir($settings{installPath});
push(@INC,$settings{installPath}.'/lib');
print "Creating data directories: ";
foreach my $d (qw(file_path template_path temp_path))
{
	print "$d ";
	mkpath($settings{$d});
}
print "\b\n";
print "Initializing Lixuz...";
eval
{
    require LIXUZ;
};
if ($@)
{
    die("failed. Lixuz could not initialize. Perhaps some module is missing?\n\nCrash dump:\n-----\n$@\n-----\n");
}
print "done\n";
print "Creating action settings...";
my $i18n = LIXUZ::HelperModules::I18N->new();
my %actionPaths = LIXUZ::Schema::LzAction->getPathsHash($i18n);
foreach my $path (keys(%actionPaths))
{
    my $s = LIXUZ->model('LIXUZDB::LzAction')->find({ action_path => $path });
    if ($s)
    {
        next;
    }
    print '.';
    $s = LIXUZ->model('LIXUZDB::LzAction')->create({ action_path => $path });
    $s->update();
}
print "done\n";
print "Creating statuses...";
my $n = 1; # Statuses begin at 1, not 0
foreach (qw(Draft Live Revision Inactive))
{
    my $s = LIXUZ->model('LIXUZDB::LzStatus')->create({
            status_id => $n,
            status_name => $_,
            system_status => '1',
        });
    $s->update();
    $n++;
    print ".";
}
print "done\n";
print "Creating fields...";
createField('inline: title','singleline','title','articles',true,undef,undef);
createField('inline: lead','multiline','lead','articles',false,undef,true);
createField('inline: author','singleline','author','articles',false,undef,undef);
createField('inline: body','multiline','body','articles',false,undef,true);
createField('inline: publish_time','datetime','publish_time','articles',true,undef,undef);
createField('inline: expiry_time','datetime','expiry_time','articles',false,undef,undef);
createField('inline: status_id','user-pulldown','status_id','articles',true,undef,undef);
createField('inline: folder','user-pulldown','folder','articles',true,undef,undef);
createField('inline: template_id','user-pulldown','template_id','articles',false,undef,undef);
print "done\n";
if (@createUsers > 1)
{
    print "Creating admin users...";
}
else
{
    print "Creating admin user...";
}
my $role = LIXUZ->model('LIXUZDB::LzRole')->create({
        role_name => 'Admin',
        role_status => 'Active',
    });
print '.';
my $actions = LIXUZ->model('LIXUZDB::LzAction');
while(my $a = $actions->next)
{
    LIXUZ->model('LIXUZDB::LzRoleAction')->create({
            action_id => $a->action_id,
            role_id => $role->role_id,
            allowed => 1,
        });
}
foreach my $userInfo (@createUsers)
{
    print '.';
    my $user = LIXUZ->model('LIXUZDB::LzUser')->create({
            created => \'now()',
            firstname => 'changeme',
            lastname => 'changeme',
            user_name => $userInfo->{user},
            role_id => $role->role_id,
        });
    print '.';
    $user->set_password($userInfo->{pwd});
    $user->update();
}
print "done\n";
print "Populating remaining data...\n";
LIXUZ->model('LIXUZDB::LzFileClass')->create({
        id => 0,
        name => 'Default/generic',
    });
print "done\n";

print "\n";
print "Lixuz has now been successfully installed.\n";
print "Now you will have to manually install the cronjobs and set up\n";
print "apache. Read docs/installation.pod for more information.\n";

sub createField
{
    my($name,$type,$inline,$exclusive,$obligatory,$height,$richtext) = @_;
    my $newField = LIXUZ->model('LIXUZDB::LzField')->create({
            field_name => $name,
            field_type => $type,
            field_height => $height,
            inline => $inline,
            obligatory => $obligatory,
            field_richtext => $richtext,});
    $newField->update();
}

sub createConfigFile
{
    open(my $template,'<',$settings{installPath}.'/lixuz.yml.tpl');
    open(my $target,'>',$settings{installPath}.'/lixuz.yml');
    my $ses = $settings{temp_path}.'/lixuzSessionStorage';
    my $mason = $settings{temp_path}.'/mason/';
    my $root = $settings{installPath}.'/root/';
    while(my $l = <$template>)
    {
        next if $l =~ /lixuz_install\.pl/;
        if(length($l))
        {
            $l =~ s/\[DBNAME\]/$dbnam/;
            $l =~ s/\[DBUSER\]/$dbuser/;
            $l =~ s/\[DB_PASSWD\]/$dbpwd/;
            $l =~ s/\[SESSION_STORAGE\]/$ses/;
            $l =~ s/\[MEMCACHED_SERVER\]/$settings{memcached}/;
            $l =~ s/\[MEMCACHED_NAMESPACE\]/$settings{memcached_namespace}/;
            $l =~ s/\[MASON_DATADIR\]/$mason/;
            $l =~ s/\[LIXUZ_ROOT\]/$root/;
            $l =~ s/\[TEMPLATE_PATH\]/$settings{template_path}/;
            $l =~ s/\[TMP_PATH\]/$settings{temp_path}/;
            $l =~ s/\[FILE_PATH\]/$settings{file_path}/;
            $l =~ s/\[FROM_EMAIL\]/$settings{from_email}/;
            $l =~ s/\[EMAIL_TO_OVERRIDE\]/false/;
            $l =~ s/\[DEFAULT_URL_CATEGORY\]/\\%c/;
            $l =~ s/\[DEFAULT_URL_ARTICLE\]/\\%c\/\\%a/;
            $l =~ s/\[RSS_IMPORT_ACTIVE_DEFAULT\]/false/;
			$l =~ s/\[INDEXER_STORAGE_PATH\]/$settings{indexFiles}/;
			$l =~ s/\[INDEXER_LANGUAGE\]/no/;
            $l =~ s/\[FILES_COMPAT\]/false/;
        }
        print {$target} $l;
    }
    close($template);
    close($target);
    unlink($settings{installPath}.'/lixuz.yml.tpl');
}

sub copyRecursive
{
    my $baseSource = shift;
    my $source = shift;
    my $target = shift;
	mkpath($target);
    opendir(my $sd,$source);
    while(my $f = readdir($sd))
    {
        if ($f eq '.' or
            $f eq '..' or
            $f eq '.git' or
            $f =~ /~$/ or
            $f =~ /\.(swp)$/)
        {
            next;
        }

        if (-d $source.'/'.$f)
        {
            my $nice = $source;
            $baseSource =~ s{/+}{/}g;
            $nice =~ s{/+}{/}g;
            $nice =~ s{^$baseSource/?}{}g;
            iprint('Creating: '.$nice);
            mkpath($target.'/'.$f);
            copyRecursive($baseSource,$source.'/'.$f,$target.'/'.$f);
        }
        else
        {
            copyFile($baseSource,$source.'/'.$f,$target.'/'.$f);
        }
    }
}

sub copyFile
{
    my ($baseSource,$source,$target) = @_;
    my $nice = $source;
    $baseSource =~ s{/+}{/}g;
    $nice =~ s{/+}{/}g;
    $nice =~ s{^$baseSource/?}{}g;
    iprint('Copying: '.$nice);
    $| = 1;
    copy($source,$target) or die("FATAL: Failed to copy($source,$target): $!\n");
    my $perm = sprintf('0%o', (stat($source))[2] & 07777);
    chmod(oct($perm),$target);
}

sub getPath
{
    my $prompt = shift;
    my $existsMsg = shift;
    $existsMsg = $existsMsg ? $existsMsg : 'Are you sure you want to use that path?';
    my $default = shift;

    while(1)
    {
        $path = getInput($prompt,$default);
        chomp($path);
        if (-d $path)
        {
            if(not getBool($path.': already exists. '.$existsMsg,'No'))
            {
                next;
            }
        }
        elsif(-e $path)
        {
            print "$path: already exists and is not a directory.\n";
            next;
        }
        elsif(-e $path and not -w $path)
        {
            print "Can not write to $path\n";
            next;
        }
        else
        {
            my $base = $path;
            $base =~ s{/*$}{};
            $base = dirname($base);
            if(not -w $base)
            {
                print "Not allowed to write to $base so can not create this directory.\n";
                next;
            }
        }
        return $path;
        last;
    }
}

sub getInput
{
    my $prompt = shift;
    $prompt = $prompt ? $prompt : '(prompt missing)';
    my $default = shift;
    if ($default)
    {
        $prompt .= ' ['.$default.']';
    }
    while(1)
    {
        my $i = $term->readline($prompt.' > ');
        if(not defined $i or not length($i) or $i =~ /^\n$/)
        {
            if ($default)
            {
                print "\b\r\033[4m$prompt > \033[0m".$default."\n";
                return $default;
            }
            print "Please enter a response.\n";
            next;
        }
        elsif($i =~ m{^\s*//})
        {
            promptCommand($i);
            next;
        }
        return $i;
    }
}

sub promptCommand
{
    my $command = shift;
    $command =~ s{^\s*//}{};
    $command =~ s{\s+$}{};
    chomp($command);

    given($command)
    {
        when(['exit', 'quit', 'abort', 'cancel'])
        {
            print "Quitting as requested...\n";
            exit(0);
        }

        when('help')
        {
            print "Available commands:\n";
            print "  //help     - view this help\n";
            print "  //exit     - cancel the install and exit\n";
            print "\nIf you are looking for installation help, see the docs/installation.pod\nfile in the Lixuz tarball.\n";
            print "\n-\n";
        }

        default
        {
            print "Unknown installer command: //$command\n";
        }
    }
}

sub newStep
{
    system('clear');
    my $stepName = shift;
    $stepName = $stepName ? ' - '.$stepName : '';
    my $step;
    if ($totalSteps > 0)
    {
        $step = 'LIXUZ installer [Step '.$stepNo.' of '.$totalSteps.']'.$stepName;
    }
    else
    {
        $step = 'LIXUZ installer'.$stepName;
    }
    for(0..length($step))
    {
        print '*';
    }
    print "\n$step\n";
    for(0..length($step))
    {
        print '*';
    }
    print "\n\n";
    $stepNo++;
}

sub getBool
{
    my $prompt = shift;
    my $default = shift;
    while(1)
    {
        my $i = getInput($prompt,$default);
        if(not defined $i or not length $i)
        {
            print "Please enter 'yes' or 'no'\n";
            next;
        }
        $i =~ s/\s*//g;
        if ($i =~ /^(yes|1|aye|ja|true|y)$/i)
        {
            if(not $i =~ /^yes$/i)
            {
                print "(assuming you meant yes)\n";
            }
            return true;
        }
        elsif($i =~ /^(no|0|nay|nei|false|n)$/i)
        {
            if(not $i =~ /^no$/i)
            {
                print "(assuming you meant no)\n";
            }
            return false;
        }
        else
        {
            print "Unrecognized input '$i'. Please enter 'yes' or 'no'\n";
        }
    }
}

sub mysql_exec
{
    my $stmt = shift;
    my $exit = shift;
    my $useForce = shift;
    my @extraArgs;
    if ($useForce)
    {
        push(@extraArgs,'--force');
    }
    my $r = system('mysql',@extraArgs,'--silent','-n','-u'.$dbuser,'-p'.$dbpwd,$dbnam,'-e',$stmt);
    if ($exit && $r != 0)
    {
        die("failed - mysql returned nonzero\n");
    }
    return $r;
}

sub getRndPwd
{
    my $letters = 'abcdefghijklmnopqrstuvwxyz';
    $letters .= uc($letters);
    $letters .= '0123456789';
    my @opts = split(//,$letters);
    my $rnd;
    for(0..15)
    {
        $rnd .= $opts[rand scalar(@opts)];
    }
    return $rnd;
}

sub addUser
{
    print "\n";
	my $currUser = $ENV{SUDO_USER} ? $ENV{SUDO_USER} : $ENV{USER};
    my $userName = getInput('Username',$currUser);
    my $rnd = getRndPwd();
    print "(here is a random password if you need one: $rnd)\n";
    my $userPwd = getInput('Password');
    push(@createUsers, {  user => $userName,  pwd => $userPwd });
    print "\n";
    if(getBool('Do you want to add an additional user?','No'))
    {
        addUser();
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
