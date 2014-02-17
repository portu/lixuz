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

package LIXUZ::HelperModules::AccessControl::Folders;

# The basic user-facing methods can be found in ::PermBase. See that
# for the most commonly used API.

use Moose;
with 'LIXUZ::Role::AccessControl::ObjPerms';

use constant {
    true => 1,
    false => 0,
};

# Lower-level methods

sub get_object_perm
{
    my $self = shift;
    my $folder = shift;
    my @folders = $self->_build_recursive_list($folder);
    my $perm = 6;
    foreach my $f (@folders)
    {
        $perm = $self->get_perm_for_singleFolder($f,$perm);
        last if $perm < 2;
    }
    return $perm;
}

sub get_object_id
{
    shift;
    my $object = shift;
    return $object->folder_id;
}

sub get_object_type
{
    return 'folder';
}

sub get_perm_for_singleFolder
{
    my $self = shift;
    my $folder = shift;
    my $fallback = shift;
    my $value = $fallback;

    my $perms = $self->c->model('LIXUZDB::LzPerms')->search({
            object_type => 'folder',
            object_id => $folder->folder_id,
            -or => [
                { user_id => $self->userId },
                { role_id => $self->roleId },
            ],

        }, { order_by => \'permission DESC' });
    if ($perms->count)
    {
        my $f = $perms->next;
        $value = $f->permission;
    }
    return $value;
}

# Internal methods

sub _build_recursive_list
{
    my $self = shift;
    my $folder = shift;
    my @list = ($folder);
    while($folder = $folder->parent)
    {
        push(@list,$folder);
    }
    return reverse(@list);
}

__PACKAGE__->meta->make_immutable;
__END__

=head1 SUMMARY

LIXUZ::HelperModules::AccessControl::Folders - access control checks for Lixuz folders

=head1 DESCRIPTION

This is a low-level module that provides access to access control checks for
Lixuz folders.  This module is generally not called directly, it just
implements an interface that implements the back-end functions required for
with I<LIXUZ::Role::AccessControl::ObjPerms>. The methods provided in that role
is considered the public interface. Furthermore the module is rarely called by
a user at all, rather mostly being called on an LzFolder object directly, which
will instantiate and call methods on this object as needed.

=head1 METHODS

=over

=item get_object_perm(folder)

Returns the octal representation of the permissions for userId (see ObjPerms) on
this folder.

=item get_object_id()

Returns the folder_id of the currently processing folder

=item get_object_type()

Returns the string 'folder'

=item get_perm_for_singleFolder(folder)

Returns the permissions related to a single folder (not tree).

=back
