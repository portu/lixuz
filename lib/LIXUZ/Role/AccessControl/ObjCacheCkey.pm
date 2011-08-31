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

package LIXUZ::Role::AccessControl::ObjCacheCkey;

use Moose::Role;
requires 'get_object_id';
requires 'get_object_type';

sub ckey
{
    my $self = shift;
    my $obj = shift;
    return 'objperms_'.$self->userId.'_'.$self->roleId.'_'.$self->get_object_type($obj).'_'.$self->get_object_id($obj);
}

1;
