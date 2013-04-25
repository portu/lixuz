package LIXUZ::Schema::LzCategory;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';


=head1 NAME

LIXUZ::Schema::LzCategory

=cut

__PACKAGE__->table("lz_category");

=head1 ACCESSORS

=head2 category_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 category_name

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 parent

  data_type: 'integer'
  is_nullable: 1

=head2 root_parent

  data_type: 'integer'
  is_nullable: 1

=head2 category_order

  data_type: 'integer'
  is_nullable: 1

=head2 template_id

  data_type: 'integer'
  is_nullable: 1

=head2 display_type_id

  data_type: 'integer'
  is_nullable: 1

=head2 folder_id

  data_type: 'integer'
  is_nullable: 1

=head2 external_link

  data_type: 'text'
  is_nullable: 1

=head2 category_status

  data_type: 'enum'
  default_value: 'Active'
  extra: {list => ["Active","Inactive"]}
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "category_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "category_name",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "parent",
  { data_type => "integer", is_nullable => 1 },
  "root_parent",
  { data_type => "integer", is_nullable => 1 },
  "category_order",
  { data_type => "integer", is_nullable => 1 },
  "template_id",
  { data_type => "integer", is_nullable => 1 },
  "display_type_id",
  { data_type => "integer", is_nullable => 1 },
  "folder_id",
  { data_type => "integer", is_nullable => 1 },
  "external_link",
  { data_type => "text", is_nullable => 1 },
  "category_status",
  {
    data_type => "enum",
    default_value => "Active",
    extra => { list => ["Active", "Inactive"] },
    is_nullable => 1,
  },
);
__PACKAGE__->set_primary_key("category_id");


# Created by DBIx::Class::Schema::Loader v0.07002 @ 2011-01-17 10:17:20
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:rfd+AtLAMcMWd75LGlP7tw

__PACKAGE__->has_many(children => 'LIXUZ::Schema::LzCategory', {
    'foreign.parent' => 'self.category_id',
    });

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

use LIXUZ::HelperModules::Cache qw(get_ckey CT_1H);
use LIXUZ::HelperModules::Live::Articles qw(get_live_articles_from);
use Moose;
with 'LIXUZ::Role::URLGenerator';
# Objects from orderedRS gets reblessed as ProxiedResultSets
use LIXUZ::HelperModules::ProxiedResultSet;

# Summary: Get all fields from this user in a hash
# Usage: object->get_everything();
# Returns: Hash with field => value pairs.
sub get_everything
{
    my $self = shift;
    my %Return;
    foreach my $col( qw(category_id category_name parent root_parent category_order template_id display_type_id folder_id external_link category_status) )
    {
        $Return{$col} = $self->get_column($col);
    }
    return(\%Return);
}

# Summary: Get all articles in this category, or subcategories
# Usage: $resultSet = $category->get_articles($c,\%options?);
# Options can be undef, or a hashref with zero or more of the following
#   parameters:
# rows => int, max number of elements returned in resultset
sub get_articles
{
    my($self,$c,$info) = @_;
    $info = $info ? $info : { };
    $info->{live} = defined $info->{live} ? $info->{live} : 0;
    # We allow both limit and rows
    my $limit = defined $info->{limit} ? $info->{limit} : $info->{rows};
    my $articles = $self->_fetchCategoryChildren($c,$limit,$info->{live});
    return $articles;
}

# Summary: The same as get_articles, but only fetches live articles.
# Usage: Same as get_articles, with the following additions to the options hash:
#   overrideLiveStatus => a status_id to use in place of the core live status_id,
#   extraLiveStatus => a space-separated list of status_id's that will count as
#       live in ADDITION to the core one
sub get_live_articles
{
    my($self,$c,$info) = @_;
    $info = $info ? $info : { };
    my $live = {
        overrideLiveStatus => $info->{overrideLiveStatus},
        extraLiveStatus => $info->{extraLiveStatus}
    };
    $info->{live} = $live;
    my $arts = $self->get_articles($c,$info);
    return $arts;
}

sub getCategorySearchSQL
{
    my $self = shift;
    return $self->_getCategorySearchSQL(@_);
}

sub fetchCategoryChildren_preSQL
{
    my $self = shift;
    return $self->_getCategorySearchSQL(@_);
}

# Summary: Retrieve category names in an array, highest level first. 
# Primarily used by the URLGenerator role.
sub get_category_tree
{
    my $self = shift;
    my $c    = shift;
    my $cat  = $self;
    my @tree;

    push(@tree,$cat->category_name);
    while($cat = $cat->parent)
    {
        push(@tree,$cat->category_name);
    }
    return @tree;
}

