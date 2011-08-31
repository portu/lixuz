#!/usr/bin/perl
# buildlocale.pl
# Copyright (C) Eskild Hustvedt 2006-2011
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

use strict;
use warnings;
use File::Find;
use File::Temp qw/tempdir/;
use File::Copy qw/move/;
use Fatal qw(chdir mkdir open close);
use Cwd qw(getcwd realpath);
use constant { true => 1, false => 0};

my @Files;
my $buildOnlyMode = false;
my $origDir = getcwd;
my $potTarget = realpath($origDir.'/i18n/lixuz.pot');
my $i18nDir = realpath($origDir.'/i18n');

$| = 1;

my $temp = tempdir('/tmp/lixuz.potgen.XXXXXX',CLEANUP => 1);

my $HEADER = '# LIXUZ translation file';
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
$year += 1900;
$mon++;

die("Needs to be run from the base dir of the LIXUZ source tree\n") if not -d './lib' or not -d './root';
die("Needs gettext, install the gettext package\n") if not InPath('xgettext') or not InPath('msgmerge') or not InPath('msgfmt');

# Purpose: Do some replacements on files in the copy so that xgettext find them easier to work with
# Usage: find(\&fileFixup,...);
sub fileFixup
{
	return if -d $File::Find::name;
	return if $File::Find::name =~ /\.git/;
	return if not $File::Find::name =~ /\.(pl|pm|html|mas)$/;
	print '.';
	open(my $f,'<',$File::Find::name);
	undef $/;
	my $d = <$f>;
	close($f);
	return if(not defined $d or not length $d or not $d =~ /\S/);
	my $newF;
	my $found = 0;
    my $isHtml = $File::Find::name =~ /\.html$/;
    # A few specific .pm-files needs to have the html workarounds applied
    if ($File::Find::name =~ m{(Admin/Articles|Role/List)\.pm$})
    {
        $isHtml = 1;
    }
	foreach my $l (split(/\n/,$d))
	{
		if($l =~ s/\$(c->stash->{i18n}|i18n)->get(_advanced)?/gettext/g)
		{
			$found = 1;
            if ($isHtml)
            {
                $l =~ s/^(.*?)gettext\(/gettext(/;
                $l =~ s/,\s*},$//;
                $l =~ s/(<[^%>]>|\s+)*$//g;
                if (not $l =~ /%>.*<%.*gettext/)
                {
                    $l =~ s/%>.*$//;
                }
                else
                {
                    $l =~ s/%>[^%]+<%/ ; /g;
                    $l =~ s/%>[^%]+$//g;
                }
                $l =~ s/$/;/;
            }
            else
            {
                $l =~ s/,gettext/, gettext/g;
                $l =~ s/{[^}]*}/{}/g;
            }
		}
        elsif ($isHtml)
        {
            $l = '';
        }
		$newF .= $l."\n";
	}
	return if not $found;
	my $name = $File::Find::name;
	$name =~ s/$temp/.\//;
    $name =~ s/\/+/\//g;
	push(@Files,$name);
	die('$newF was undef, something went wrong') if not defined $newF;
	open(my $t,'>',$File::Find::name);
	print $t $newF;
	close($t);
}

