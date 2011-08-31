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

package LIXUZ::Schema::LzArticleRelations;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';


=head1 NAME

LIXUZ::Schema::LzArticleRelations

=cut

__PACKAGE__->table("lz_article_relations");

=head1 ACCESSORS

=head2 article_id

  data_type: 'integer'
  is_nullable: 0

=head2 related_article_id

  data_type: 'integer'
  is_nullable: 0

=head2 relation_type

  data_type: 'enum'
  extra: {list => ["previous","related"]}
  is_nullable: 0

=head2 created_date

  data_type: 'timestamp'
  default_value: current_timestamp
  is_nullable: 0

=head2 revision

  data_type: 'integer'
  default_value: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "article_id",
  { data_type => "integer", is_nullable => 0 },
  "related_article_id",
  { data_type => "integer", is_nullable => 0 },
  "relation_type",
  {
    data_type => "enum",
    extra => { list => ["previous", "related"] },
    is_nullable => 0,
  },
  "created_date",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 0,
  },
  "revision",
  { data_type => "integer", default_value => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("article_id", "related_article_id", "relation_type", "revision");


# Created by DBIx::Class::Schema::Loader v0.07002 @ 2011-01-17 10:17:20
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:bRakB1bkd0V1aVZLfLrgnw
__PACKAGE__->belongs_to('owner' => 'LIXUZ::Schema::LzArticle', { 'foreign.article_id' => 'self.article_id', 'foreign.revision' => 'self.article_id' });
__PACKAGE__->has_many('related' => 'LIXUZ::Schema::LzArticle', { 'foreign.article_id' => 'self.related_article_id' });

use Carp;
use LIXUZ::HelperModules::Cache qw(get_ckey);
use LIXUZ::HelperModules::Live::Articles qw(get_live_articles_from);
use constant { 
    SELF_REFERENCING => 3,
    RELATIONSHIP_PROCESSED => 1,
    DUPLICATES => 2 
    };
use Moose;
with 'LIXUZ::Role::Serializable';

sub related_live
{
    my ($self) = shift;
    my $related = $self->related;
    my $live;
    if ($related->can('search'))
    {
        $live = get_live_articles_from($related);
        $live = $live->next if $live;
    }
    else
    {
        if ($related->status_id == 2)
        {
            $live = $related;
        }
    }
    return $live;
}

sub get_chronology
{
    my ($self,$c) = @_;
    croak('$c is missing') if not $c;
    return $self->_get_chronology_depth($c,'previous',20,'article_id');
}

sub get_reverse_chronology
{
    my ($self,$c) = @_;
    croak('$c is missing') if not $c;
    my $searcher = $c->model('LIXUZDB::LzArticleRelations')->find({ related_article_id => $self->article_id, relation_type => 'previous'});
    if(not $searcher)
    {
        return undef;
    }
    return $searcher->_get_chronology_depth($c,'previous',20,'related_article_id');
}

sub _get_chronology_depth
{
    my ($self,$c,$type,$depth,$searchColumn) = @_;
    my $m = $c->model('LIXUZDB::LzArticleRelations');
    my $cacheName = get_ckey('article','chronology',$type.'-'.$depth.'-'.$searchColumn.'-'.$self->article_id);
    my $count = 0;
    my %entries;
    my @search;
    my $current = $self;
    my $order;
    if ($searchColumn eq 'article_id')
    {
        $order = 'DESC';
    }
    else
    {
        $order = 'ASC';
    }
    if (my $chron = $c->cache->get($cacheName))
    {
        my $arts = get_live_articles_from($c->model('LIXUZDB::LzArticle'));
        return $arts->search({ -or => $chron },{ order_by => 'publish_time '.$order });
    }
    $c->cache->set(get_ckey('article','lastChronologyKey',$self->article_id),$cacheName,4600);
    for(1..$depth)
    {
        my $id;
        if ($searchColumn eq 'article_id')
        {
            $id = $current->related_article_id;
        }
        else
        {
            $id = $current->article_id;
        }
        if (defined $current->related_article_id and defined $current->article_id and $current->related_article_id == $current->article_id)
        {
            if ((not $entries{$id}) or ($entries{$id} != SELF_REFERENCING))
            {
                $entries{$id} = SELF_REFERENCING;
                $c->log->error('Self-referencing relationship found for (should perhaps be auto-deleted?): '.$current->article_id);
            }
        }
        if ($entries{$id})
        {
            if ($entries{$id} == RELATIONSHIP_PROCESSED)
            {
                $c->log->debug('Attempted to add duplicate (recursive relationships): '.$id);
                $entries{$id} = DUPLICATES;
            }
        }
        else
        {
            $entries{$id} = RELATIONSHIP_PROCESSED;
            push(@search, { article_id => $id});
        }
        $current = $m->find({'relation_type' => $type, $searchColumn => $id});
        if(not $current)
        {
            last;
        }
    }
    undef %entries;
    if(not @search)
    {
        return;
    }
    $c->cache->set($cacheName,\@search, 3600);
    my $arts = get_live_articles_from($c->model('LIXUZDB::LzArticle'));
    return $arts->search({ -or => \@search },{ order_by => 'publish_time '.$order });
}

# You can replace this text with custom content, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