# Summary: Retrieve the ordered front-page RS.
# Usage: Same as get_live_articles, with the following additions to the options hash:
#   template => the template *object* corresponding to the template in use.
#   Required.
sub orderedRS
{
    my($self,$c,$info) = @_;
    my $template = $info->{template};
    if (!defined $template)
    {
        $template = $c->model('LIXUZDB::LzTemplate')->find({
                type => 'list',
                is_default => 1,
            });
    }
    my $templateMeta = $template->get_info($c);

    if (! $templateMeta->{layout})
    {
        return $self->get_live_articles($c,$info);
    }

    return LIXUZ::HelperModules::ProxiedResultSet->new(
            normalBuilder => sub
            {
                my $proxy = shift;
                my $total = $templateMeta->{layout_spots};
                # If the number of ordered articles are below the number of requested articles
                # then we assume that there aren't enough articles to go around, and thus we
                # don't bother constructing a live list on the assumption that there won't
                # be enough anyway.
                if (defined $proxy->ordered && $proxy->ordered->count < $total)
                {
                    return undef;
                }
                # This returns all articles that are not already present in the
                # ordered resultset
                return $self->get_live_articles($c,$info)->search(
                    {
                        'me.article_id' => {
                            -not_in => [ $proxy->getOrderedArticleIDs ]
                        }
                    });
            },
            orderedBuilder => sub
            {
                my $total = $templateMeta->{layout_spots};

                my $ordered;
                my $newer;
                my $older;

                # Retrieve a list of all articles present in spots
                my $layout = $c->model('LIXUZDB::LzCategoryLayout')->search({ 'category_id' => $self->category_id }, { order_by => 'spot' });
                if (!$layout->count)
                {
                    return;
                }

                # Retrieve a list of all of the live articles in $layout
                $ordered = get_live_articles_from($layout->search_related('article'), $info);
                if (!$ordered)
                {
                    return;
                }

                # Build a list of the articles in the layout
                my @present;
                my $newerThan;
                while(my $entry = $layout->next)
                {
                    $newerThan //= $entry->ordered_at;
                    push(@present,$entry->article_id);
                }

                # Retrieve articles that have been published *after* the last ordering of
                # the RS
                my $newerSearch = {
                    'me.article_id' => { -not_in => \@present },
                };
                if(defined $newerThan)
                {
                    $newerSearch->{publish_time} = { '>' => $newerThan };
                }
                $newer = $self->get_live_articles($c,$info)->search($newerSearch,
                    {
                        limit => $total,
                        order_by => 'publish_time DESC'
                    });

                # The array that will be used as the basis for the final result set
                my @entries;

                # Push all newer articles
                while(my $new = $newer->next)
                {
                    # Limit the number of entries
                    if(scalar(@entries) > $total)
                    {
                        last;
                    }

                    push(@entries,$new);
                    push(@present,$new->article_id);
                }

                # Push the ordered articles
                while(my $current = $ordered->next)
                {
                    # Limit the number of entries
                    if(scalar(@entries) > $total)
                    {
                        last;
                    }

                    push(@entries,$current);
                }

                if( (my $remaining = ($total - scalar(@entries) )) > 0)
                {
                    # Retrieve the older articles
                    $older = $self->get_live_articles($c,$info)->search({
                                'me.article_id' => { -not_in => \@present }
                            },
                            {
                                order_by => 'publish_time DESC',
                                limit => $remaining,
                            });

                    # Finally, push the older articles if needed
                    while(my $old = $older->next)
                    {
                        # Limit the number of entries
                        if(scalar(@entries) > $total)
                        {
                            last;
                        }

                        push(@entries,$old);
                        push(@present,$old->article_id);
                    }
                }

                my $result = $c->model('LIXUZDB::LzArticle');
                $result->set_cache(\@entries);

                return $result;
            },
        );
}

# ======================
# PRIVATE
# ======================

sub _orderedCkey
{
    my($self,$extraLive,$overrideLive) = @_;
    $extraLive    //= [];
    $overrideLive //= '';
    return 'catOrdered_'.$self->category_id.'|'.join('-',@{$extraLive}).'|'.$overrideLive;
}

