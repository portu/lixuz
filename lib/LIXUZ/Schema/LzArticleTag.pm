package LIXUZ::Schema::LzArticleTag;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';


=head1 NAME

LIXUZ::Schema::LzArticleTag

=cut

__PACKAGE__->table("lz_article_tag");

=head1 ACCESSORS

=head2 tag_id

  data_type: 'integer'
  is_nullable: 0

=head2 article_id

  data_type: 'integer'
  is_nullable: 0

=head2 added_by

  data_type: 'integer'
  is_nullable: 0

=head2 revision

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "tag_id",
  { data_type => "integer", is_nullable => 0 },
  "article_id",
  { data_type => "integer", is_nullable => 0 },
  "added_by",
  { data_type => "integer", is_nullable => 0 },
  "revision",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("tag_id", "article_id", "revision");


# Created by DBIx::Class::Schema::Loader v0.07002 @ 2011-01-17 10:17:20
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:VmHKi8nq7qEPfwiUtLufPQ

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

__PACKAGE__->belongs_to('tag' => 'LIXUZ::Schema::LzTag', 'tag_id');
with 'LIXUZ::Role::Serializable';

# You can replace this text with custom content, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
