package LIXUZ::Schema::LzNewsletterSaved;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';


=head1 NAME

LIXUZ::Schema::LzNewsletterSaved

=cut

__PACKAGE__->table("lz_newsletter_saved");

=head1 ACCESSORS

=head2 saved_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 sent_by_user

  data_type: 'integer'
  is_nullable: 0

=head2 from_address

  data_type: 'varchar'
  is_nullable: 1
  size: 254

=head2 subject

  data_type: 'varchar'
  is_nullable: 1
  size: 254

=head2 body

  data_type: 'text'
  is_nullable: 1

=head2 format

  data_type: 'enum'
  extra: {list => ["text","html"]}
  is_nullable: 1

=head2 sent_at

  data_type: 'timestamp'
  default_value: current_timestamp
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "saved_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "sent_by_user",
  { data_type => "integer", is_nullable => 0 },
  "from_address",
  { data_type => "varchar", is_nullable => 1, size => 254 },
  "subject",
  { data_type => "varchar", is_nullable => 1, size => 254 },
  "body",
  { data_type => "text", is_nullable => 1 },
  "format",
  {
    data_type => "enum",
    extra => { list => ["text", "html"] },
    is_nullable => 1,
  },
  "sent_at",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 0,
  },
);
__PACKAGE__->set_primary_key("saved_id");


# Created by DBIx::Class::Schema::Loader v0.07002 @ 2011-01-17 10:17:20
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:kNTzx2FgVtiA4wBAx5bmqA

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


# You can replace this text with custom content, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
