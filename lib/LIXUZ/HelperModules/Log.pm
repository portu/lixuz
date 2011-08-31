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

package LIXUZ::HelperModules::Log;
use Moose;
extends 'Catalyst::Log';
use POSIX qw(strftime);

around '_log' => sub
{
    my $orig    = shift;
    my $self    = shift;
    my $level   = shift;
    my $dt = strftime('%Y-%m-%d %H:%M:%S',localtime);
    $level = sprintf( '%-17s] [%s', $dt, $level);
    return $self->$orig($level,@_);
};

# Make the class immutable. Inlining the constructor isn't possible due to
# the use of the 'around' method modifier above.
__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;
