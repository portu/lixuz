package LIXUZ::Schema::LzComment;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';


=head1 NAME

LIXUZ::Schema::LzComment

=cut

__PACKAGE__->table("lz_comment");

=head1 ACCESSORS

=head2 comment_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 user_id

  data_type: 'integer'
  is_nullable: 0

=head2 object_id

  data_type: 'integer'
  is_nullable: 0

=head2 object_type

  data_type: 'enum'
  extra: {list => ["article","time_entry"]}
  is_nullable: 0

=head2 on_revision

  data_type: 'integer'
  default_value: 1
  is_nullable: 0

=head2 written_time

  data_type: 'datetime'
  is_nullable: 1

=head2 subject

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 body

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "comment_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "user_id",
  { data_type => "integer", is_nullable => 0 },
  "object_id",
  { data_type => "integer", is_nullable => 0 },
  "object_type",
  {
    data_type => "enum",
    extra => { list => ["article", "time_entry"] },
    is_nullable => 0,
  },
  "on_revision",
  { data_type => "integer", default_value => 1, is_nullable => 0 },
  "written_time",
  { data_type => "datetime", is_nullable => 1 },
  "subject",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "body",
  { data_type => "text", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("comment_id");



__PACKAGE__->belongs_to('ttUser' => 'LIXUZ::Schema::LzUser', { 'foreign.user_id' => 'self.user_id' });
__PACKAGE__->belongs_to('article' => 'LIXUZ::Schema::LzArticle', { 'foreign.article_id' => 'self.object_id', 'foreign.revision' => 'self.on_revision' });
__PACKAGE__->belongs_to('author' => 'LIXUZ::Schema::LzUser', 'user_id');

# Created by DBIx::Class::Schema::Loader v0.07002 @ 2012-04-09 11:54:25
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:4QhTOFpt22QppRxe2XlIBw


# You can replace this text with custom content, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
