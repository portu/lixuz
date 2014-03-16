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

package LIXUZ::Controller::Admin::Categories::Layout;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
BEGIN { extends 'Catalyst::Controller::FormBuilder' };
with 'LIXUZ::Role::List::Database';

use LIXUZ::HelperModules::Search qw(cross);
use LIXUZ::HelperModules::Forms qw(finalize_form);
use LIXUZ::HelperModules::Includes qw(add_jsIncl add_cssIncl add_globalJSVar add_jsOnLoad);
use LIXUZ::HelperModules::DragDrop;

sub messageToList
{
    my ($self, $c, $message) = @_;
    if (defined $c->stash->{displaySite} && $c->stash->{displaySite} == 0)
    {
        $c->stash->{content} = $message;
        $c->stash->{template} = 'adm/core/dummy.html';
    }
    else
    {
        $c->flash->{ListMessage} = $message;
        if(not $message)
        {
            $c->log->warn('No valid message supplied to messageToList in Layout.pm');
        }
        $c->response->redirect('/admin/categories');
        $c->detach();
    }
}   

sub edit : Local Args
{
    my ( $self, $c, $cat_id ) = @_;
    my $i18n = $c->stash->{i18n};

    if (not defined $cat_id or $cat_id =~ /\D/)
    {   
        return $self->messageToList($c,$i18n->get_advanced('Error: Invalid ID supplied'));
    }
    else
    {
        my $category = $c->model('LIXUZDB::LzCategory')->find({category_id => $cat_id});
        if(not $category)
        {
            return $self->messageToList($c,$i18n->get_advanced('Error: Failed to locate a category with the id %(CATEGORY_ID).', { CATEGORY_ID => $cat_id }));
        }
        else
        {
            my @catarray               = $category->get_category_tree($c);
            my $catname                = '/'.join('/',reverse(@catarray));

            my $template               = $category->template;

            my $layoutMeta             = $template->get_layout_meta($c);

            $c->stash->{category_id}   = $cat_id;
            $c->stash->{templateObj}   = $template;
            $c->stash->{category_name} = $catname;
            $c->stash->{pageTitle}     = $i18n->get('Category layout');
            $c->stash->{articles}      = $category->orderedRS($c,$layoutMeta->{listmeta});

            my $dnd = LIXUZ::HelperModules::DragDrop->new($c,'LIXUZDB::LzFolder','/admin/articles/folderAjax/',
                {
                    name => 'folder_name',
                    uid => 'folder_id',
                },
                {
                    immutable => 1, # FIXME: Drop
                    onclick => 'categoryLayout.updateArtList',
                },
            );
            if ($c->req->param('folder') && $c->req->param('folder') !~ /\D/)
            {
                $dnd->set_flags({ hilightUIDs => { $c->req->param('folder') => 1 }});
            }
            else
            {
                $dnd->set_flags({ hilightUIDs => { 'root' => 1 }});
            }
            $c->stash->{dragdrop} = $dnd->get_html();
            add_jsIncl($c,$dnd->get_jsfiles());
            add_jsIncl($c,'utils.js','layout.js');
            add_cssIncl($c,$dnd->get_cssfiles());

            $c->stash->{template} = 'adm/categories/layout/edit.html';

        }
    }

}

