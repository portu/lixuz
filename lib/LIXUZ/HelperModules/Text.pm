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

# LIXUZ::HelperModules::Text
# 
# This contains various generic text processing functions
package LIXUZ::HelperModules::Text;

use strict;
use warnings;
use Carp;
use constant {
    true => 1,
    false => 0,
};
use Exporter qw(import);
our @EXPORT_OK = qw(sanitizeStringLength);

sub sanitizeStringLength
{
    my $string = shift;
    my @lines;
    my $currentLine = '';
    my @split = split(/ /,$string);

    for(my $i = 0; $i < @split; $i++)
    {
        my $str = $split[$i];
        my $tmpResult;
        if ($currentLine)
        {
            $tmpResult = $currentLine.' ';
        }
        $tmpResult .= $str;

        if(length($tmpResult) > 79)
        {
            push(@lines,$currentLine);
            $currentLine = $str;
        }
        else
        {
            $currentLine = $tmpResult;
        }
    }
    if(length $currentLine > 0)
    {
        push(@lines,$currentLine);
    }
    return join("\n",@lines);
}

1;
