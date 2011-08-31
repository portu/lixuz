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

# LIXUZ::HelperModules::Lists
#
package LIXUZ::HelperModules::Lists;

use strict;
use warnings;
use Exporter qw(import);
use LIXUZ::HelperModules::JSON qw(json_response json_error);
our @EXPORT_OK = qw(reply_json_list);

# FIXME: Allow handleListRequestJSON in the list role perform this on
#       a pre-made object instead
#
# Purpose: Reply a list in JSON, for use in objectSelectors.
# Usage: reply_json_list($c,$object,[ column names (to use in $object->get_column()) ] or \&codeRef, $mode?);
# $c is the catalyst object
# $object is the model object
#
# The third parameter can be two things, which defines how this function
# will build its data list:
# [] an arrayref of column names to include in each line
#   or
# \& a coderef
#
# If we get an arrayref then we will build an array of arrayrefs into
# list_ref in the reply.
#
# If we get a coderef then we will build a string of returned data
# from coderef->($c,$currentObject); into files_grid in the reply.
#
# However, if $mode is supplied and is the string SINGLE, then the coderef
# will get the entire list and be expected to return the complete
# HTML.
sub reply_json_list
{
    my $c = shift;
    my $object = shift;
    my $action = shift;
    my $mode = shift;
    my $reply = { URL => $c->req->uri->as_string};
    if(ref($action) eq 'ARRAY')
    {
        my $contents = [];
        while((defined $object) and (my $oe = $object->next))
        {
            my $instance = {};
            foreach my $ent (@{$action})
            {
                $instance->{$ent} = $oe->get_column($ent);
            }
            push(@{$contents},$instance);
        }
        $reply->{contents} = $contents;
    }
    elsif(ref($action) eq 'CODE' and $mode and $mode eq 'CODE_ARRAY')
    {
        my @data;
        while((defined $object) and (my $gridentry = $object->next))
        {
            my $entry = $action->($c,$gridentry);
            next if not defined $entry;
            push(@data,$entry);
        }
        $reply->{contents} = \@data;
    }
    elsif(ref($action) eq 'CODE')
    {
        my $files_grid;
        if(not $mode or not $mode eq 'SINGLE')
        {
            while((defined $object) and (my $gridentry = $object->next))
            {
                my $addContent = $action->($c,$gridentry);
                next if not defined $addContent;
                $files_grid .= $addContent;
            }
        }
        else
        {
            my $addContent = $action->($c,$object);
            next if not defined $addContent;
            $files_grid = $addContent;
        }
        $reply->{files_grid} = $files_grid;
    }
    else
    {
        croak("Unknown ref supplied to reply_json_list: ".ref($action));
    }
    my $pager = $c->stash->{pager};
    $pager //= $object->pager;
    if(not $pager)
    {
        $c->log->error('reply_json_list(): pager missing!');
        return json_error($c,'INTERNALPAGERMISSING_RJL');
    }
    $reply->{pager} = {};
    $reply->{pager}->{page} = $pager->current_page;
    $reply->{pager}->{pageTotal} = $pager->last_page;
    $reply->{pager}->{resultTotal} = $pager->total_entries;
    return json_response($c,$reply);
}

1;