sub renderCatArticleList : Local Args Form('/core/search')
{
    my ($self, $c, $cat_id) = @_;
    my $category;
    my $articles;
    my $i18n = $c->stash->{i18n};
    $c->stash->{displaySite} = 0;

    if (not defined $cat_id or $cat_id =~ /\D/)
    {
        return $self->messageToList($c,$i18n->get_advanced('Error: Invalid ID supplied'));
    }
    $category = $c->model('LIXUZDB::LzCategory')->find({category_id => $cat_id});
    if (not $category)
    {
        return $self->messageToList($c,$i18n->get_advanced('Error: Failed to locate a category with the id %(CATEGORY_ID).', { CATEGORY_ID => $cat_id }));
    }
    if (defined (my $folder = $c->req->param('folder')))
    {
        if ($folder =~ /\D/ && $folder ne 'root')
        {
            return $self->messageToList($c,$i18n->get_advanced('Error: Invalid folder-ID supplied'));
        }
        elsif ($folder ne 'root')
        {
             my $folder_cat = $c->model('LIXUZDB::LzCategoryFolder')->find({category_id => $cat_id, folder_id => $folder});
             if (not $folder_cat)
             {
                 return $self->messageToList($c,$i18n->get_advanced('This folder is not associated with the category'));
             }
        }
    }
    $articles = $category->get_live_articles($c);
    if (!defined $articles)
    {
        die('Ended up without any articles RS');
    }
    $c->req->params->{orderby} = 'modified_time';
    $c->req->params->{ordertype} = 'DESC';
    $c->req->params->{status_id} = 2;
    my $query = $c->req->param('query');
    my $forceSearch = ( defined($query) && length($query) ) ? 1 : 0;
    my $result = $c->forward(qw( LIXUZ::Controller::Admin::Articles retrieveArticles ),[
            $c->model('LIXUZDB::LzArticle'),
            $query,
            $self->formbuilder,
            0,
            $forceSearch
        ]);
    $c->stash->{artlist} = $result;
    $c->stash->{template} = 'adm/categories/layout/list.html';
}

sub save : Local
{
    my ( $self, $c ) = @_;
    my $i18n = $c->stash->{i18n};
    my $category_id = $c->req->param('category_id');
    my $template_id = $c->req->param('template_id');
    my $template = $c->model('LIXUZDB::LzTemplate')->find({ template_id => $template_id });
    if (not defined $category_id or $category_id =~ /\D/)
    {
        $self->messageToList($c, $i18n->get('Invalid category id.') );
    }
    elsif (not defined $template_id or $template_id =~ /\D/ or !$template)
    {
        $self->messageToList($c, $i18n->get('Invalid template id.') );
    }
    elsif(!defined $template->get_info($c)->{layout})
    {
        $self->messageToList($c, $i18n->get('Template has no spots, unable to save layout') );
    }
    else
    {
        my $previousOrdering = $c->model('LIXUZDB::LzCategoryLayout')->search({ category_id => $category_id });
        $previousOrdering->delete;
        
        my $category = $c->model('LIXUZDB::LzCategory')->find({ category_id => $category_id });

        my @article_order = $c->req->param('spot_article');

        my $layoutMeta = $template->get_layout_meta($c);
        my $totalSpots = $layoutMeta->{layout_spots};

        my @articles;
        for(my $spot = 0; $spot <= $totalSpots; $spot++)
        {
            my $content = $c->req->param('spot_article_'.$spot);
            if ( defined $content && $content =~ /^\d+$/)
            {
                push(@articles,$content);
            }
        }

        my $otherArticles = $category->get_live_articles($c, { 
                overrideLiveStatus => $layoutMeta->{overrideLiveStatus},
                extraLiveStatus => $layoutMeta->{extraLiveStatus},
            });
        $otherArticles = $otherArticles->search({ 'me.article_id' => { -not_in => \@articles } });

        my %seen;
        for(my $spot = 0; $spot <= $totalSpots; $spot++)
        {
            my $artid = $c->req->param('spot_article_'.$spot);
            if (! defined $artid || $artid =~ /\D/)
            {
                my $next = $otherArticles->next;
                if (defined $next && $next =~ /^\d+$/)
                {
                    $artid = $next;
                }
                else
                {
                    next;
                }
            }
            while ($seen{$artid})
            {
                $c->log->warn('WARNING: Duplicates in layout definition. Replacing duplicate of '.$artid);
                my $next = $otherArticles->next;
                if ($next)
                {
                    $artid = $next;
                }
                else
                {
                    $artid = undef;
                }
            }
            if (! defined $artid || !length($artid) || $artid !~ /^\d+$/)
            {
                next;
            }
            $seen{$artid} = 1;
            my $insert_order_obj = $c->model('LIXUZDB::LzCategoryLayout')->create({
                    category_id => $category_id,
                    article_id => $artid,
                    template_id => $template_id,
                    spot => $spot,
                });

            $insert_order_obj->update;
        }
        $self->messageToList($c, $i18n->get('Category layout saved successfully.') );
    }
}
1;
