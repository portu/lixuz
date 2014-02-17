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

package LIXUZ::Role::AccessControl::Model;

use Moose::Role;
with 'LIXUZ::Role::AccessControl';
with 'LIXUZ::Role::AccessControl::ObjCache';
with 'LIXUZ::Role::AccessControl::PermChecker';
use LIXUZ::HelperModules::AccessControl::Folders;

has 'aclObject' => (
    is => 'rw',
    isa => 'Object',
    builder => '_getAclObject',
    lazy => 1,
    );

has 'c' => (
    is => 'rw',
    weak_ref => 1,
    isa => 'Ref',
    required => 0,
);

sub get_object_id
{
    my $self = shift;
    if ($self->get_object_type eq 'folder')
    {
        return $self->folder_id;
    }
}

sub get_object_type
{
    my $self = shift;
    if ($self->isa('LIXUZ::Schema::LzFolder'))
    {
        return 'folder';
    }
}

sub _getAclObject
{
    my $self = shift;

    if ($self->isa('LIXUZ::Schema::LzFolder'))
    {
        return LIXUZ::HelperModules::AccessControl::Folders->new(c => $self->c);
    }
    else
    {
        die('_getAclObject: consuming class is not one AC::Model recognizes: "'.ref($self).'"');
    }
}

sub can_read
{
    my $self = shift;
    my $c = shift;
    $self->c($c);

    my $cached = $self->m_try_cache('read');
    return $cached if defined $cached;

    return $self->aclObject->can_read($self);
}

sub can_write
{
    my $self = shift;
    my $c = shift;
    $self->c($c);

    my $cached = $self->m_try_cache('write');
    return $cached if defined $cached;

    return $self->aclObject->can_write($self);
}

sub m_try_cache
{
    my $self = shift;

    # Super users have free reign
    if ($self->c->user->super_user)
    {
        return 1;
    }

    my $type = shift;

    if (defined(my $cached = $self->cache($self)))
    {
        if ($type eq 'write')
        {
            return $self->val_is_writable($cached);
        }
        else
        {
            return $self->is_readable($cached);
        }
    }
    return;
}

sub check_write
{
    my $self = shift;
    if(not $self->can_write(@_))
    {
        $self->c->user->access_denied();
    }
    return 1;
}

sub check_read
{
    my $self = shift;
    if(not $self->can_read(@_))
    {
        $self->c->user->access_denied();
    }
    return 1;
}

1;
__END__

=head1 SUMMARY

LIXUZ::Role::AccessControl::Model - access control checks on a model object

=head1 DESCRIPTION

This role provides access control checks for model objects (ie. LzFolder). It
implements the ACL, ObjCache and PermChecker interfaces, and is consumable by
models for easy ACL checks directly on the object.

=head1 PUBLIC METHODS

=over

=item can_read($c)

Returns true if the current user is permitted to read from the object.

=item can_writer($c)

Returns true if the current user is permitted to writer to the object.

=item check_read($c)

Returns true if the current user is permitted to read from the object,
otherwise it aborts processing and displays an access denied page.

=item check_write($c)

Returns true if the current user is permitted to write to the object,
otherwise it aborts processing and displays an access denied page.

=back
