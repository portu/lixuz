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

package LIXUZ::Schema::LzArticleLock;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';


=head1 NAME

LIXUZ::Schema::LzArticleLock

=cut

__PACKAGE__->table("lz_article_lock");

=head1 ACCESSORS

=head2 article_id

  data_type: 'integer'
  is_nullable: 0

=head2 locked_by_user

  data_type: 'integer'
  is_nullable: 0

=head2 locked_at

  data_type: 'timestamp'
  default_value: current_timestamp
  is_nullable: 0

=head2 updated_at

  data_type: 'datetime'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "article_id",
  { data_type => "integer", is_nullable => 0 },
  "locked_by_user",
  { data_type => "integer", is_nullable => 0 },
  "locked_at",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 0,
  },
  "updated_at",
  { data_type => "datetime", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("article_id");


# Created by DBIx::Class::Schema::Loader v0.07002 @ 2011-01-17 10:17:20
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:l4F31x5Xl1Gbtg/Ih4knyg
#__PACKAGE__->belongs_to('article' => 'LIXUZ::Schema::LzArticle','article_id');
__PACKAGE__->belongs_to('user' => 'LIXUZ::Schema::LzUser','locked_by_user');

use Moose;
with 'LIXUZ::Role::Serializable';


# You can replace this text with custom content, and it will be preserved on regeneration
1;


# You can replace this text with custom content, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