# Summary: This is used to locate all children of a category, so that all articles in the
#   category and sub-categories are found
# Usage: self->fetchCategoryChildren($c, limit?,$onlyLiveInfo?);
# limit is optional, the number of results to return
sub _fetchCategoryChildren
{
    my($self,$c,$limit,$onlyLive) = @_;
    $limit = $limit ? $limit : 30;

    my($orSearch,$found) =  $self->_getCategorySearchSQL($c);
    if(not $found)
    {
        return undef;
    }
    return $self->_fetchCategoryChildren_preSQL($c,$orSearch,$limit,$onlyLive);
}

sub _getCategorySearchSQL
{
    my($self,$c) = @_;
    my $folders;
    my $ckey = get_ckey('category','children',$self->category_id);
    if (not $folders = $c->cache->get($ckey))
    {
        if(not defined $self->root_parent)
        {
            $folders = $self->_toplevelChildrenFetcher($c);
        }
        else
        {
            $folders = $self->_recursiveChildrenFetcher($c);
        }
        $c->cache->set($ckey,$folders,CT_1H);
    }
    my $orSearch = [];
    my $found;
    foreach my $folder (sort @{$folders})
    {
        push(@{$orSearch},{ 'folders.'.folder_id => $folder});
        $found = 1;
    }
    if(wantarray())
    {
        return($orSearch,$found);
    }
    else
    {
        return($orSearch);
    }
}

sub _fetchCategoryChildren_preSQL
{
    my($self,$c,$orSearch,$limit,$onlyLive) = @_;
    my $options = { order_by => 'publish_time DESC', join => [qw(folders revisionMeta)], prefetch => 'folders' };
    if(ref($limit))
    {
        $options->{rows} = $limit->{rows};
    }
    else
    {
        $options->{rows} = $limit;
    }
    if (! ref($orSearch) || !(scalar(@{$orSearch}) > 0))
    {
        $c->log->error('fetchCategoryChildren_preSQL: orSearch is empty! About to fail spectaculary');
    }
    my $articles = $c->model('LIXUZDB::LzArticle')->search({ '-or' => $orSearch, 'revisionMeta.is_latest_in_status' => 1, },$options);
    if ($onlyLive)
    {
        $articles = get_live_articles_from($articles,$onlyLive);
    }
    if (ref($limit))
    {
        $articles = $articles->page($limit->{page});
    }
    return $articles;
}

sub _toplevelChildrenFetcher
{
    my($self,$c) = @_;
    my $children = $c->model('LIXUZDB::LzCategory')->search({ '-or' => [ {root_parent => $self->category_id}, {parent => $self->category_id}]}, { columns => [ 'category_id']});
    my @categories = $self->category_id;
    while(my $child = $children->next)
    {
        push(@categories,$child->category_id);
    }
    return $self->_getFoldersFromCategories($c,@categories);
}

sub _getFoldersFromCategories
{
    my $self = shift;
    my $c = shift;
    my @folderList;
    my @folderSearch;
    while(my $category = shift(@_))
    {
        push(@folderSearch,{ category_id => $category});
    }
    my $search = $c->model('LIXUZDB::LzCategoryFolder')->search({'-or' => \@folderSearch},{ columns => ['folder_id']});
    while(my $f = $search->next)
    {
        push(@folderList,$f->folder_id);
    }
    return \@folderList;
}

sub _recursiveChildrenFetcher
{
    my($self,$c) = @_;
    my $loopL = 0;
    my @categoryList;
    my @childrenLists;
    push(@categoryList,$self->category_id);
    push(@childrenLists,scalar $self->children->search(undef,{prefetch => 'children',columns => ['category_id']}));
    while((my $children = shift(@childrenLists)) && ($loopL++ < 1000))
    {
        while(my $child = $children->next)
        {
            if ($child->children)
            {
                push(@childrenLists, scalar $child->children->search(undef,{prefetch => 'children',columns => ['category_id']}));
            }
            push(@categoryList,$child->category_id);
        }
    }
    return $self->_getFoldersFromCategories($c,@categoryList);
}

__PACKAGE__->has_many(children => 'LIXUZ::Schema::LzCategory', { 'foreign.parent' => 'self.category_id' });
__PACKAGE__->has_many(folders => 'LIXUZ::Schema::LzCategoryFolder', 'category_id');
__PACKAGE__->belongs_to(parent => 'LIXUZ::Schema::LzCategory');

__PACKAGE__->has_many(layouts => 'LIXUZ::Schema::LzCategoryLayout', 'category_id');
1;


# You can replace this text with custom content, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
