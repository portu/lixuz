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

# LIXUZ::HelperModules::SimpleFormValidator
package LIXUZ::HelperModules::SimpleFormValidator;

use strict;
use warnings;
use Exporter qw(import);
our @EXPORT_OK = qw(simple_validate_form);
use constant {
    true => 1,
    false => 0,
    };

# Summary: This is a simple form validator.
# Usage:
#   simple_validate_form($c,\%formInfo);
# %formInfo:
# {
#   field_name => {
#       required => bool,
#       validate_regex = 'regex string',
#       max_length => int,
#       min_length => int,
#       error_msg => string,
#   },
# }
sub simple_validate_form
{
    my($c,$fields) = @_;

    foreach my $f (keys(%{$fields}))
    {
        my $k = $fields->{$f};
        my $val = $c->req->param($f);
        my $message = defined $k->{error_msg} ? $k->{error_msg} : 'The field '.$k.' was invalid';
        if (not $k->{required} && not $f)
        {
            next;
        }
        elsif ($k->{required} && not $f)
        {
            return (false,$message);
        }
        elsif (defined $k->{min_length} and not length($val) >= $k->{min_length})
        {
            return (false,$message);
        }
        elsif (defined $k->{max_length} and not length($val) <= $k->{max_length})
        {
            return (false,$message);
        }
        elsif(defined $k->{validate_regex} and not $val =~ /$k->{validate_regex}/)
        {
            return (false,$message);
        }
    }
    return (true,undef);
}

1;
