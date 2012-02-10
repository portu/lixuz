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

package LIXUZ::Role::List::Indexer;

use Moose::Role;
use LIXUZ::HelperModules::Indexer;
use List::MoreUtils qw(any);
use LIXUZ::HelperModules::JSON qw(json_response);
use Try::Tiny;
use Carp;
use 5.010;

with 'LIXUZ::Role::List::Database';

has '_indexerResultObject' => (
    is => 'rw',
    );

around 'listGetResultObject' => sub
{
    my $orig = shift;
    my $self = shift;

    if ($self->_indexerResultObject)
    {
        return $self->_indexerResultObject;
    }
    else
    {
        return $self->$orig(@_);
    }
};

sub _indexer_select_resolve_method
{
    my $orig = shift;
    my $self = shift;

    # Allow "sub-roles" to override our resolve method if needed
    if ($self->can('_select_resolve_method'))
    {
        return $self->_select_resolve_method($orig,@_);
    }

    my $resolveWith = 'database';

    # Use the indexer if we have a search query and we *DON'T* have an
    # existing indexer result object. If we already have an indexer result
    # object then it could be a subclass of us attempting to force a database
    # search.
    if (@_ && !$self->_indexerResultObject)
    {
        my $q = $_[0];
        if(defined($q) && length($q))
        {
            $resolveWith = 'indexer';
        }
    }

    given($resolveWith)
    {
        when('database')
        {
            return $self->$orig(@_);
        }

        when('indexer')
        {
            return $self->_list_search_indexer(@_);
        }

        default
        {
            die('_indexerResultObject ended up with unknown resolveWith: '.$resolveWith);
        }
    }
}

around 'list_search' => sub
{
    return _indexer_select_resolve_method(@_);
};

sub _list_search_indexer
{
    my ($self, $string, $filter) = @_;
    if(ref($string))
    {
        $string = $string->{string};
    }
    if(not $filter or not ref($filter) eq 'HASH')
    {
        $filter = {};
    }
    $filter->{query} = $string;

    my $page = $self->c->request->param('page');
    if(not defined $page or not $page =~ /^\d+$/)
    {
        $page = 1;
    }

    my $type;
    # FIXME: Hacky, use a proper isa check
    my $searchType = 'articles';
    if(ref($self) =~ /Files/)
    {
        $searchType = 'files';
    }

    my $indexer = LIXUZ::HelperModules::Indexer->new(
        c => $self->c,
        searchType => $searchType,
        mode => 'internal',
    );
    my $result = $indexer->search($filter, { page => $page });
    $self->_indexerResultObject($result);

    if ($self->_loptions->{objectName})
    {
        $self->c->stash->{ $self->_loptions->{objectName} } = $result;
        $self->c->stash->{pager} = $result->pager;
    }
    return $result;
}

1;
