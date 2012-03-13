package LIXUZ::Schema::LzFileFolder;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';


=head1 NAME

LIXUZ::Schema::LzFileFolder

=cut

__PACKAGE__->table("lz_file_folder");

=head1 ACCESSORS

=head2 file_id

  data_type: 'integer'
  is_nullable: 0

=head2 folder_id

  data_type: 'integer'
  is_nullable: 0

=head2 primary_folder

  data_type: 'tinyint'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "file_id",
  { data_type => "integer", is_nullable => 0 },
  "folder_id",
  { data_type => "integer", is_nullable => 0 },
  "primary_folder",
  { data_type => "tinyint", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("file_id", "folder_id");


# Created by DBIx::Class::Schema::Loader v0.07002 @ 2012-03-12 12:51:38
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:wwYzMNc1UMV+oNgttCwqNw
__PACKAGE__->belongs_to('folder' => 'LIXUZ::Schema::LzFolder', 'folder_id');
__PACKAGE__->belongs_to('file' => 'LIXUZ::Schema::LzFile', 'file_id');


# You can replace this text with custom content, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
