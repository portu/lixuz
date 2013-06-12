package LIXUZ::Schema::LzFieldValue;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';


=head1 NAME

LIXUZ::Schema::LzFieldValue

=cut

__PACKAGE__->table("lz_field_value");

=head1 ACCESSORS

=head2 field_id

  data_type: 'integer'
  is_nullable: 0

=head2 module_id

  data_type: 'integer'
  is_nullable: 0

=head2 value

  data_type: 'text'
  is_nullable: 1

=head2 dt_value

  data_type: 'datetime'
  is_nullable: 1

=head2 module_name

  data_type: 'enum'
  extra: {list => ["articles","workflow","users","roles","folders","templates","files"]}
  is_nullable: 0

=head2 revision

  data_type: 'integer'
  default_value: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "field_id",
  { data_type => "integer", is_nullable => 0 },
  "module_id",
  { data_type => "integer", is_nullable => 0 },
  "value",
  { data_type => "text", is_nullable => 1 },
  "dt_value",
  { data_type => "datetime", is_nullable => 1 },
  "module_name",
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
    is_nullable => 0,
  },
  "revision",
  { data_type => "integer", default_value => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("field_id", "module_id", "revision");


# Created by DBIx::Class::Schema::Loader v0.07002 @ 2012-09-17 11:54:40
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:KJTseKaS13xYFg0bpcGExg

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

__PACKAGE__->belongs_to('field' => 'LIXUZ::Schema::LzField','field_id');
__PACKAGE__->might_have('article' => 'LIXUZ::Schema::LzArticle',
    {
        'foreign.article_id' => 'self.module_id',
        'foreign.revision' => 'self.revision',
    });

use Moose;
with 'LIXUZ::Role::Serializable';

sub _serializeExtra
{
    return [ 'human_value' ];
}
sub _serializeIgnore
{
    return [ 'dt_value' ];
}

around 'value' => sub
{
    my $orig = shift;
    my $self = shift;
    if (@_)
    {
        return $self->set_column( $self->field->storage_type, @_ );
    }
    else
    {
        return $self->get_column( $self->field->storage_type );
    }
};

sub human_value
{
    my $self = shift;
    my $val = $self->value;
    if ($self->field->field_type eq 'user-pulldown')
    {
        $val =~ s/^\d+\D+//g;
        my $ret = $self->result_source->schema->resultset('LzFieldOptions')->find({ option_id => $val, field_id => $self->field_id });
        if ($ret)
        {
            $val = $ret->option_name;
        }
        else
        {
            $val = $self->value;
        }
    }
    return $val;
}

1;


# You can replace this text with custom content, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
