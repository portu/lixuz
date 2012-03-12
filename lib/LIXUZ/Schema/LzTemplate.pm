package LIXUZ::Schema::LzTemplate;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';


=head1 NAME

LIXUZ::Schema::LzTemplate

=cut

__PACKAGE__->table("lz_template");

=head1 ACCESSORS

=head2 template_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 name

  data_type: 'varchar'
  is_nullable: 1
  size: 254

=head2 file

  data_type: 'varchar'
  is_nullable: 0
  size: 254

=head2 type

  data_type: 'enum'
  extra: {list => ["list","search","article","include","message","rssimport","email_text","email_html","media"]}
  is_nullable: 1

=head2 apiversion

  data_type: 'integer'
  is_nullable: 0

=head2 uniqueid

  data_type: 'varchar'
  is_nullable: 0
  size: 254

=head2 is_default

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "template_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "name",
  { data_type => "varchar", is_nullable => 1, size => 254 },
  "file",
  { data_type => "varchar", is_nullable => 0, size => 254 },
  "type",
  {
    data_type => "enum",
    extra => {
      list => [
        "list",
        "search",
        "article",
        "include",
        "message",
        "rssimport",
        "email_text",
        "email_html",
        "media",
      ],
    },
    is_nullable => 1,
  },
  "apiversion",
  { data_type => "integer", is_nullable => 0 },
  "uniqueid",
  { data_type => "varchar", is_nullable => 0, size => 254 },
  "is_default",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("template_id");


# Created by DBIx::Class::Schema::Loader v0.07002 @ 2012-03-12 12:51:49
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:TdvoNG2cPGvWdRVDRoB52w

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

use LIXUZ::HelperModules::Templates qw(get_parsed_template_info);

# You can replace this text with custom content, and it will be preserved on regeneration
sub path_to_template_file
{
    my($self,$c) = @_;
    return $c->config->{LIXUZ}->{template_path}.'/'.$self->file;
}

sub get_info
{
    my($self,$c) = @_;
    return get_parsed_template_info($c,$self->path_to_template_file($c));
}
1;


# You can replace this text with custom content, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
