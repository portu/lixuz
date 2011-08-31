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

package LIXUZ::Role::AccessControl::PermChecker;

use Moose::Role;

sub is_readable
{
    my $self = shift;
    my $val  = shift;
    if ($val == 2 || $val >= 4)
    {
        return 1;
    }
    else
    {
        return 0;
    }
}

sub val_is_writable
{
    my $self = shift;
    my $val  = shift;
    if ($val == 6)
    {
        return 1;
    }
    else
    {
        return 0;
    }
}

1;
