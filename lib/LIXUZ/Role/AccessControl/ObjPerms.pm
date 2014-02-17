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

package LIXUZ::Role::AccessControl::ObjPerms;

use Moose::Role;
with 'LIXUZ::Role::AccessControl';
with 'LIXUZ::Role::AccessControl::ObjCache';
with 'LIXUZ::Role::AccessControl::PermChecker';
requires 'get_object_perm';

sub can_write
{
    my $self = shift;
    my $object = shift;
    my $perm = $self->_getPermFromConsumer($object);
    return $self->val_is_writable($perm);
}

sub can_read
{
    my $self = shift;
    my $object = shift;
    my $perm = $self->_getPermFromConsumer($object);
    return $self->is_readable($perm);
}

sub _getPermFromConsumer
{
    my $self = shift;
    my $object = shift;
    if(my $cached = $self->cache($object))
    {
        return $cached;
    }
    my $value = $self->get_object_perm($object);
    $self->setCache($object,$value);
    return $value;
}

1;

=head1 SUMMARY

LIXUZ::Role::AccessControl::ObjPerms - frontend access control functions

=head1 DESCRIPTION

This role provides front-end functions for an object that provides get_object_perm.

=head1 PUBLIC METHODS

=over

=item can_read($object)

Returns true if the current user is permitted to read from the object.

=item can_writer($object)

Returns true if the current user is permitted to writer to the object.

=back
