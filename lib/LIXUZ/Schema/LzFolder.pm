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

package LIXUZ::Schema::LzFolder;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';


=head1 NAME

LIXUZ::Schema::LzFolder

=cut

__PACKAGE__->table("lz_folder");

=head1 ACCESSORS

=head2 folder_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 folder_name

  data_type: 'varchar'
  is_nullable: 1
  size: 100

=head2 parent

  data_type: 'integer'
  is_nullable: 1

=head2 folder_order

  data_type: 'integer'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "folder_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "folder_name",
  { data_type => "varchar", is_nullable => 1, size => 100 },
  "parent",
  { data_type => "integer", is_nullable => 1 },
  "folder_order",
  { data_type => "integer", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("folder_id");


# Created by DBIx::Class::Schema::Loader v0.07002 @ 2011-01-17 10:17:20
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:dbaG5TkTtL1Q7xWIvg4iuw

__PACKAGE__->has_many(categoryfolders => 'LIXUZ::Schema::LzCategoryFolder', 'folder_id');
__PACKAGE__->has_many(children => 'LIXUZ::Schema::LzFolder', { 'foreign.parent' => 'self.folder_id' });
__PACKAGE__->belongs_to(parent => 'LIXUZ::Schema::LzFolder');

use Moose;
with 'LIXUZ::Role::AccessControl::Model';

# Purpose: Get all children of this folder, no matter where they live in the folder tree
# Usage: my $children = $folder->children_recursive();
# Returns an arrayref of folder_ids
sub children_recursive
{
    my $self = shift;
    my $arrayRef = shift;

    my @children;

    my $children = $self->children;
    while((defined $children) && (my $child = $children->next))
    {
        push(@children,$child->folder_id);
        push(@children, @{$child->children_recursive(1)});
    }
    return \@children;
}

# Purpose: Get the full (filesystem-like) path to the folder, with all its parents
sub get_path
{
    my ($self) = @_;

    my @path;
    push(@path,$self->folder_name);

    my $pathPart = $self;
    while($pathPart = $pathPart->parent)
    {
        push(@path,$pathPart->folder_name);
    }
    return '/'.join('/',reverse(@path));
}

sub recursive_delete
{
    my $self = shift;
    my $c = shift or die('Missing $c');
    my $newParent;

    if(not defined $newParent)
    {
        if ($self->parent)
        {
            $newParent = $self->parent->folder_id;
        }
        else
        {
            my $folders = $c->model('LIXUZDB::LzFolder')->search({
                    parent => \'IS NULL',
                });
            while(my $f = $folders->next)
            {
                if ($f->folder_id == $self->folder_id)
                {
                    next;
                }
                $newParent = $f->folder_id;
                last;
            }
        }
    }

    my $children = $self->children;
    while(my $child = $children->next)
    {
        $child->recursive_delete($c,$newParent);
    }

    $self->categoryfolders->delete();
    my $articles = $c->model('LIXUZDB::LzArticleFolder')->search({
            primary_folder => 1,
            folder_id => $self->folder_id
        });
    while(my $art = $articles->next)
    {
        if(not defined $newParent)
        {
            $art->delete();
        }
        else
        {
            $art->set_column('folder_id',$newParent);
            $art->update();
        }
    }
    my $files = $c->model('LIXUZDB::LzFile')->search({
            folder_id => $self->folder_id
        });
    while(my $file = $files->next)
    {
        $file->set_column('folder_id',$newParent);
        $file->update();
    }
    $c->model('LIXUZDB::LzFieldModule')->search({
            folder_id => $self->folder_id
        })->delete();

    $self->delete();

    return 1;
}

1;


# You can replace this text with custom content, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
