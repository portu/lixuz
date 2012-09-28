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
use LIXUZ::HelperModules::Templates qw(cached_parse_templatefile);

sub messageToList
{
    my ($self, $c, $message) = @_;
    $c->flash->{ListMessage} = $message;
    if(not $message)
    {
        $c->log->warn('No valid message supplied to messageToList in Layout.pm');
    }
    $c->response->redirect('/admin/categories');
    $c->detach();
}   

sub edit : Local Args
{
    my ( $self, $c, $cat_id ) = @_;
    my $i18n = $c->stash->{i18n};

    if (not defined $cat_id or $cat_id =~ /\D/)
    {   
        return $self->messageToList($c,$i18n->get_advanced('Error: Failed to locate a layout with the CATEGORY_ID %(CATEGORY_ID).', { CATEGORY_ID => $cat_id }));
    }
    else
    {
        my $category = $c->model('LIXUZDB::LzCategory')->find({category_id => $cat_id});
        if(not $category)
        {
            return $self->messageToList($c,$i18n->get_advanced('Error: Failed to locate a layout with the CATEGORY_ID %(CATEGORY_ID).', { CATEGORY_ID => $cat_id }));
        }
        else
        {
            my @catarray =$category->get_category_tree($c);
            my $catname = '/'.join('/',reverse(@catarray));
            $c->stash->{category_id} = $cat_id;
            $c->stash->{category_name} = $catname; 

            $c->stash->{pageTitle} = $c->stash->{i18n}->get('Article Ordering');
            my $template = $c->model('LIXUZDB::LzTemplate')->find({ type => 'list', is_default => 1});
            my $file = $template->path_to_template_file($c);

            my $info = cached_parse_templatefile($c,$file);

            $c->stash->{layout_str} =  $info->{TEMPLATE_LAYOUT};

            my $dnd = LIXUZ::HelperModules::DragDrop->new($c,'LIXUZDB::LzFolder','/admin/articles/folderAjax/',
                {
                    name => 'folder_name',
                    uid => 'folder_id',
                },
                {
                    immutable => 1, # FIXME: Drop
                    onclick => 'renderArticleList',
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
    my ( $self, $c, $cat_id) = @_;
    my $query = $c->req->param('query');;
    my $category;
    $self->c($c);
    my $i18n = $c->stash->{i18n};
    my $errorMessage;

    if (not defined $cat_id or $cat_id =~ /\D/)
    {
        $errorMessage = $i18n->get('Invalid category id');
    }
    else
    {
        $category = $c->model('LIXUZDB::LzCategory')->find({category_id => $cat_id});
        if (not $category)
        {
            $errorMessage = $i18n->get('Invalid category id');
        }
        else
        {
            if (defined $c->req->param('folder'))
            {            
                my $folder = $c->req->param('folder');
                if ($folder =~ /\D/)
                {
                    $errorMessage = $i18n->get('Invalid folder id');
                }
                else
                {
                     my $folder_cat = $c->model('LIXUZDB::LzCategoryFolder')->find({category_id => $cat_id, folder_id => $folder});
                     if (not $folder_cat)
                     {
                         $errorMessage = $i18n->get('This folder is not associated with the category');
                     }
                     else
                     {
                         $category = $c->model('LIXUZDB::LzCategory')->find({category_id => $cat_id, folder_id =>$folder});
                     }
                }
            }
            if ($errorMessage eq '' )
            {
                my $newer = $category->get_live_articles($c);
                $self->handleListRequest({
                        object => $newer,
                        objectName => 'artlist',
                        template => 'adm/categories/layout/list.html',
                        orderParams => [qw(article_id title status_id modified_time assigned_to_user author)],
                        searchColumns => [qw/title article_id body lead/],
                    });
           }
        }   
    }
    if (defined $errorMessage)
    {
        $c->stash->{errorMessage} = $errorMessage;
        $c->stash->{template} = 'adm/categories/layout/list.html';
    }

    $c->stash->{displaySite} = 0;
}

sub save : Local
{
    my ( $self, $c ) = @_;
    my $i18n = $c->stash->{i18n};
    my $pst_category_id = $c->req->param('hid_category_id');
    my $pst_template_id = $c->req->param('hid_template_id');
    if (not defined $pst_category_id or $pst_category_id =~ /\D/)
    {
        $self->messageToList($c, $i18n->get('Invalid category id.') );
    }
    elsif (not defined $pst_template_id or $pst_template_id =~ /\D/)
    {
        $self->messageToList($c, $i18n->get('Invalid template id.') );
    }
    elsif (not defined $c->req->param('spot_article') )
    {
        $self->messageToList($c, $i18n->get('Article ordering is empty.') );
    }
    else
    {
        my $del_order_obj = $c->model('LIXUZDB::LzCategoryLayout')->search({ category_id => $pst_category_id });
        $del_order_obj->delete_all;

        my @pst_article_order = $c->req->param('spot_article');
        my $i=1;
        foreach my $artid(@pst_article_order)
        {
            if ($artid != 0 && $artid != ' ')
            {
                my $insert_order_obj = $c->model('LIXUZDB::LzCategoryLayout')->create({
                    category_id => $pst_category_id,
                    article_id => $artid,
                    template_id => $pst_template_id,
                    spot => $i,
                });
                
                $insert_order_obj->update;
            }
            $i++;
        }
        $self->messageToList($c, $i18n->get('Article order saved successfully.') );
    }
}
1;
