package LIXUZ::Schema::LzTimeEntry;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';


=head1 NAME

LIXUZ::Schema::LzTimeEntry

=cut

__PACKAGE__->table("lz_time_entry");

=head1 ACCESSORS

=head2 time_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 user_id

  data_type: 'integer'
  is_nullable: 0

=head2 time_start

  data_type: 'datetime'
  is_nullable: 0

=head2 time_end

  data_type: 'datetime'
  is_nullable: 0

=head2 last_seen

  data_type: 'datetime'
  is_nullable: 0

=head2 ip_start

  data_type: 'varchar'
  is_nullable: 1
  size: 50

=head2 ip_end

  data_type: 'varchar'
  is_nullable: 1
  size: 50

=head2 tt_status

  data_type: 'integer'
  default_value: 0
  is_nullable: 1

=head2 entry_type

  data_type: 'enum'
  extra: {list => ["manually","auto"]}
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "time_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "user_id",
  { data_type => "integer", is_nullable => 0 },
  "time_start",
  { data_type => "datetime", is_nullable => 0 },
  "time_end",
  { data_type => "datetime", is_nullable => 0 },
  "last_seen",
  { data_type => "datetime", is_nullable => 0 },
  "ip_start",
  { data_type => "varchar", is_nullable => 1, size => 50 },
  "ip_end",
  { data_type => "varchar", is_nullable => 1, size => 50 },
  "tt_status",
  { data_type => "integer", default_value => 0, is_nullable => 1 },
  "entry_type",
  {
    data_type => "enum",
    extra => { list => ["manually", "auto"] },
    is_nullable => 1,
  },
);
__PACKAGE__->set_primary_key("time_id");


# Created by DBIx::Class::Schema::Loader v0.07002 @ 2012-08-16 11:28:06
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:RDSDHVvAu7Gz3vhVt6vVNw


# You can replace this text with custom content, and it will be preserved on regeneration

__PACKAGE__->belongs_to('timeEntryUser' => 'LIXUZ::Schema::LzUser', { 'foreign.user_id' => 'self.user_id' });

sub timetracker_status
{
    my $self = shift;
    return $self->tt_status;
}
__PACKAGE__->meta->make_immutable;
1;
