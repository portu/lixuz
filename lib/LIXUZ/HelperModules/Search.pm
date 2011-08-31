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

# LIXUZ::HelperModules::Search
#
# This file contains shared functions that are used to create and perform
# searches in LIXUZ.
#
# It exports nothing by default, you need to explicitly import the
# functions you want.
package LIXUZ::HelperModules::Search;

use strict;
use warnings;
use Exporter qw(import);
use HTML::Entities;
use Carp qw(croak);

our @EXPORT_OK = qw(cross perform_search perform_advanced_search parse_search_string);

# Purpose: Perform a search
# Usage: my $resultSet = perform_search($model,$string,$columns,$prefix,$c);
#
# $model is the resultSet to run the search on. Ie. fetch with $c->model('...');
#
# $string is the search string from the user, unfiltered
#
# $columns is an arrayref of columns to search in $model
#
# $prefix is the prefix to include in the search. This will be me. if not specified.
#
# $c is the catalyst object (duh)
sub perform_search
{
    my $model = shift;
    my $string = shift;
    if(not defined $string or not length $string)
    {
        return $model;
    }
    my $columns = shift;
    my $prefix = shift;
    my $c = shift;

    my($include, $ignore) = get_search_SQL($columns,$string,$prefix,$c);

    my $result;
    if (@{$ignore})
    {
        $result = $model->search({
                -and => {
                    -or => $include,
                    -and => $ignore
                }
            });
    }
    else
    {
        $result = $model->search({
                -or => $include
            });
    }
    return $result;
}

# Purpose: An advanced version of perform_search()
# Usage: perform_advanced_search($c,$model,{ normal_search }, { advanced_filter });
#
# This is an advanced version of perform_serach() that allows you to add additional
# filtering to the search result. It takes two hashes, normal_search is:
# {
#   string => $string in perform_search(),
#   columns => $columns in perform_search(),
#   prefix => $prefix in perform_search(),
# }
#
# advanced_filter is:
# {
#   columns => allowed search columns (arrayref),
#               This can be in the form table.column, where it
#               will look for filter_'column' in the parameters, but
#               will do a search_related instead
#   origTable => the name of the original table, this is required if you
#               include expressions in "columns" that require use of
#               search_related. It will be used to get the resultset for
#               origHandler back after a search_related. ie. it does:
#               $v = $v->search_related('workflow',{something});
#               $v = $v->search_related(advanced_filter->{origHandler},{},unedf);
# }
sub perform_advanced_search
{
    my ($c, $model, $normal, $advancedFilter) = @_;

    # Perform the base search
    my $result = perform_search($model,$normal->{string}, $normal->{columns}, $normal->{prefix},$c);

    if ($normal->{string})
    {
        $c->stash->{folder_recursive} = 1;
    }

    # If we didn't get any results then just return without bothering
    # to do anything else
    if(not $result)
    {
        return;
    }

    my $prefix = $normal->{prefix} ? $normal->{prefix}.'.' : 'me.';

    # Generate filterHash from columns+parameters
    my $filterHash = {
        base => {},
    };
    foreach my $column (@{$advancedFilter->{columns}})
    {
        (my $name = $column) =~ s/^[^\.]+\.//;
        my $cont = $c->req->param('filter_'.$name);
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
            $filterHash->{base}->{$prefix.$column} = $cont;
        }
    }
    # If we have anything in filterHash, run through it
    foreach my $filter (keys %{$filterHash})
    {
        next if not $filterHash->{$filter};
        if ($filter eq 'base')
        {
            $result = $result->search($filterHash->{base});
        }
        else
        {
            if(not defined $advancedFilter->{origTable})
            {
                croak("origTable not supplied to perform_advanced_search() but related table search is used");
            }
            $result = $result->search_related($filter, $filterHash->{$filter});
            return if not $result;
            $result = $result->search_related($advancedFilter->{origTable},{},undef);
            return if not $result;
        }
    }
    # Return the final search result
    return $result;
}

# Purpose: Generate search SQL
# Usage: my($include, $exclude) = get_search_sql($columns,$string,$prefix,$c);
#
# include is an arrayref to be -or'ed in the search
# exclude (if present) is an arrayref to be -and'ed in the search
sub get_search_SQL
{
    my $columns = shift || [];
    my $string = shift;
    my $prefix = shift;
    my $c = shift;
    if(not $string)
    {
        return;
    }

    my ($include_tokens, $exclude_tokens) = parse_search_string($string,$c);

    my ($include, $exclude);
    if ( $prefix )
    {
        $include = [cross($columns,$include_tokens,'-like',$prefix)];
    }
    else
    {
        $include = [cross($columns,$include_tokens)];
    }
    $exclude = [cross($columns,$exclude_tokens,'not like','')];
    return($include,$exclude);
}

# Summary: This function generates a list of all columns paired with all the search tokens.
# Usage: @fields = cross(\@fields, \@tokens);
# Purpose: This returned array can be used in search and filtering
sub cross {
    my $columns = shift || [];
    my $tokens  = shift || [];
    my $type = shift || '-like';
    my $prefix = @_ ? shift(@_).'.' : 'me.';
    $prefix = '' if $prefix eq '.';
    map {s/%/\\%/g} @$tokens;

    my @include_result;
    foreach my $column (@$columns){
        $column = $prefix.$column;
        push @include_result,
        (map +{$column => {$type => "%$_%"}}, @$tokens);
    }
    return @include_result;
}

# Purpose: Parse search expressions in a string
# Usage: my($includeStrings, $excludeStrings) = parse_search_string($string,$c);
#
# This will interperate various common serach expressions found in the
# supplied string and return two arrayrefs. The first contains a list
# of strings that should be searched ofr, the second contains a list
# of strings to exclude.
#
# Supported expressions:
# -remove           don't include the word supplied
# "hello world"     include the string exactly as typed
# +include          include the word supplied, the + is just ignored
# +"hello world"    same as "hello world"
# -"hello world"    don't include the exact string supplied
sub parse_search_string
{
    my $string = shift;
    my $c = shift;
    $string = decode_entities($string);
    my @split = split(/\s+/,$string);

    if(not $string =~ /("|-)/)
    {
        return \@split;
    }

    my $conc;
    my @include_result;
    my @exclude_result;
    my $currCon = \@include_result;
    foreach my $str (@split)
    {
        if (not defined $conc and $str =~ /^-/)
        {
            $currCon = \@exclude_result;
        }
        if ($str =~ s/^"//)
        {
            if ($str =~ /"$/)
            {
                push(@{$currCon},$str);
            }
            else
            {
                $conc = $str;
            }
        }
        elsif(defined $conc)
        {
            if ($str =~ s/"$//)
            {
                $conc .= ' '.$str;
                push(@{$currCon},$conc);
                $conc = undef;
                $currCon = \@include_result;
            }
            else
            {
                $conc .= ' '.$str;
            }
        }
        else
        {
            if ($str =~ s/^\-//)
            {
                push(@exclude_result,$str);
            }
            else
            {
                $str =~ s/^\+//;
                $str =~ s/\\+/+/g;
                push(@include_result, $str);
            }
        }
    }

    if ($conc)
    {
        push(@{$currCon}, $conc);
    }

    return (\@include_result,\@exclude_result);
}
