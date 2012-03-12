package LIXUZ::Schema::LzRevision;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';


=head1 NAME

LIXUZ::Schema::LzRevision

=cut

__PACKAGE__->table("lz_revision");

=head1 ACCESSORS

=head2 revision_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 type

  data_type: 'enum'
  extra: {list => ["article"]}
  is_nullable: 0

=head2 type_id

  data_type: 'integer'
  is_nullable: 0

=head2 type_revision

  data_type: 'integer'
  is_nullable: 0

=head2 is_latest

  data_type: 'tinyint'
  default_value: 1
  is_nullable: 0

=head2 created_at

  data_type: 'timestamp'
  default_value: current_timestamp
  is_nullable: 0

=head2 committer

  data_type: 'integer'
  is_nullable: 1

=head2 is_latest_in_status

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "revision_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "type",
  { data_type => "enum", extra => { list => ["article"] }, is_nullable => 0 },
  "type_id",
  { data_type => "integer", is_nullable => 0 },
  "type_revision",
  { data_type => "integer", is_nullable => 0 },
  "is_latest",
  { data_type => "tinyint", default_value => 1, is_nullable => 0 },
  "created_at",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 0,
  },
  "committer",
  { data_type => "integer", is_nullable => 1 },
  "is_latest_in_status",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("revision_id");


# Created by DBIx::Class::Schema::Loader v0.07002 @ 2011-03-22 10:56:10
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:vLoGyaaQSJ1UXMp1ZEEurw

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

__PACKAGE__->belongs_to('committed_by','LIXUZ::Schema::LzUser', 'committer');


# You can replace this text with custom content, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
