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

package LIXUZ::Schema::LzKeyValue;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';


=head1 NAME

LIXUZ::Schema::LzKeyValue

=cut

__PACKAGE__->table("lz_key_value");

=head1 ACCESSORS

=head2 keyvalue_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 thekey

  data_type: 'char'
  is_nullable: 0
  size: 156

=head2 value

  data_type: 'text'
  is_nullable: 1

=head2 type

  data_type: 'enum'
  extra: {list => ["dictionary","url"]}
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "keyvalue_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "thekey",
  { data_type => "char", is_nullable => 0, size => 156 },
  "value",
  { data_type => "text", is_nullable => 1 },
  "type",
  {
    data_type => "enum",
    extra => { list => ["dictionary", "url"] },
    is_nullable => 0,
  },
);
__PACKAGE__->set_primary_key("keyvalue_id");


# Created by DBIx::Class::Schema::Loader v0.07002 @ 2011-01-17 10:17:20
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Qh84XGQPaJpz5nDOF0k30w


# You can replace this text with custom content, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
