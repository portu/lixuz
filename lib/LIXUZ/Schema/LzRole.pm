package LIXUZ::Schema::LzRole;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';


=head1 NAME

LIXUZ::Schema::LzRole

=cut

__PACKAGE__->table("lz_role");

=head1 ACCESSORS

=head2 role_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 role_name

  data_type: 'varchar'
  is_nullable: 1
  size: 100

=head2 role_status

  data_type: 'enum'
  default_value: 'Active'
  extra: {list => ["Active","Inactive"]}
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "role_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "role_name",
  { data_type => "varchar", is_nullable => 1, size => 100 },
  "role_status",
  {
    data_type => "enum",
    default_value => "Active",
    extra => { list => ["Active", "Inactive"] },
    is_nullable => 1,
  },
);
__PACKAGE__->set_primary_key("role_id");


# Created by DBIx::Class::Schema::Loader v0.07002 @ 2011-01-17 10:17:20
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:5nscnoZ4NHaZIYtj3EVgHg

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

__PACKAGE__->has_many(users => 'LIXUZ::Schema::LzUser','role_id');
__PACKAGE__->has_many(actions => 'LIXUZ::Schema::LzRoleAction','role_id');

# Summary: Get all fields (except password) from this user in a hash
# Usage: object->get_everything();
# Returns: Hash with field => value pairs.
sub get_everything
{
    my $self = shift;
    my %Return;
    # Password omitted on purpose.
    foreach my $col( qw(role_id role_name role_status) )
    {
        $Return{$col} = $self->get_column($col);
    }
    return(\%Return);
}

# Summary: Check if a role is active
# Usage: object->is_active();
# Returns: Boolean, true if role is active
sub is_active
{
    my $self = shift;
    if(not $self->role_status eq 'Active')
    {
        return();
    }
    return 1;
}
1;


# You can replace this text with custom content, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
