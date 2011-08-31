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

package LIXUZ::Controller::Admin::Articles::Trash;

use strict;
use warnings;
use base qw(Catalyst::Controller::FormBuilder);
use LIXUZ::HelperModules::Includes qw(add_jsIncl add_cssIncl add_jsOnLoad add_globalJSVar);
use LIXUZ::HelperModules::JSON qw(json_response json_error);
use LIXUZ::HelperModules::RevisionHelpers qw(get_latest_article article_latest_revisions);

sub index : Path Args(0) Form('/core/search')
{
    my($self,$c,$query) = @_;
	add_jsIncl($c,'articles.js');
    my $article = article_latest_revisions($c->model('LIXUZDB::LzArticle')->search({ trashed => 1 }));
    my $list = $c->forward(qw(LIXUZ::Controller::Admin::Articles retrieveArticles),[ $article, $query, $self->formbuilder,1]);
    $c->stash->{template} = 'adm/articles/trashList.html';
    $c->stash->{pageTitle} = $c->stash->{i18n}->get('Trash (articles)');
    $c->stash->{trashMode} = 1;
}

sub delete : Local Args
{
    my($self,$c, $artid) = @_;
    # If we don't have an UID then just give up
    if (not defined $artid or $artid =~ /\D/)
    {
        return json_error($c,'INVALIDARTID');
    }
    else
    {
        my $article = get_latest_article($c,$artid);
        if(not $article)
        {
            return json_error($c,'ARTNOTFOUND');
        }
        elsif(not $article->trashed)
        {
            return json_error($c,'NOT_TRASHED','Attempted to delete non-trashed article');
        }
        elsif(not $article->can_write($c))
        {
            return json_error($c,'PERMISSIONDENIED');
        }
        my $backups = $c->model('LIXUZDB::LzBackup')->search({ backup_source_id => $artid, backup_source => 'article'});
        while(( defined $backups) and (my $backup = $backups->next))
        {
            $backup->delete();
        }
        my $articles = $c->model('LIXUZDB::LzArticle')->search({ article_id => $artid });
        while(my $art = $articles->next)
        {
            # TODO: Maybe we should be using delete_all() ?
            $art->workflow->delete();
            $art->delete();
        }
        return json_response($c);
    }
}

sub move : Local Args
{
    my($self,$c, $artid) = @_;
    # If we don't have an UID then just give up
    if (not defined $artid or $artid =~ /\D/)
    {
        return json_error($c,'INVALIDARTID');
    }
    else
    {
        my $article = get_latest_article($c,$artid);
        if(not $article)
        {
            return json_error($c,'ARTNOTFOUND');
        }
        elsif($article->trashed)
        {
            return json_error($c,'ALREADY_TRASHED','Article is already in the trash');
        }
        elsif(not $article->can_write($c))
        {
            return json_error($c,'PERMISSIONDENIED');
        }


        my $articles = $c->model('LIXUZDB::LzArticle')->search({ article_id => $artid });

        while(my $art = $articles->next)
        {
            # Make the status id 'Inactive' instead of 'Live'
            if (not defined $article->status_id or $article->status_id == 2)
            {
                $art->set_column('status_id',4);
            }

            $art->set_column('trashed',1);
            $art->update();
        }
        return json_response($c);
    }
}

sub restore : Local Args
{
    my($self,$c, $artid) = @_;
    # If we don't have an UID then just give up
    if (not defined $artid or $artid =~ /\D/)
    {
        return json_error($c,'INVALIDARTID');
    }
    else
    {
        my $article = get_latest_article($c,$artid);
        if(not $article)
        {
            return json_error($c,'ARTNOTFOUND');
        }
        elsif(not $article->trashed)
        {
            return json_error($c,'NOT_TRASHED','Attempted to restore non-trashed article');
        }
        elsif(not $article->can_write($c))
        {
            return json_error($c,'PERMISSIONDENIED');
        }
        my $articles = $c->model('LIXUZDB::LzArticle')->search({ article_id => $artid });

        while(my $art = $articles->next)
        {
            $art->set_column('trashed',0);
            $art->update();
        }
        return json_response($c);
    }
}

1;
