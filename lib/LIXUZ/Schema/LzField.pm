package LIXUZ::Schema::LzField;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';


=head1 NAME

LIXUZ::Schema::LzField

=cut

__PACKAGE__->table("lz_field");

=head1 ACCESSORS

=head2 field_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 field_name

  data_type: 'varchar'
  is_nullable: 1
  size: 100

=head2 field_type

  data_type: 'enum'
  extra: {list => ["singleline","multiline","user-pulldown","predefined-pulldown","multi-select","checkbox","range","meta-int","meta-date","meta-other","datetime","date"]}
  is_nullable: 1

=head2 field_height

  data_type: 'smallint'
  is_nullable: 1

=head2 field_richtext

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 1

=head2 field_range

  data_type: 'varchar'
  is_nullable: 1
  size: 20

=head2 inline

  data_type: 'varchar'
  is_nullable: 1
  size: 19

=head2 exclusive_module

  data_type: 'enum'
  extra: {list => ["articles","workflow","users","roles","folders","templates","files"]}
  is_nullable: 1

=head2 obligatory

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "field_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "field_name",
  { data_type => "varchar", is_nullable => 1, size => 100 },
  "field_type",
  {
    data_type => "enum",
    extra => {
      list => [
        "singleline",
        "multiline",
        "user-pulldown",
        "predefined-pulldown",
        "multi-select",
        "checkbox",
        "range",
        "meta-int",
        "meta-date",
        "meta-other",
        "datetime",
        "date",
      ],
    },
    is_nullable => 1,
  },
  "field_height",
  { data_type => "smallint", is_nullable => 1 },
  "field_richtext",
  { data_type => "tinyint", default_value => 0, is_nullable => 1 },
  "field_range",
  { data_type => "varchar", is_nullable => 1, size => 20 },
  "inline",
  { data_type => "varchar", is_nullable => 1, size => 19 },
  "exclusive_module",
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
    is_nullable => 1,
  },
  "obligatory",
  { data_type => "tinyint", default_value => 0, is_nullable => 1 },
);
__PACKAGE__->set_primary_key("field_id");


# Created by DBIx::Class::Schema::Loader v0.07002 @ 2012-03-12 12:51:38
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Hcrp8Z9gh+G6i477jYUaOA

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

sub type_name
{
    my($self, $c) = @_;
    my $i18n = $c->stash->{i18n};
    # enum('singleline','multiline','user-pulldown','predefined-pulldown','checkbox')
    my %Map = (
        'singleline' => $i18n->get('Single line'),
        'multiline' => $i18n->get('Multi-line'),
        'user-pulldown' => $i18n->get('Custom pulldown'),
        'range-pulldown' => $i18n->get('Range-defined pulldown'),
        'multi-select' => $i18n->get('Multiple select'),
        'datetime' => $i18n->get('Date/time'),
        'predefined-pulldown' => $i18n->get('Pulldown'),
        'checkbox' => $i18n->get('Checkbox'),
        'range' => $i18n->get('Range'),
        'meta-date' => $i18n->get('Metadata (date)'),
        'meta-int' => $i18n->get('Metadata (integer)'),
    );
    my $type = $self->field_type;
    if(not $type)
    {
        return $i18n->get_advanced('(unknown - not set in database)',{ FIELDNAME => $self->field_type });
    }
    if ($type eq 'user-pulldown' && defined $self->field_range)
    {
        $type = 'range-pulldown';
    }
    $type = $Map{$type};
    if ($type)
    {
        return $type;
    }
    else
    {
        return $i18n->get_advanced('(unknown - "%(FIELDNAME)")',{ FIELDNAME => $self->field_type });
    }
}

sub is_inline
{
    my $self = shift;
    if(defined $self->inline)
    {
        return 1;
    }
    return;
}

sub can_render_for
{
    my $self = shift;
    my $module = shift;
    if(not defined $self->exclusive_module)
    {
        return 1;
    }
    elsif($self->exclusive_module eq $module)
    {
        return 1;
    }
    else
    {
        return;
    }
}

__PACKAGE__->has_many('modules' => 'LIXUZ::Schema::LzFieldModule','field_id');
__PACKAGE__->has_many('values' => 'LIXUZ::Schema::LzFieldValue','field_id');
__PACKAGE__->has_many('options' => 'LIXUZ::Schema::LzFieldOptions','field_id');
1;


# You can replace this text with custom content, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
