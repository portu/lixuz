#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use Config::Any;
chdir($FindBin::RealBin.'/../');

my $file = 'lixuz.yml';

$ENV{SCHEMA_LOADER_BACKCOMPAT} = 1;

my $conf = Config::Any->load_files( { files =>  [ $file ], use_ext => 1} ) or die("Failed to load config: $file: $!\n");
if(ref($conf) eq 'ARRAY')
{
    $conf = $conf->[0]->{$file};
}

# Update all DB modules
system('perl','script/lixuz_create.pl','model','DBIC','DBIC::Schema','LIXUZ::Schema','create=static',$conf->{'Model::LIXUZDB'}->{'connect_info'}->{'dsn'},$conf->{'Model::LIXUZDB'}->{'connect_info'}->{'user'},$conf->{'Model::LIXUZDB'}->{'connect_info'}->{'password'});
unlink('./t/model_DBIC.t','./lib/LIXUZ/Model/DBIC.pm','lib/LIXUZ/Schema/LzDmMap.pm');

# (also supports svn and svk)
my $SCM = 'git';
$ENV{GIT_PAGER} = 'cat';

sub silentSystem
{
    open(my $SAVED_STDOUT, '>&',\*STDOUT);
    open(my $SAVED_STDERR, '>&',\*STDOUT);
    open(STDOUT,'>','/dev/null');
    open(STDERR,'>','/dev/null');
    my $ret = system(@_);
    open(STDOUT,'>&',$SAVED_STDOUT);
    open(STDERR,'>&',$SAVED_STDERR);
    return $ret;
}

my @cleanThis;
my $foundContent = 0;
my $unknown = 0;
sub checkForChanges
{
    my $file = shift;
    # `` isn't particulary pretty, but this isn't production code so meh
    my $stat = `$SCM status "$file" 2>&1`;
    if ($SCM eq 'git')
    {
        if ($stat =~ /^error/)
        {
            $unknown++;
            return;
        }
    }
    elsif ($stat =~ /^\?/)
    {
        $unknown++;
        return;
    }
    my $info = `$SCM diff "$file"`;
    my $content;
    foreach (split(/\n/,$info))
    {
        next if /^(===|\+\+\+|\-\-\-)/;
        next if not /^(\+|\-)/;
        next if /(Created by DBIx::Class::Schema|DO NOT MODIFY THIS OR ANYTHING ABOVE)/;
        $content .= $_."\n";
    }
    if(not $content)
    {
        push(@cleanThis,$file);
    }
    else
    {
        $foundContent++;
    }
    print ".";
}

$| = 1;
print "Finding and reverting unchanged schema files...";
foreach my $file (glob('./lib/LIXUZ/Schema/*.pm'))
{
    checkForChanges($file);
}
checkForChanges('lib/LIXUZ/Schema.pm');
if (@cleanThis)
{
    if ($SCM eq 'git')
    {
        silentSystem($SCM,'checkout',@cleanThis);
    }
    else
    {
        silentSystem($SCM,'revert',@cleanThis);
    }
    print ".";
}
print "done\n";
if ($foundContent)
{
    my $schema = $foundContent == 1 ? 'schema' : 'schemas';
    print "$foundContent $schema has been updated";
    if ($unknown)
    {
        my $schema = $unknown == 1 ? 'schema was' : 'schemas were';
        print " and $unknown new $schema found";
    }
    print "\n";
}
elsif($unknown)
{
    my $schema = $unknown == 1 ? 'schema was' : 'schemas were';
    print "No schemas have been updated, but $unknown new $schema found\n";
}
else
{
    print "No schemas have been updated.\n";
}
