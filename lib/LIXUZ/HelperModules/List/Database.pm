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

package LIXUZ::HelperModules::List::Database;

use Moose;
use List::MoreUtils qw(any);
use LIXUZ::HelperModules::JSON qw(json_response);
use LIXUZ::HelperModules::Forms qw(finalize_form);
use LIXUZ::HelperModules::Search qw(cross parse_search_string);
use Try::Tiny;
use Hash::Merge qw(merge);
use Carp;

extends 'LIXUZ::HelperModules::List';

has '_lResultObject' => (
    is => 'rw',
    default => undef,
);

sub listGetPaginatedResultObject
{
    my($self) = @_;
    # Perform pagination
    my $page = $self->c->request->param('page');
    if(not defined $page or not $page =~ /^\d+$/)
    {
        $page = 1;
    }
    $self->listSetParam('rows',30, 1);
    my $object = $self->listGetResultObject();
    $object = $object->page($page);
    my $pager = $object->pager;
    $self->c->stash->{pager} = $pager;

    if ($self->objectName)
    {
        $self->c->stash->{ $self->objectName } = $object;
    }

    return $object;
}

sub listPerformOrdering
{
    my $self = shift;
    my $object = shift;
    my $order = $self->listGetOrderFromParam($object);
    return if not defined $order;

    $self->listSetParam('order_by',$order);
}

sub listGetResultObject
{
    my $self = shift;
    my $options = shift;
    if (!$self->_handled)
    {
        $self->handleListRequest();
    }
    if ($options && $options->{paginate})
    {
        return $self->listGetPaginatedResultObject();
    }
    if (!$self->_lDataChanged && $self->_lResultObject)
    {
        return $self->_lResultObject;
    }

    $self->listPerformOrdering();

    $self->_lDataChanged(0);

    my $search = $self->_lSearchData->{expression};
    my $settings = $self->_lSearchData->{settings};
    $settings->{join} = $self->_lSearchData->{join};

    my $obj = $self->object;

    my $object = $self->object->search($search,$settings);
    $self->_lResultObject($object);

    if ($self->objectName)
    {
        $self->c->stash->{ $self->objectName } = $object;
    }

    return $object;
}

sub listAddJoin
{
    my $self = shift;
    foreach my $join (@_)
    {
        if(any { $_ eq $join } @{$self->_lSearchData->{join}})
        {
            next;
        }
        push(@{$self->_lSearchData->{join}},$join);
        $self->_lDataChanged(1);
    }
}

sub listAddExpr
{
    my $self = shift;
    my $expressions = shift;
    my $final = $expressions;

    if ($expressions->{'-or'} || $expressions->{'-and'})
    {
        my $or = $expressions->{'-or'};
        my $and = $expressions->{'-and'};

        if(ref($and) eq 'ARRAY')
        {
            $and = undef;
        }
        else
        {
            $final->{'-and'} = [];
        }

        if ($or)
        {
            push(@{$final->{'-and'}}, { '-or' => $expressions->{'-or'} } );
            delete($final->{'-or'});
        }
        if ($and)
        {
            push(@{$final->{'-and'}}, $and);
        }
    }
    else
    {
        my $newF = {
            '-and' => [
                $final
            ]
        };
        $final = $newF;
    }

    my $expr = merge($final,$self->_lSearchData->{expression});
    $self->_lSearchData->{expression} = $expr;
    $self->_lDataChanged(1);
}

# Purpose: Perform a search
# Usage: my $resultSet = $obj->list_search($string,$columns);
#
# $string is the search string from the user, unfiltered
#
# $columns is an arrayref of columns to search in the model
sub list_search
{
    my $self = shift;
    my $string = shift;
    if(not defined $string or not length $string)
    {
        return;
    }
    my $columns = shift;

    my ($include_tokens, $exclude_tokens) = parse_search_string($string,$self->c);

    my ($include, $ignore);
    $include = [cross($columns,$include_tokens)];
    $ignore  = [cross($columns,$exclude_tokens,'not like','')];

    if (@{$ignore})
    {
        $self->listAddExpr({
                -and => {
                    -or => $include,
                    -and => $ignore
                }
            });
    }
    else
    {
        $self->listAddExpr({
                -or => $include
            });
    }
    return;
}

# Purpose: An advanced version of list_search()
# Usage: obje->list_advanced_search({ normal_search }, { advanced_filter });
#
# This is an advanced version of list_serach() that allows you to add additional
# filtering to the search result. It takes two hashes, normal_search is:
# {
#   string => $string in list_search(),
#   columns => $columns in list_search(),
# }
#
# advanced_filter is:
# {
#   columns => allowed search columns (arrayref),
#               This can be in the form table.column, where it
#               will look for filter_'column' in the parameters, but
#               will do a search_related instead
# }
sub list_advanced_search
{
    my ($self, $normal, $advancedFilter) = @_;

    # Perform the base search
    $self->list_search($normal->{string}, $normal->{columns});

    if ($normal->{string})
    {
        $self->c->stash->{folder_recursive} = 1;
    }

    # Generate filterHash from columns+parameters
    my $filterHash = {
        base => {},
    };
    foreach my $column (@{$advancedFilter})
    {
        (my $name = $column) =~ s/^[^\.]+\.//;
        my $cont = $self->c->req->param('filter_'.$name);
        if(not defined $cont or not length $cont)
        {
            next;
        }

        # If column has a . then the filtering is done in a related table and we need to do
        # some additional processing later on
        if ($column =~ /\./)
        {
            (my $related = $column) =~ s/^([^\.]+)\..*/$1/;
            if(not defined $filterHash->{$related})
            {
                $filterHash->{$related} = {};
            }
            $filterHash->{$related}->{$column} = $cont;
        }
        # If it doesn't then we simply add it to $filterHash to be run in one big search dump later on
        else
        {
            $filterHash->{base}->{$column} = $cont;
        }
    }
    # If we have anything in filterHash, run through it
    foreach my $filter (keys %{$filterHash})
    {
        next if not $filterHash->{$filter};
        if ($filter ne 'base')
        {
            $self->listAddJoin($filter);
        }
        $self->listAddExpr($filterHash->{$filter});
    }
}

sub _listGetPrefix
{
    my $self = shift;
    return $self->object->current_source_alias;
}

1;
