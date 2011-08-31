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

package LIXUZ::Schema::LzLiveComment;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';


=head1 NAME

LIXUZ::Schema::LzLiveComment

=cut

__PACKAGE__->table("lz_live_comment");

=head1 ACCESSORS

=head2 comment_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 article_id

  data_type: 'integer'
  is_nullable: 0

=head2 ip

  data_type: 'char'
  is_nullable: 0
  size: 15

=head2 author_name

  data_type: 'char'
  is_nullable: 1
  size: 128

=head2 subject

  data_type: 'char'
  is_nullable: 1
  size: 255

=head2 body

  data_type: 'text'
  is_nullable: 1

=head2 created_date

  data_type: 'timestamp'
  default_value: current_timestamp
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "comment_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "article_id",
  { data_type => "integer", is_nullable => 0 },
  "ip",
  { data_type => "char", is_nullable => 0, size => 15 },
  "author_name",
  { data_type => "char", is_nullable => 1, size => 128 },
  "subject",
  { data_type => "char", is_nullable => 1, size => 255 },
  "body",
  { data_type => "text", is_nullable => 1 },
  "created_date",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 0,
  },
);
__PACKAGE__->set_primary_key("comment_id");


# Created by DBIx::Class::Schema::Loader v0.07002 @ 2011-01-17 10:17:20
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:DyhZfHDUPF6UTck9TKfxfg

sub article
{
    my $self = shift;
    my $art = $self->result_source->schema->source('LzArticle')->resultset->find({
            article_id => $self->article_id,
            status_id => 2
        });
    return $art;
}

sub shortsubject
{
    my $self = shift;
    my $length = shift;
    $length = $length ? $length : 30;

    my $subject = $self->subject;
    if(not defined $subject or not length($subject) > $length)
    {
        return $subject;
    }

    $subject = substr($subject, 0, $length - 3);
    $subject .='...';
    return $subject;
}

1;


# You can replace this text with custom content, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
