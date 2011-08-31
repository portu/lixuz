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

package LIXUZ::HelperModules::TemplateRenderer::Resolver::Articles;
use Moose;
with 'LIXUZ::Role::TemplateRenderer::Resolver';

use LIXUZ::HelperModules::Live::Comments qw(comment_handler comment_prepare);
use LIXUZ::HelperModules::Live::Articles qw(get_live_articles_from);
use LIXUZ::HelperModules::Calendar qw(datetime_from_SQL_to_unix);
use LIXUZ::HelperModules::Cache qw(get_ckey);
use HTML::Entities qw(decode_entities);
use Carp;
use constant { true => 1, false => 0 };

sub get
{
    my($self,$type,$params) = @_;

    # TODO: Replace with given/when when we've migrated to 5.10
    if($type eq 'list')
    {
        return $self->get_list($params);
    }
    elsif($type eq 'get')
    {
        return $self->get_article($params);
    }

    die('Unknown data request: '.$type);
}

sub get_list
{
    my($self,$searchContent) = @_;

    my $isFrontPage = false;
    my $artid;

    my $return = {};

    my $saveAs = $searchContent->{as};
    if(not $saveAs)
    {
        $self->log('Resolver Article list: No as= parameter for data, ignoring request. Template might crash.');
        return;
    }

    my $obj;
    my $limit = $searchContent->{limit} ? $searchContent->{limit} : 10;
    if ($self->renderer->has_var($saveAs))
    {
        $obj = $self->renderer->get_var($saveAs);
    }
    elsif($self->renderer->has_statevar('raw_'.$saveAs))
    {
        $obj = $self->renderer->get_statevar('raw_'.$saveAs);
        $return->{$saveAs} = $obj;
    }
    else
    {
        if ($searchContent->{catid})
        {
            my $catid = $searchContent->{catid};
            my $cat;
            if ($catid eq 'url' || $catid eq 'arturl')
            {
                if ($self->renderer->has_statevar('primaryArticle'))
                {
                    $cat = $self->renderer->get_statevar('primaryArticle')->category($self->c);
                    $artid = $self->renderer->get_statevar('primaryArticle')->article_id;
                }
                elsif($self->renderer->has_statevar('category'))
                {
                    $cat = $self->renderer->get_statevar('category');
                }
                elsif($self->renderer->get_statevar('categoryFront') && defined $searchContent->{root_catid})
                {
                    $cat = $self->c->model('LIXUZDB::LzCategory')->find({ category_id => $searchContent->{root_catid} });
                    $self->renderer->set_statevar('category',$cat);
                }
                else
                {
                    if ($searchContent->{soft})
                    {
                        return;
                    }
                    else
                    {
                        $self->renderer->error(404,undef,'No category/article/categoryFront statevar');
                    }
                }
            }
            else
            {
                $cat = $self->c->model('LIXUZDB::LzCategory')->find({category_id => $catid},{prefetch => 'children', columns => [ 'category_id','parent','root_parent' ]});
            }
            if ($cat)
            {
                $obj = $cat->get_live_articles($self->c,{ limit => $limit, extraLiveStatus => $searchContent->{extraLiveStatus}, overrideLiveStatus => $searchContent->{overrideLiveStatus}});
                $return->{$saveAs.'_category'} = $cat;
            }
        }
        else
        {
            $obj = get_live_articles_from($self->c->model('LIXUZDB::LzArticle'), { rows => $limit, order_by => 'publish_time DESC', extraLiveStatus => $searchContent->{extraLiveStatus}, overrideLiveStatus => $searchContent->{overrideLiveStatus} });
        }

        # FIXME: This might not always be an actual 404. It might be an empty category.
        if(not $obj)
        {
            if ($searchContent->{soft})
            {
                return;
            }
            if (not $searchContent->{catid} eq 'url' and not $searchContent->{catid} eq 'arturl')
            {
                $self->c->log->warn('Resolvers: Article->list: Requested unknown or empty category in template: '.$searchContent->{catid});
            }
            elsif($isFrontPage)
            {
                $self->c->log->warn('Resolvers: Article->list: Requested unknown or empty category as the root category: '.$searchContent->{root_catid});
            }
            $self->renderer->error(404,undef,'No object found in get_list() for '.$searchContent->{as});
        }

        if ($searchContent->{ignoreDupes} && $artid)
        {
            $obj = $obj->search({ 'me.article_id' => \"!= $artid" });
        }
        $return->{$saveAs} = $obj;
    }
    if ($searchContent->{includePager})
    {
        my $page = 1;
        if ($searchContent->{allowPaging})
        {
            $page = $self->c->req->param('page');
            if(not defined $page or not $page =~ /^\d+$/)
            {
                $page = 1;
            }
        }
        $obj = $obj->page($page);
        $return->{$saveAs.'_pager'} = $obj->pager;
        if ($return->{$saveAs})
        {
            $return->{$saveAs} = $obj;
        }
    }
    return $return;
}

