package LIXUZ::Schema::LzWorkflowComments;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';


=head1 NAME

LIXUZ::Schema::LzWorkflowComments

=cut

__PACKAGE__->table("lz_workflow_comments");

=head1 ACCESSORS

=head2 article_id

  data_type: 'integer'
  is_nullable: 0

=head2 user_id

  data_type: 'integer'
  is_nullable: 1

=head2 comment_body

  data_type: 'text'
  is_nullable: 1

=head2 comment_subject

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 written_time

  data_type: 'datetime'
  is_nullable: 1

=head2 comment_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 on_revision

  data_type: 'integer'
  default_value: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "article_id",
  { data_type => "integer", is_nullable => 0 },
  "user_id",
  { data_type => "integer", is_nullable => 1 },
  "comment_body",
  { data_type => "text", is_nullable => 1 },
  "comment_subject",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "written_time",
  { data_type => "datetime", is_nullable => 1 },
  "comment_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "on_revision",
  { data_type => "integer", default_value => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("comment_id");


# Created by DBIx::Class::Schema::Loader v0.07002 @ 2011-01-17 10:17:20
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:m93C0ZDgRwrsCu+fofP4Cg

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
__PACKAGE__->belongs_to('article' => 'LIXUZ::Schema::LzArticle', { 'foreign.article_id' => 'self.article_id', 'foreign.revision' => 'self.on_revision' });
__PACKAGE__->belongs_to('author' => 'LIXUZ::Schema::LzUser', 'user_id');


# You can replace this text with custom content, and it will be preserved on regeneration
1;


# You can replace this text with custom content, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
