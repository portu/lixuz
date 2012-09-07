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

# This class provides a version of the list role that will search both the
# normal indexer as well as the database for a query, if the indexer returned
# fewer than 200 results. This allows more useful results for queries for
# partial words.

package LIXUZ::HelperModules::List::Dual;

use Moose;
use LIXUZ::HelperModules::Indexer;
use List::MoreUtils qw(any);
use LIXUZ::HelperModules::JSON qw(json_response);
use Try::Tiny;
use Carp;
use 5.010;

extends 'LIXUZ::HelperModules::List::Indexer';

has '_forceSearchMethod' => (
    is => 'rw',
);

# Method that gets called in place of the ::Indexer versions resolve method
# selector.
sub _select_resolve_method
{
    my $self = shift;
    my $orig = shift;

    # Default to dual
    my $resolveWith = 'dual';
    # If we got no parameters then use the database, in these cases there's
    # no search query, so the indexer is completely useless.
    if (!@_)
    {
        $resolveWith = 'database';
    }
    # If we're attempting to force a certain resolver, then obey that request.
    if ($self->_forceSearchMethod)
    {
        $resolveWith = $self->_forceSearchMethod;
    }


    given($resolveWith)
    {
        when('database')
        {
            return $self->$orig(@_);
        }

        when('dual')
        {
            return $self->_dual_resolver($orig,@_);
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

sub _dual_resolver
{
    my $self = shift;
    my $orig = shift;

    my $ret = $self->_list_search_indexer(@_);

    # If the indexer returned over 200 results, then we don't bother generating
    # a secondary database-based search.
    if ($ret->count >= 200)
    {
        return $ret;
    }

    $self->_indexerResultObject(0);

    # Ok, generate a database-based search
    if ($ret->count == 0)
    {
        return $self->$orig(@_);
    }

    my @ignore;
    
    # Exclude existing results
    while(my $r = $ret->next)
    {
        push(@ignore,$r->id);
    }
    $ret->reset;
    my $idType = 'article_id';
    if ($self->objectName eq 'file')
    {
        $idType = 'file_id';
    }
    $self->listAddExpr({ $idType => { '-not_in' => \@ignore }});

    # Perform the database call
    $self->$orig(@_);
    my $databaseResult = $self->listGetResultObject;
    # Push database results onto the indexer object
    $ret->_pushFromDB($databaseResult);

    # Remove forced search method
    $self->_forceSearchMethod(undef);
    # Overwrite any already generated objects
    $self->_indexerResultObject($ret);
    $self->_lResultObject($ret);
    # Regenerate paginated object
    $self->listGetPaginatedResultObject();
    return $ret;
}

1;
