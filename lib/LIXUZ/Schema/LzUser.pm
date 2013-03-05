package LIXUZ::Schema::LzUser;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';


=head1 NAME

LIXUZ::Schema::LzUser

=cut

__PACKAGE__->table("lz_user");

=head1 ACCESSORS

=head2 user_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 role_id

  data_type: 'integer'
  is_nullable: 1

=head2 user_name

  data_type: 'varchar'
  is_nullable: 1
  size: 50

=head2 firstname

  data_type: 'varchar'
  is_nullable: 1
  size: 50

=head2 lastname

  data_type: 'varchar'
  is_nullable: 1
  size: 50

=head2 email

  data_type: 'varchar'
  is_nullable: 1
  size: 100

=head2 password

  data_type: 'varchar'
  is_nullable: 1
  size: 32

=head2 user_status

  data_type: 'enum'
  default_value: 'Active'
  extra: {list => ["Active","Inactive"]}
  is_nullable: 1

=head2 last_login

  data_type: 'timestamp'
  default_value: current_timestamp
  is_nullable: 0

=head2 created

  data_type: 'timestamp'
  default_value: '0000-00-00 00:00:00'
  is_nullable: 0

=head2 lang

  data_type: 'varchar'
  is_nullable: 1
  size: 6

=head2 reset_code

  data_type: 'varchar'
  is_nullable: 1
  size: 50

=cut

__PACKAGE__->add_columns(
  "user_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "role_id",
  { data_type => "integer", is_nullable => 1 },
  "user_name",
  { data_type => "varchar", is_nullable => 1, size => 50 },
  "firstname",
  { data_type => "varchar", is_nullable => 1, size => 50 },
  "lastname",
  { data_type => "varchar", is_nullable => 1, size => 50 },
  "email",
  { data_type => "varchar", is_nullable => 1, size => 100 },
  "password",
  { data_type => "varchar", is_nullable => 1, size => 32 },
  "user_status",
  {
    data_type => "enum",
    default_value => "Active",
    extra => { list => ["Active", "Inactive"] },
    is_nullable => 1,
  },
  "last_login",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 0,
  },
  "created",
  {
    data_type     => "timestamp",
    default_value => "0000-00-00 00:00:00",
    is_nullable   => 0,
  },
  "lang",
  { data_type => "varchar", is_nullable => 1, size => 6 },
  "reset_code",
  { data_type => "varchar", is_nullable => 1, size => 50 },
);
__PACKAGE__->set_primary_key("user_id");


# Created by DBIx::Class::Schema::Loader v0.07002 @ 2012-03-12 12:51:58
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Vnn3F+yuAP+zxXqAWYy/OA

# LIXUZ content management system
# Copyright (C) Utrop A/S Portu media & Communications 2008-2012
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


__PACKAGE__->belongs_to('role' => 'LIXUZ::Schema::LzRole', 'role_id');
with 'LIXUZ::Role::Serializable';

use Moose;
use Digest::MD5 qw(md5_hex);

has 'c' => (
    is => 'rw',
    weak_ref => 1,
    isa => 'Ref',
    required => 0,
    # This is used to bootstrap $c->user->can_access. Called by Admin.pm's auto sub.
    writer => 'set_c',
);

sub _serializeIgnore
{
    return [ 'password', 'last_login', 'created', 'email', 'lang', 'reset_code' ];
}

# Summary: Encrypts the users password and changes it in the database
# Usage: object->set_password(NEW_PASSWORD);
# Returns: Nothing
sub set_password
{
    my $self = shift;
    my $password = shift;
    $password = md5_hex($password);
    $self->set_column('password',$password);
}

sub check_password
{
    my $self = shift;
    my $password = shift;
    $password = md5_hex($password);
    if ($self->password eq $password)
    {
        return 1;
    }
    return;
}

# Summary: Get all fields (except password) from this user in a hash
# Usage: object->get_everything();
# Returns: Hash with field => value pairs.
sub get_everything
{
    my $self = shift;
    my %Return;
    # Password omitted on purpose.
    foreach my $col( qw(user_id user_name firstname lastname email user_status last_login created lang) )
    {
        $Return{$col} = $self->get_column($col);
    }
    $Return{role} = $self->role;
    return(\%Return);
}

# Summary: Check if a user is fully active (ie. both the user and role is active)
# Usage: object->is_active();
# Returns: Boolean, true if account+role is active
sub is_active
{
    my $self = shift;
    if(not $self->user_status eq 'Active' or not $self->role or not $self->role->role_status eq 'Active')
    {
        return();
    }
    return 1;
}

sub verboseName
{
    my $self = shift;
    return $self->firstname.' '.$self->lastname.' ('.$self->user_name.')';
}

sub name
{
    my $self = shift;
    return $self->firstname.' '.$self->lastname;
}

sub verboseEmail
{
    my $self = shift;
    return $self->firstname.' '.$self->lastname.' <'. $self->email.'>';
}

sub can_access
{
    my $self = shift;
    return $self->_accessWrap('can_access',@_);
}

sub super_user
{
    my $self = shift;
    return $self->_accessWrap('can_access','SUPER_USER');
}

sub check_access
{
    my $self = shift;
    return $self->_accessWrap('check_access',@_);
}

sub last_denied
{
    my $self = shift;
    return $self->{ACL}->last_denied(@_);
}

sub access_denied
{
    my $self = shift;
    return $self->{ACL}->access_denied(@_);
}

sub _accessWrap
{
    my $self = shift;
    my $method = shift;
    if (scalar(@_) > 2)
    {
        $self->c(shift(@_));
    }
    die('$c is missing') if not defined $self->c;
    if (!$self->{ACL})
    {
        $self->{ACL} = LIXUZ::HelperModules::AccessControl->new( c => $self->c, userId => $self->user_id, roleId => $self->role_id );
    }
    if(scalar(@_) == 2)
    {
        # ID-based
    }
    else
    {
         # Path-based
         return $self->_accessWrapRun($method,@_);
    }
}

sub _accessWrapRun
{
    my $self = shift;
    my $method = shift;
    if ($method eq 'check_access')
    {
        return $self->{ACL}->check_access(@_);
    }
    else
    {
        return $self->{ACL}->can_access_path(@_);
    }
}

# You can replace this text with custom content, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
