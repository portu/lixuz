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

# LIXUZ::HelperModules::Live::Articles
# 
package LIXUZ::HelperModules::Live::Articles;

use strict;
use warnings;
use Carp;
use Exporter qw(import);
our @EXPORT_OK = qw(get_live_articles_from);

# This is a function that can be called with an article resultset,
# it will then return a resultset where only live articles will be included.
#
# Usage: $object = get_live_articles_from($object, \%optionsHash);
#
# These parameters are optional, and can be supplied in \%optionsHash
# prefix = a prefix to append to each search entry
# overrideLiveStatus = a status id that will be counted as 'live'
# extraLiveStatus = an arrayref of statuses, or a single integer status_id,
#   that will be counted as live in addition to the primary one.
# rows = a limit on rows that gets appended to the search
# order_by = an order by that gets appended to the search
sub get_live_articles_from($;$$)
{
    my($object,$o) = @_;
    $o = defined $o ? $o : {};
    my $searchParams = {};

    $searchParams->{rows} = $o->{rows}
        if(defined($o->{rows}));

    $searchParams->{order_by} = $o->{order_by}
        if(defined($o->{order_by}));

    my @extraLiveStatus;
    if(defined $o->{extraLiveStatus})
    {
        if(ref($o->{extraLiveStatus}))
        {
            @extraLiveStatus = @{$o->{extraLiveStatus}};
        }
        else
        {
            @extraLiveStatus = $o->{extraLiveStatus};
        }
    }
    my $search = { _getLiveSearch($o->{prefix},$o->{overrideLiveStatus},@extraLiveStatus) };
    if(defined $o->{extraLiveStatus} or defined $o->{overrideLiveStatus})
    {
        $searchParams->{join} = 'revisionMeta';
        $search->{'revisionMeta.is_latest_in_status'} = 1;
    }
    if (!ref($object) || !$object->can('search'))
    {
        carp('get_live_articles_from(): Got non-searchable object: '.ref($object));
    }
    return $object->search( $search, $searchParams );
}

# The function that actually does the work
sub _getLiveSearch
{
    my $prefix = shift;
    my $primaryLiveStatus = shift;
    my @extraStatuses = @_;

    $primaryLiveStatus = defined $primaryLiveStatus ? $primaryLiveStatus : 2;
    $prefix = defined $prefix ? $prefix.'.' : '';

    my @liveStatus = ($primaryLiveStatus);
    push(@liveStatus,@extraStatuses);

    my @liveSearch = map { { $prefix.'status_id' => $_ } } @liveStatus;
    return -and => [ trashed => \'!= 1', $prefix.publish_time => \'<= now()', -or => [ { $prefix.expiry_time => \'IS NULL' }, { $prefix.expiry_time => \'> now()' } ], -or => \@liveSearch ];
}

1;
