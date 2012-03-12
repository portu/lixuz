package LIXUZ::Schema::LzRssArticle;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';


=head1 NAME

LIXUZ::Schema::LzRssArticle

=cut

__PACKAGE__->table("lz_rss_article");

=head1 ACCESSORS

=head2 rss_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 guid

  data_type: 'varchar'
  is_nullable: 0
  size: 129

=head2 pubdate

  data_type: 'datetime'
  is_nullable: 1

=head2 title

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 lead

  data_type: 'text'
  is_nullable: 1

=head2 link

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 source

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 deleted

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 1

=head2 status

  data_type: 'enum'
  default_value: 'Inactive'
  extra: {list => ["Active","Inactive"]}
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "rss_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "guid",
  { data_type => "varchar", is_nullable => 0, size => 129 },
  "pubdate",
  { data_type => "datetime", is_nullable => 1 },
  "title",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "lead",
  { data_type => "text", is_nullable => 1 },
  "link",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "source",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "deleted",
  { data_type => "tinyint", default_value => 0, is_nullable => 1 },
  "status",
  {
    data_type => "enum",
    default_value => "Inactive",
    extra => { list => ["Active", "Inactive"] },
    is_nullable => 1,
  },
);
__PACKAGE__->set_primary_key("rss_id");
__PACKAGE__->add_unique_constraint("guid", ["guid"]);


# Created by DBIx::Class::Schema::Loader v0.07002 @ 2011-01-17 10:17:20
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:itNTxGpK0qKXMCWLnXR+EA

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

use LIXUZ::HelperModules::Calendar qw(datetime_from_SQL);
 
# Summary: Stay compatible with LzArticle, return link for url
sub url { my $self = shift; return $self->link }
sub get_url { my $self = shift; return $self->link }
sub get_absolute_url { my $self = shift; return $self->link }

# Summary: Stay compatible with LzArticle, return shortened title
sub shorttitle { return LIXUZ::Schema::LzArticle::shorttitle(@_); }

# Summary: Get the publish time in a human format
# Usage: string = article->human_publish_time();
sub human_publish_time
{
    my $self = shift;
    return datetime_from_SQL($self->pubdate);
}

# Summary: Return the domain name it links to
# Usage: string = article->domain_name();
sub domain_name
{
    my $self = shift;
    my $sourceDomain = $self->link;
    $sourceDomain =~ s/^http...(www\.)?//g;
    $sourceDomain =~ s/^([^\/]+).*/$1/g;
    return $sourceDomain;
}

# These are stubs that makes LzRssArticle more compatible with LzArticle.
# They are all no-ops.
sub get_fileSpot { }
sub in_category { }

1;


# You can replace this text with custom content, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
