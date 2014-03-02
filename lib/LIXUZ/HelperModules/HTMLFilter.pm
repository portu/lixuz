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

# LIXUZ::HelperModules::HTMLFilter
#
# This module assists in filtering out nasties from HTML
# in articles.
#
# It exports nothing by default, you need to explicitly import the
# functions you want.
package LIXUZ::HelperModules::HTMLFilter;
use strict;
use warnings;
use HTML::Normalize;
use HTML::Restrict;
use Exporter qw(import);
our @EXPORT_OK = qw(filter_string);

# Summary: Remove HTML cruft from a string
# Usage: new_string = filter_string(old_string);
# Note: If you try to filter undef then this will return '' (not undef)
sub filter_string
{
	my $string = shift;
    if (!defined $string)
    {
        return '';
    }
    # Filter away unwanted HTML elements and attributes
	my $hr = HTML::Restrict->new(
        # These are the elements that are allowed, along with any attributes allowed.
        # Everything else gets removed.
        rules => {
            b => [],
            i => [],
            u => [],
            a => [qw(href title target)],
            p => [qw(style)],
            hr => [],
            br => [],
            h1 => [],
            h2 => [],
            h3 => [],
            h4 => [],
            h5 => [],
            div => [qw(name uid id style class)],
            img => [qw(src alt style class width height align)],
            object => [qw(width height data type class classid align codebase)],
            embed => [qw(src quality width height type pluginspage align allowscriptaccess class name)],
            span => [qw(style)],
            param => [qw(name value)],
            video => [qw(src class style)],
            audio => [qw(src class style)],
            iframe => [qw(src width height frameborder class type title)],
            li => [],
            ul => [],
            ol => [],
            section => [],
            nav => [],
            footer => [],
            table => [qw(border style class cellspacing cellpadding)],
            tbody => [],
            tr => [],
            td => [qw(width valign colspan)],
            th => [qw(width valign colspan)],
            strong => [],
            em => [],
        },
        uri_schemes => [ undef, 'http','https','tel','mailto' ]
    );
    $string = $hr->process( $string );
    # Repair tag soup
    my $normalizer = HTML::Normalize->new(
        -compact => 0,
        -unformatted => 1,
        -html => $string,
    );
    return $normalizer->cleanup();
}

1;
