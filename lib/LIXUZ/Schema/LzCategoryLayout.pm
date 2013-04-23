package LIXUZ::Schema::LzCategoryLayout;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';


=head1 NAME

LIXUZ::Schema::LzCategoryLayout

=cut

__PACKAGE__->table("lz_category_layout");

=head1 ACCESSORS

=head2 category_id

  data_type: 'integer'
  is_nullable: 0

=head2 article_id

  data_type: 'integer'
  is_nullable: 0

=head2 template_id

  data_type: 'integer'
  is_nullable: 0

=head2 spot

  data_type: 'smallint'
  is_nullable: 0

=head2 ordered_at

  data_type: 'timestamp'
  default_value: current_timestamp
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "category_id",
  { data_type => "integer", is_nullable => 0 },
  "article_id",
  { data_type => "integer", is_nullable => 0 },
  "template_id",
  { data_type => "integer", is_nullable => 0 },
  "spot",
  { data_type => "smallint", is_nullable => 0 },
  "ordered_at",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 0,
  },
);
__PACKAGE__->set_primary_key("category_id", "article_id", "template_id");


# Created by DBIx::Class::Schema::Loader v0.07002 @ 2013-04-23 14:11:54
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:uu0Y4c9s81/jStuujM2UXQ

__PACKAGE__->belongs_to('article' => 'LIXUZ::Schema::LzArticle',{article_id=>'article_id'});
__PACKAGE__->belongs_to('template','LIXUZ::Schema::LzTemplate', 'template_id');
__PACKAGE__->belongs_to('category' => 'LIXUZ::Schema::LzCategory', 'category_id');

# You can replace this text with custom content, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
