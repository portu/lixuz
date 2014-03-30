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

# LIXUZ::HelperModules::Cache
package LIXUZ::HelperModules::Cache;
use strict;
use warnings;
use Exporter qw(import);
our @EXPORT_OK = qw(get_ckey);
our @EXPORT = qw(CT_DEFAULT CT_24H CT_1H);
use constant CT_1H => 3600;
use constant CT_DEFAULT => 86400;
use constant CT_24H => 86400;
use Carp;

=pod

=head1 SUMMARY

LIXUZ::HelperModules::Cache - Cache helper functions for Lixuz

=head1 DESCRIPTION

This module provides a single function, as well as three constants
that can assist with caching within Lixuz.

=head1 FUNCTIONS

=over

=item get_ckey($component,$data,$uid)

Purpose: Get a standardized cache key string

This function is here to assist in getting predictable cache
keys, so that they can be repeated elsewhere in the code without
having to copy keys around the app.

Ie. if one wanted the cache key for the body of article no.
123, one would do $key = get_ckey('article','body',123);
Which is nice and predictable.

It takes three arguments:

$component is the primary source/use of the data. For instance 'article'
if it is related to an article.

$data      is the type of data related to the $component, for instance
'body' for the article body

$uid       is a unique ID related to the data and component, for instance
the article ID for an article

Any of the arguments can be undef, and lixuz will just default them,
however you must supply at least one valid argument.

get_ckey is case insensitive and will lowecase everything, so you are
free to use uppercase or camelcase in your calls to increase readability
- get_ckey won't care either way.

=back

=cut
sub get_ckey
{
    my($component,$data,$uid) = @_;

    if(not @_)
    {
        croak('get_ckey() got nothing useful to construct a cache key from!');
    }

    $component = $component ? $component : 'lz';
    $data = $data ? $data : 'core';
    $uid = $uid ? $uid : 'base';

    my $ckey = lc($component.'_'.$data.'_'.$uid);
    return $ckey;
}

=pod

=head1 CONSTANTS

=over

=item CT_DEFAULT, CT_24H

Integer constants, the number of seconds in a day. CT_DEFAULT should be used
over CT_24H unless you know that exactly 24 hours are what you want. CT_DEFAULT
is subject to change at any time.

=item CT_1H

Integer constant, the number of seconds in one hour.

=back

=cut

1;
