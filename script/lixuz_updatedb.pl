#!/usr/bin/perl
use strict;
use warnings;
# Remove the line containing accessor => in LzStatus.pm so that the lixuz_create accepts it.
system('perl','-pi','-e','s/^\s+accessor.*=>.*\n$//;','./lib/LIXUZ/Schema/LzStatus.pm');
# Update all DB modules
system('perl','script/lixuz_create.pl','model','DBIC','DBIC::Schema','LIXUZ::Schema','create=static','dbi:mysql:dbname=lixuz','lixuz','li09uz31');
# Add accessor back into LzStatus.pm
system('perl','-pi','-e','s/{ data_type => "varchar", is_nullable => 1, size => 56 },/{ data_type => "varchar", is_nullable => 1, size => 56, accessor => "_hidden_orig_status_name" },/g','./lib/LIXUZ/Schema/LzStatus.pm');
system('perl','-pi','-e','s/size => (20|56),/size => $1,\n    accessor => \'_hidden_orig_status_name\',/;','./lib/LIXUZ/Schema/LzStatus.pm');
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