sub get_article
{
    my($self, $searchContent) = @_;

    my $return = {};

    my $saveAs = $searchContent->{as};
    if(not $saveAs)
    {
        $self->log('Resolver Article get: No as= parameter for data, ignoring request. Template might crash.');
        return;
    }

    my $obj;

    if ($self->renderer->has_var($saveAs))
    {
        $obj = $self->renderer->get_var($saveAs);
    }
    else
    {
        if ($searchContent->{artid})
        {
            my $artid = $searchContent->{artid};
            if ($artid eq 'url')
            {
                if ($self->renderer->has_statevar('primaryArticle'))
                {
                    $obj = $self->renderer->get_statevar('primaryArticle');
                }
                else
                {
                    $artid = $self->_getArticleFromURL($self->c);
                }
            }
            if(not defined $obj and defined $artid)
            {
                $obj = get_live_articles_from($self->c->model('LIXUZDB::LzArticle'), { extraLiveStatus => $searchContent->{extraLiveStatus}, overrideLiveStatus => $searchContent->{overrideLiveStatus} });
                $obj = $obj->search({ article_id => $artid });
                if ($obj)
                {
                    $obj = $obj->next;
                }
            }
            elsif(defined $obj and not $self->renderer->get_statevar('primaryArticleIsValid'))
            {
                if(not $obj->is_live($self->c, $searchContent->{extraLiveStatus}, $searchContent->{overrideLiveStatus}))
                {
                    $self->renderer->error(404,undef,'Provided primaryArticle is not valid');
                }
            }
        }

        if(not $obj)
        {
            $self->renderer->error(404,undef,'Failed to locate any matching article');
        }

        $return->{$saveAs} = $obj;
    }

    if ($obj->live_comments && $searchContent->{handleComments})
    {
        comment_handler($self->c,$obj->article_id);
    }

    if ($searchContent->{includeRelations})
    {
        my $chronology = $obj->relationships->find({ relation_type => 'previous'});
        if ($chronology and my $previous = $chronology->get_chronology($self->c))
        {
            $return->{$saveAs.'_prevArt'} = $previous;
        }
        if ($chronology and my $next = $chronology->get_reverse_chronology($self->c))
        {
            $return->{$saveAs.'_nextArt'} = $next;
        }
        my $relart = $obj->relationships->search({ relation_type => 'related' });
        if ($relart)
        {
            $return->{$saveAs.'_relArt'} = $relart;
        }
    }
    if ($obj->live_comments && $searchContent->{includeComments})
    {
        comment_prepare($self->c,$obj->article_id);
    }
    return $return;
}

sub _getArticleFromURL
{
    my($self) = @_;
    my @paths = split(m#/+#,$self->c->req->path);
    my $artid = $paths[-1];
    $artid =~ s/^.*-//g;
    if (not $artid =~ /^\d+$/)
    {
        # FIXME: Error handling
        return;
    }

    return $artid;
}

sub _getCategoryObjectFromURL
{
    my($self,$settings,$style) = @_;

    # FIXME: Error handling, error handling and error handling
    my @paths = split(m#/+#,$self->c->req->path);
    my $catname;
    if ($style eq 'arturl')
    {
        $catname = $paths[-2];
    }
    else
    {
        $catname = $paths[-1];
    }

    my $cat;
    my $isFrontPage = 0;
    if (not defined $catname or not length $catname)
    {   
        $isFrontPage = 1;
        $cat = $self->c->model('LIXUZDB::LzCategory')->find({category_id => $settings->{root_catid}}, {columns => [ 'category_id','parent','root_parent']});
    }
    else
    {   
        my $origCat = $catname;
        $catname =~ s/-/ /g;
        $cat = $self->c->model('LIXUZDB::LzCategory')->find({category_name => $catname},{prefetch => 'children',columns => [ 'category_id','parent','root_parent']});
        # FIXME
        $self->c->stash->{rssCategory} = $origCat;
        if (not $cat)
        {   
            $cat = $self->c->model('LIXUZDB::LzCategory')->find({category_name => $origCat},{prefetch => 'children',columns => [ 'category_id','parent','root_parent']});
        }
    }
    if(wantarray())
    {
        return($cat,$isFrontPage)
    }
    else
    {
        return($cat);
    }
}

__PACKAGE__->meta->make_immutable;
1;
