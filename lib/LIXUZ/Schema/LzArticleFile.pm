package LIXUZ::Schema::LzArticleFile;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';


=head1 NAME

LIXUZ::Schema::LzArticleFile

=cut

__PACKAGE__->table("lz_article_file");

=head1 ACCESSORS

=head2 article_id

  data_type: 'integer'
  is_nullable: 0

=head2 file_id

  data_type: 'integer'
  is_nullable: 0

=head2 spot_no

  data_type: 'integer'
  is_nullable: 1

=head2 caption

  data_type: 'text'
  is_nullable: 1

=head2 revision

  data_type: 'integer'
  default_value: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "article_id",
  { data_type => "integer", is_nullable => 0 },
  "file_id",
  { data_type => "integer", is_nullable => 0 },
  "spot_no",
  { data_type => "integer", is_nullable => 1 },
  "caption",
  { data_type => "text", is_nullable => 1 },
  "revision",
  { data_type => "integer", default_value => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("article_id", "file_id", "revision");


# Created by DBIx::Class::Schema::Loader v0.07002 @ 2011-01-17 10:17:20
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ntHxei2YDjs4eD/gpyTEhg

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

__PACKAGE__->belongs_to('file' => 'LIXUZ::Schema::LzFile', 'file_id');
__PACKAGE__->belongs_to('article' => 'LIXUZ::Schema::LzArticle', { 'foreign.article_id' => 'self.article_id', 'foreign.revision' => 'self.revision' });

use Moose;
with 'LIXUZ::Role::Serializable';

sub _serializeExtra
{
    return [ 'file' ];
}
sub autoAssignToSpot
{
    my ($self,$c) = @_;
    my $art = $self->article;
    my $template;
    if (not $template = $art->template)
    {
        $template = $c->model('LIXUZDB::LzTemplate')->find({ type => 'article', is_default => 1});
    }
    if(not $template)
    {
        $c->log->error('LzArticleFile: autoAssignToSpot(): Failed to locate a template.');
        return;
    }
    my $info = $template->get_info($c);
    if(not defined $info->{spots_parsed})
    {
        return;
    }
    my @spots;
    foreach my $spot (@{$info->{spots_parsed}})
    {
        if (defined $spot->{default} and length $spot->{default})
        {
            $spots[$spot->{default}] = $spot;
        }
    }
    if(not @spots)
    {
        return;
    }
    
    foreach my $spot (@spots)
    {
        my $existing = $c->model('LIXUZDB::LzArticleFile')->search({
                article_id => $self->article_id,
                spot_no => $spot->{id},
            });
        if ($existing->count > 0)
        {
            next;
        }
        $self->set_column('spot_no',$spot->{id});
        $self->update();
        return;
    }
}

# This retrieves the caption. Either from this object, or if we don't have one,
# from the parent LzFile object
sub get_caption
{
    my $self = shift;
    if (defined $self->caption)
    {
        return $self->caption;
    }
    return $self->file->caption;
}

# These are proxies for methods on LzFile
sub height
{
    my $self = shift;
    return $self->file->height(@_);
}

sub width
{
    my $self = shift;
    return $self->file->width(@_);
}

sub get_url_aspect
{
    my $self = shift;
    return $self->file->get_url_aspect(@_);
}

sub get_url
{
    my $self = shift;
    return $self->file->get_url(@_);
}

sub getFieldContents
{
    my $self = shift;
    return $self->file->getFieldContents(@_);
}

sub is_image
{
    my $self = shift;
    return $self->file->is_image(@_);
}

sub is_flash
{
    my $self = shift;
    return $self->file->is_flash(@_);
}

sub is_video
{
    my $self = shift;
    return $self->file->is_video(@_);
}

sub is_audio
{
    my $self = shift;
    return $self->file->is_audio(@_);
}

1;


# You can replace this text with custom content, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
