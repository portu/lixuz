package LIXUZ::Schema::LzFieldModule;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';


=head1 NAME

LIXUZ::Schema::LzFieldModule

=cut

__PACKAGE__->table("lz_field_module");

=head1 ACCESSORS

=head2 field_module_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 field_id

  data_type: 'integer'
  is_nullable: 0

=head2 module

  data_type: 'enum'
  extra: {list => ["articles","workflow","users","roles","folders","templates","files"]}
  is_nullable: 0

=head2 object_id

  data_type: 'integer'
  is_nullable: 1

=head2 position

  data_type: 'smallint'
  is_nullable: 1

=head2 enabled

  data_type: 'tinyint'
  default_value: 1
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "field_module_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "field_id",
  { data_type => "integer", is_nullable => 0 },
  "module",
  {
    data_type => "enum",
    extra => {
      list => [
        "articles",
        "workflow",
        "users",
        "roles",
        "folders",
        "templates",
        "files",
      ],
    },
    is_nullable => 0,
  },
  "object_id",
  { data_type => "integer", is_nullable => 1 },
  "position",
  { data_type => "smallint", is_nullable => 1 },
  "enabled",
  { data_type => "tinyint", default_value => 1, is_nullable => 1 },
);
__PACKAGE__->set_primary_key("field_module_id");


# Created by DBIx::Class::Schema::Loader v0.07002 @ 2012-03-12 12:51:38
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:fsoAA/MeNczxtzOttldLuQ

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
with 'LIXUZ::Role::Serializable';

sub _serializeExtra
{
    return [ 'field' ];
}

__PACKAGE__->belongs_to('field' => 'LIXUZ::Schema::LzField','field_id');

# You can replace this text with custom content, and it will be preserved on regeneration
1;


# You can replace this text with custom content, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
