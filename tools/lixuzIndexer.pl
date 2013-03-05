#!/usr/bin/perl
# LIXUZ content management system
# Copyright (C) Utrop A/S Portu media & Communications 2008-2011
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# Simple helper script for indexing in Lixuz.
#
# This script is called by the insert/delete triggers on tables
# to update or create entries in the index.
#
# It is meant to be light and fast, and therefore does not load
# the Lixuz core (but uses a mock from HelperModules::Scripts)
# and leaves index optimization to the indexer cronjob.
# It also loads most time-consuming modules after checking if
# --fork was supplied, so that it does not block LIXUZ from completing
# a request.
use strict;
use warnings;
use Getopt::Long;
use POSIX qw(nice);
use FindBin;
use lib $FindBin::RealBin.'/../lib';

my ($fork,$id,$type,$delete,$revision) = (0,undef,'',0,undef);

GetOptions(
    'fork' => \$fork,
    'id=i' => \$id,
    'revision=i' => \$revision,
    'type=s' => \$type,
    'delete' => \$delete,
    'help' => sub {
        print "Indexing helper for Lixuz. Not meant for direct execution\n";
        exit(0);
    },
) or die;

if ($fork)
{
    exit if fork;
}
nice(10); # Other processes (read: LIXUZ core) are more important
eval('use LIXUZ::HelperModules::Scripts qw(getConfig mockC);
use LIXUZ::HelperModules::Indexer;
use LIXUZ::Schema;1;') or die;

if(not defined $type)
{
    die("--type is required\n");
}
$type =~ s/^lz_//;
$type = lc($type);
if ($type ne 'article' && $type ne 'file')
{
    die("Uknown --type: $type");
}
if(not defined $id or $id =~ /\D/)
{
    die("--id not supplied");
}
if(defined $revision)
{
    if ($type eq 'file')
    {
        die("--revision supplied with --type file");
    }
    elsif($revision =~ /\D/)
    {
        die("--revision $revision is invalid");
    }
}


my $config = getConfig();
my $c = mockC();
my $row;
my $rsName;
my $schema = LIXUZ::Schema->connect($config->{'Model::LIXUZDB'}->{connect_info});;
my $indexer;

if ($type eq 'article')
{
    $indexer = LIXUZ::HelperModules::Indexer->new(config => $config->{'LIXUZ'}->{'indexer'}, mode => 'external', c => $c);
    $rsName = 'LzArticle';
}
elsif($type eq 'file')
{
    $indexer = LIXUZ::HelperModules::Indexer->new(config => $config->{'LIXUZ'}->{'indexer'}, mode => 'internal', c => $c);
    $rsName = 'LzFile';
}

my $searchExpr = { $type.'_id' => $id };
if (defined $revision)
{
	$searchExpr->{revision} = $revision;
}

$row = $schema->resultset($rsName)->find($searchExpr);
if (not defined $row)
{
    $indexer->delete({ type => $type, id => $id, revision => $revision });
    if (!$delete)
    {
        warn("Did not find ".$type."_id row $id and deletion was not requested. Deleted anyway.");
    }
}
else
{
    $indexer->add_autoreplace($row);
}

# Not ->commit(1)
$indexer->commit;
exit(0);
