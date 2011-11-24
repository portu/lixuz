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
use HTML::Scrubber;
use HTML::Normalize;
use Exporter qw(import);
our @EXPORT_OK = qw(filter_string);

# Summary: Remove HTML cruft from a string
# Usage: new_string = filter_string(old_string);
sub filter_string
{
	my $string = shift;
    # Scrub
	my $scrubber = HTML::Scrubber->new(
		allow => [ 'b', 'i', 'u', 'a', 'p','hr','br', 'h1', 'h2', 'h3', 'h4', 'h5', 'div', 'img', 'object', 'embed', 'span', 'param', 'video', 'audio', 'iframe', 'li', 'ul', 'ol', 'section', 'nav', 'footer', 'table','tbody','tr','td','th','strong' ],
		comment => 0,
		process => 0,
		script => 0,
		style => 0,
	);
    $scrubber->rules(
        table => {
            border => 1,
            style => 1,
            class => 1,
            cellspacing => 1,
            cellpadding => 1,
        },
        td => {
            width => 1,
            valign => 1,
        },
        th => {
            width => 1,
            valign => 1,
        },
        img => {
            src => 1,
            alt => 1,
            style => 1,
            class => 1,
            width => 1,
            height => 1,
        },
        div => {
            name => 1,
            uid => 1,
            id => 1,
            style => 1,
            class => 1,
        },
        object => {
            width => 1,
            height => 1,
            data => 1,
            type => 1,
            class => 1,
            classid => 1,
            align => 1,
            codebase => 1,
        },
        embed => {
            src => 1,
            quality => 1,
            width => 1,
            height => 1,
            type => 1,
            pluginspage => 1,
            align => 1,
            allowScriptAccess => 1,
            class => 1,
            name => 1,
        },
        iframe => {
            src => 1,
            width => 1,
            height => 1,
            frameborder => 1,
            class => 1,
            type => 1,
            title => 1,
        },
        param => {
            name => 1,
            value => 1,
        },
        video => {
            src => 1,
            class => 1,
            style => 1,
        },
        audio => {
            src => 1,
            class => 1,
            style => 1,
        },
        a => {
            href => 1,
            title => 1,
            target => 1,
        },
    );
	$string = $scrubber->scrub($string);
    # Repair tag soup
    my $normalizer = HTML::Normalize->new(
        -compact => 0,
        -unformatted => 1,
        -html => $string,
    );
    return $normalizer->cleanup();
}

1;
