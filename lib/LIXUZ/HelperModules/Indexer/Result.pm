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

package LIXUZ::HelperModules::Indexer::Result;
use Moose;
use 5.010;

with 'LIXUZ::Role::IndexerData';

has 'entriesPerPage' => (
    is => 'rw',
    isa => 'Num',
    required => 1
);
has '_dirtyPager' => (
    is => 'rw',
    isa => 'Num',
    default => 1,
);
has '_currentPage' => (
    is => 'rw',
    isa => 'Num',
    default => 1,
);
has '_pager' => (
    is => 'rw',
    isa => 'Object',
    required => 0,
);
has '_result' => (
    is => 'ro',
    isa => 'ArrayRef',
    required => 1,
);
has '_currEntries' => (
    is => 'rw',
    isa => 'ArrayRef',
    builder => '_constructCache',
    lazy => 1,
);
has '_currInt' => (
    is => 'rw',
    isa => 'Int',
    default => -1,
);
has '_rawDBEntries' => (
    is => 'rw',
    isa => 'ArrayRef',
    default => sub { [] },
    lazy => 1
);

sub pager
{
    my $self = shift;
    if ($self->_dirtyPager)
    {
        if ($self->_pager)
        {
            $self->entriesPerPage($self->_pager->entries_per_page);
            $self->_currentPage($self->_pager->current_page);
        }
        my $pager = Data::Page->new();
        $pager->total_entries(scalar @{$self->_result});
        $pager->entries_per_page($self->entriesPerPage);
        $pager->current_page($self->_currentPage);
        $self->_pager($pager);
        $self->_dirtyPager(0);
    }
    return $self->_pager;
}

sub next
{
    my $self = shift;
    my $curr = $self->_currInt;
    $curr++;
    $self->_currInt($curr);
    return $self->_currEntries->[$curr];
}

sub count
{
    my $self = shift;
    return $self->pager->total_entries;
}

sub page
{
    my $self = shift;
    my $page = shift;
    $self->_currentPage($page);
    $self->pager->current_page($page);
    $self->_constructCache();
    return $self;
}

sub first
{
    my $self = shift;
    $self->reset;
    return $self->next;
}

sub reset
{
    my $self = shift;
    $self->_currInt(-1);
}

sub _constructCache
{
    my $self = shift;

    my ($startAt,$stopAt) = ($self->pager->first, $self->pager->last);
    # Array is 0-indexed, while the pager is 1-indexed.
    $startAt--; $stopAt--;

    my @results = @{$self->_result}[$startAt..$stopAt];
    my %idIndex;
    my @searches_articles;
    my @searches_files;
    foreach my $part (@results)
    {
        # If $part is an object, just skip over it
        if (ref($part) ne 'HASH')
        {
            next;
        }
        if(not defined $part->{id})
        {
            $self->c->log->warn('Got undef $part->{id} in search result');
            next;
        }
        my ($type,$id,$revision) = $self->_parseIndexID($part->{id});

        given($type)
        {
            when('file')
            {
                my $search = {
                    file_id => $id,
                };
                push(@searches_files, $search);
            }

            when('article')
            {
                my $search = {
                    article_id => $id,
                };
                if(defined $revision)
                {
                    $search->{revision} = $revision;
                }
                else
                {
                    $search->{status_id} = 2;
                }
                push(@searches_articles,$search);
            }

            default
            {
                if(not defined $type)
                {
                    $type = '[undef]';
                }
                $self->c->log->warn('Unknown item type in search result: '.$type);
            }
        }
    }

    if (@searches_articles)
    {
        my $articles = $self->c->model('LIXUZDB::LzArticle')->search({ '-or' => \@searches_articles});
        while(my $art = $articles->next)
        {
            my $id = $self->_getIndexID($art);
            $idIndex{$id} = $art;
        }
    }
    if (@searches_files)
    {
        my $files = $self->c->model('LIXUZDB::LzFile')->search({ '-or' => \@searches_files});
        while(my $file = $files->next)
        {
            my $id = $self->_getIndexID($file);
            $idIndex{$id} = $file;
        }
    }

    my @result;
    foreach my $part (@results)
    {
        my $dbEntry;
        # If $part is an object then we don't need to retrieve it from the idIndex
        if (ref($part) ne 'HASH')
        {
            $dbEntry = $part;
        }
        else
        {
            if(not defined $part->{id})
            {
                $self->c->log->warn('Search result provided an undefined part id. Skipping entry.');
                next;
            }
            $dbEntry = $idIndex{ $part->{id} };
        }

        if(not $dbEntry)
        {
            $self->c->log->warn('Search result wanted "'.$part->{id}.'" - but database search failed to find it.');
        }
        else
        {
            push(@result, $dbEntry);
        }
    }
    $self->_currEntries(\@result);
}

sub _pushFromDB
{
    my $self = shift;
    my $object = shift;
    if ($object->can('next'))
    {
        while(my $o = $object->next)
        {
            $self->_pushFromDB($o);
        }
    }
    else
    {
        push(@{$self->_result},$object);
        # Mark the pager as 'dirty' - it will be regenerated
        $self->_dirtyPager(1);
        $self->reset;
    }
    return $self;
}

1;