# Purpose: Load a configuration file
# Usage: LoadConfigFile(/FILE, \%ConfigHash, \%OptionRegexHash, OnlyValidOptions?);
#  OptionRegeXhash can be available for only a select few of the config options
#  or skipped completely (by replacing it by undef).
#  If OnlyValidOptions is true it will cause LoadConfigFile to skip options not in
#  the OptionRegexHash.
sub LoadConfigFile {
	my ($File, $ConfigHash, $OptionRegex, $OnlyValidOptions) = @_;

	my $Status = true;

	open(my $CONFIG, '<', $File) or do {
		print "Unable to read config settings: $File:$!\n";
		return(false);
	};
	$/ = "\n";
	while(<$CONFIG>) {
		next if m/^\s*(#.*)?$/;
		next unless m/=/;
		chomp;
		my $Option = $_;
		my $Value = $_;
		$Option =~ s/^\s*(\S*)\s*=.*/$1/;
		$Value =~ s/^.*=\s*(.*)\s*/$1/;
		if($OnlyValidOptions) {
			unless(defined($OptionRegex->{$Option})) {
				print ("Unknown configuration option \"$Option\" in $File: Ignored.\n");
				next;
			}
		}
		unless(defined($Value)) {
			print ("Empty value for option $Option in $File");
			$Status = false;
		}
		if(defined($OptionRegex) and defined($OptionRegex->{$Option})) {
			my $MustMatch = $OptionRegex->{$Option};
			unless ($Value =~ /$MustMatch/) {
				$Status = false;
				print "Invalid setting of $Option in the config file: Must match $OptionRegex->{$Option}\n";
				next;
			}
		}
		$ConfigHash->{$Option} = $Value;
	}
	close($CONFIG);
	return($Status);
}

# Purpose: Create our locale/ tree and build mo-files
# Usage: createI18NTree();
sub createI18NTree
{
	my %LocaleDirHash;
	my $LocaleDir = $i18nDir.'/locale/';
	LoadConfigFile($i18nDir.'/aliases.conf',\%LocaleDirHash);
	print "Creating the $LocaleDir directory tree...\n";
	unless (-d $LocaleDir)
    {
		mkdir($LocaleDir);
		print " Created: $LocaleDir\n";
	}
	foreach my $CurrentLocale (keys(%LocaleDirHash))
    {
		if(-l "$LocaleDir/$CurrentLocale")
        {
			print " Removed link: $LocaleDir/$CurrentLocale\n";
			unlink("$LocaleDir/$CurrentLocale");
		}
		unless (-d "$LocaleDir/$CurrentLocale/LC_MESSAGES")
        {
			mkdir("$LocaleDir/$CurrentLocale");
			mkdir("$LocaleDir/$CurrentLocale/LC_MESSAGES");
			print " Created: $LocaleDir/$CurrentLocale\n";
		}
		foreach my $LocaleAlias (split(/\s+/, $LocaleDirHash{$CurrentLocale}))
        {
			if(-l "$LocaleDir/$LocaleAlias")
            {
				unless(readlink("$LocaleDir/$LocaleAlias") eq $CurrentLocale)
                {
					print " Removed link: $LocaleDir/$LocaleAlias\n";
					unlink("$LocaleDir/$LocaleAlias");
				}
			}
			unless (-e "$LocaleDir/$LocaleAlias")
            {
				symlink($CurrentLocale, "$LocaleDir/$LocaleAlias");
				print " Created symlink from \"$CurrentLocale\" to \"$LocaleAlias\"\n";
			}
		}
	}
	print "Putting mo-files into place:";
	foreach my $MO (<*.mo>) {
		my $orig = $MO;
		$orig =~ s/\.(po|mo)$//;
		if(not -d "$LocaleDir/$orig/")
		{
			print "\n$MO: No directory created\n";
			next;
		}
		move($MO,"$LocaleDir/$orig/LC_MESSAGES/lixuz.mo");
		print " $MO";
	}
	print "\n";
}

# Purpose: Check if a command is in PATH
# Usage: InPath(command)
sub InPath {
	foreach (split /:/, $ENV{PATH}) { if (-x "$_/@_" and not -d "$_/@_" ) {   return 1; } } return 0;
}

if (@ARGV and $ARGV[0] eq 'buildonly')
{
    $buildOnlyMode = true;
    shift;
}

if (not $buildOnlyMode)
{
    print 'Copying...';
    system('cp', '-r', './lib','./root' ,$temp);
    print "done\n";
    chdir($temp);
    print 'Preparing files...';
    find(\&fileFixup,$temp.'/lib',$temp.'/root');
    print "done\n";
    #use Data::Dumper;
    #die(Dumper(@Files));
    print 'Running xgettext...';
    my @command = ('xgettext',
        '--copyright-holder',	'Portu media & communications',
        '--msgid-bugs-address',	'https://github.com/portu/lixuz/issues',
        '--language',			'perl',
        '--default-domain',		'LIXUZ',
        '--package-name',		'LIXUZ',
        '--from-code',			'UTF-8',
        '--package-version',	'('.scalar localtime().')',
        '-o',					$potTarget,
        '--add-comments=TRANSLATORS',
        @Files,);
    # These can be used to debug issues
    #print '"'.join('" "',@command)."\"\n";
    #system('/bin/bash');
    system(@command);
    print "done\n";

    if(not -e $potTarget)
    {
        die("$potTarget: missing, even after xgettext\n");
    }
    print 'Finalizing POT...';
    open(my $pot,'<',$potTarget);
    undef $/;
    my $pot_content = <$pot>;
    close($pot);
    $pot_content =~ s{YEAR Portu}{$year Portu};
    $pot_content =~ s{# SOME DESCRIPTIVE TITLE\.}{$HEADER};
    $pot_content =~ s{# This file is distributed under the same license as the PACKAGE package\.\n}{};
    $pot_content =~ s{# FIRST AUTHOR <EMAIL\@ADDRESS>, YEAR\.\n}{};
    $pot_content =~ s{charset=CHARSET}{charset=UTF-8};
    open($pot,'>',$potTarget);
    print $pot $pot_content;
    close($pot);
    print "done\n";
    print "Wrote $potTarget\n";
    print "Merging changes with .po-files and building .mo-files...";
}
else
{
    print "Building .mo-files...";
}
chdir($i18nDir);
foreach my $poFile (<*.po>)
{
	next if $poFile eq '*.po' or $poFile =~ /-js\.po/;
    if(not $buildOnlyMode)
    {
        system('msgmerge','-q','-U',$poFile,$potTarget);
        print ".";
    }
	my $moFile = $poFile;
	$moFile =~ s/\.po$/.mo/g;
	system('msgfmt','-o',$moFile,$poFile);
	print ".";
}
print "done\n";
createI18NTree();
print "All done!\n";
