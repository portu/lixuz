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

package LIXUZ::Controller::Admin::Articles::JSON;
use Moose;
BEGIN { extends 'Catalyst::Controller' };

use 5.010;
use Try::Tiny;
use LIXUZ::HelperModules::JSON qw(json_response json_error);
use LIXUZ::HelperModules::RevisionHelpers qw(article_latest_revisions get_latest_article set_other_articles_inactive);

# Summary: Handle folder-related actions
sub folderHandler : Path('/admin/articles/folderAjax')
{
    my ($self, $c) = @_;
    $c->stash->{template} = 'adm/core/dummy.html';
    # Create drag and drop
    my $dnd = LIXUZ::HelperModules::DragDrop->new($c,'LIXUZDB::LzFolder','/admin/articles/folderAjax/',
        {
            name => 'folder_name',
            uid => 'folder_id',
        });
    $c->stash->{content} = $dnd->handleInput();
    $c->stash->{displaySite} = 0;
}

sub changeRevisionStatus
{
    my ($self,$c) = @_;
    my $revision = $c->req->param('revision');
    my $article = $c->req->param('article_id');
    my $status = $c->req->param('status_id');
    
    my $art = $c->model('LIXUZDB::LzArticle')->find({ article_id => $article, revision => $revision });
    if(not $art)
    {
        return json_error($c, 'INVALID_ART');
    }
    if ($art->status_id == $status)
    {
        return json_error($c, 'STATUS_IDENTICAL');
    }
    if (not $c->user->can_access('STATUSCHANGE_'.$status))
    {
        return json_error($c,'STATUSCHANGE_DENIED');
    }
    $art->set_column('status_id', $status);
    $art->update();
    if ($status == 2)
    {
        set_other_articles_inactive($c,$article,$revision);
    }
    $c->model('LIXUZDB::LzArticle')->search({
            article_id => $article,
            status_id => $status,
            revision => { '!=' => $revision },
            'revisionMeta.is_latest_in_status' => 1
        }, { join => 'revisionMeta' })->search_related('revisionMeta')->update({ is_latest_in_status => 0 });

    return json_response($c);
}

sub statusList : Local
{
    my($self,$c) = @_;

    my %ret;

    my $statuses = $c->model('LIXUZDB::LzStatus');
    while(my $status = $statuses->next)
    {
        my %info;
        $info{id} = $status->status_id;
        $info{can_access} = $c->user->can_access('STATUSCHANGE_'.$status->status_id);
        $ret{$status->status_name($c->stash->{i18n})} = \%info;
    }
    return json_response($c,{ statuses => \%ret });
}

# Summary: Handle input from article ajax
sub ajaxHandler : Path('/admin/articles/ajax')
{
    my ($self, $c) = @_;
    $c->stash->{template} = 'adm/core/dummy.html';
    my $wants = $c->req->param('wants');
    if(not $wants)
    {
        return json_error($c,'WANTSMISSING');
    }
    # TODO: Drop it
    elsif($wants eq 'folderList')
    {
        $c->log->debug('folderList from Articles.pm requested, forwarding to folderList in Services.pm');
        return $c->detach(qw(LIXUZ::Controller::Admin::Services folderList));
    }
    elsif($wants eq 'changeRevStatus')
    {
        return $self->changeRevisionStatus($c);
    }
    elsif($wants eq 'statusList')
    {
        return $self->statusList($c);
    }
    elsif($wants eq 'articleList')
    {
        return $self->getArticleList($c);
    }
    elsif($wants eq 'revisionList')
    {
        return $self->fetchRevisionList($c);
    }
    elsif($wants eq 'articleInfo')
    {
        return $self->getArticleInfo($c);
    }
    elsif($wants eq 'additionalElements')
    {
        return $self->getAdditionalElements($c);
    }
    elsif($wants eq 'folderMove')
    {
        $c->detach(qw(LIXUZ::Controller::Admin::Articles folderMoveCheck));
    }
    elsif($wants eq 'secondaryFolders')
    {
        $self->fetchSecondaryFoldersList($c);
    }
    elsif($wants eq 'fileInfo')
    {
        $self->fetchFileInfo($c);
    }
    else
    {
        return json_error($c,'WANTSINVALID');
    }
    $c->log->warn('Warning: Reached end of handleOther in Articles::JSON. Was processing wants='.$wants);
}

sub fetchFileInfo
{
    my($self,$c) = @_;


    my @files;
    my $req = $c->req->params->{fileId};
    if(ref($req))
    {
        @files = @{$req};
    }
    else
    {
        push(@files,$req);
    }
    my %ret;

    foreach my $file (@files)
    {
        my $f = $c->model('LIXUZDB::LzFile')->find({file_id => $file});
        $ret{$file} = $f->to_hash;
    }

    return json_response($c,\%ret);
}

sub fetchRevisionList
{
    my($self,$c) = @_;
    my $article_id = $c->req->param('article_id');
    my $article = $c->model('LIXUZDB::LzArticle')->search({ article_id => $article_id} , { order_by => 'revision DESC' });
    my $return = [];

    while(my $art = $article->next)
    {
        my $data = {};
        $data->{revision} = $art->revision;
        $data->{title} = $art->title;
        try
        {
            $data->{savedBy} = $art->revisionMeta->committed_by->user_name;
        };
        try
        {
            $data->{savedBy} //= '(unknown - assignee: '.$art->workflow->assigned_to_string($c,1).')';
        };
        $data->{savedBy} //= '(unknown)';
        $data->{status} = $art->status->status_name($c->stash->{i18n});
        $data->{status_id} = $art->status->status_id,
        $data->{savedAt} = $art->revisionMeta->created_at;
        push(@{$return},$data);
    }
    return json_response($c, { revisions => $return });
}

# Summary: Return a list of articles, paginated, to the client code
sub getArticleList : Private
{
    my($self,$c) = @_;
    my $folder = $c->req->param('folder_id') || $c->req->param('filter_folder');
    if(not defined $folder)
    {
        return json_error($c,'NOFOLDERID');
    }
    elsif(not my $folder_obj = $c->model('LIXUZDB::LzFolder')->find({folder_id => $folder}))
    {
        return json_error($c,'INVALIDFOLDER');
    }
    my $articleList = $c->model('LIXUZDB::LzArticleFolder')->search({folder_id => $folder},{ prefetch => 'article'});
    my $articleListHTML = '<table>';
    while(my $art = $articleList->next)
    {
        $articleListHTML .= '<tr><td>'.$art->article_id.'</td><td><a href="#" onclick="LZ_OS_ObjectClicked('.$art->article_id.'); return false;">'.$art->article->title.'</a></td></tr>';
    }
    return json_response($c,{files_grid => $articleListHTML, requestForId => $folder });
}

# Summary: Get information about an article
sub getArticleInfo : Private
{
    my($self,$c) = @_;
    my $article_id = $c->req->param('article_id');
    my $article = get_latest_article($c,$article_id);
    if (not $article)
    {
        return json_error($c,'ARTNOTFOUND');
    }
    return json_response($c,{article_id => $article_id, article_title => $article->title});
}

# Summary: Get a list of additional elements an article has
sub getAdditionalElements : Private
{
    my($self,$c) = @_;
    my $article_id = $c->req->param('article_id');
    my $article = get_latest_article($c,$article_id);
    if(not $article_id or not $article)
    {
        return json_error($c,'ARTNOTFOUND');
    }
    my $elements = $article->additionalElements;
    if (not $elements)
    {
        return json_response($c, {elements => []});
    }
    my @elements;
    while(my $element = $elements->next)
    {
        my $e = $element->element;
        push(@elements,[ $e->keyvalue_id, $e->thekey, $e->value, $e->type ]);
    }
    return json_response($c, {elements => \@elements});
}

# Summary: Fetch secondary folders list
sub fetchSecondaryFoldersList : Private
{
    my($self,$c) = @_;
    my $article_id = $c->req->param('article_id');
    my $article = get_latest_article($c,$article_id);
    if(not $article)
    {
        return json_error($c,'INVALIDARTID','The article id '.$article_id.' was not found');
    }
    # Perform ACL check
    $c->forward('LIXUZ::Controller::Admin::Articles::Workflow','writecheck',[undef, $article]) or $c->detach();
    my $dnd = LIXUZ::HelperModules::DragDrop->new($c,'LIXUZDB::LzFolder','/admin/articles/folderAjax/',
        {
            name => 'folder_name',
            uid => 'folder_id',
        },
        {
            onclick => 'toggleHilight',
        },
    );

    my $sf = $article->secondary_folders;
    my @folders;
    while((defined $sf) and (my $f = $sf->next))
    {
        push(@folders,$f->folder_id);
    }
    return json_response($c,{ tree => $dnd->get_htmlOnly(), folders => \@folders });
}

# Summary: Handle file spot assignments
sub assignFileToSpot : Local Path('/admin/articles/assignFileToSpot')
{
    my($self,$c) = @_;

    foreach my $p (qw(file artid spot))
    {
        if(not defined $c->req->param($p)
                or not length $c->req->param($p)
                or $c->req->param($p) =~ /\D/)
        {
            if ($p eq 'spot' && $c->req->param($p) && $c->req->param($p) eq 'null')
            {
                next;
            }
            return json_error($c,'INVALIDPARAM',$p);
        }
    }

    my $file = $c->req->param('file');
    my $artid = $c->req->param('artid');
    my $spot = $c->req->param('spot');

    $file = $c->model('LIXUZDB::LzFile')->find({ file_id => $file });
    my $article = get_latest_article($c,$artid);

    if(not $file)
    {
        return json_error($c,'INVALIDFILE');
    }
    if(not $article)
    {
        return json_error($c,'INVALIDARTID');
    }
    if ($spot eq 'null')
    {
        $spot = undef;
    }
    elsif ($spot > 999)
    {
        return json_error($c,'UNREASONABLE_HIGH_SPOTNO');
    }

    my @removed;

    if (defined $spot)
    {
        my $existing = $article->files->search({spot_no => $spot});

        while((defined $existing) && (my $e = $existing->next))
        {
            push(@removed,$e->file_id);
            $e->set_column('spot_no',undef);
            $e->update();
        }
    }

    my $obj = $c->model('LIXUZDB::LzArticleFile')->find({ article_id => $artid, file_id => $file->file_id});
    if(not $obj)
    {
        return json_error($c,'NO_EXISTING_REL');
    }

    $obj->set_column('spot_no',$spot);
    $obj->update();
    $article->clearCache($c);

    return json_response($c,{ removed => \@removed });
}

sub setFileCaption : Local Path('/admin/articles/setFileCaption')
{
    my($self,$c) = @_;
    my $article = $c->req->param('article_id');
    my $file = $c->req->param('file');
    $article = get_latest_article($c,$article);

    if(not $article)
    {
        return json_error($c,'INVALIDARTID');
    }

    $file = $article->files->find({file_id => $file});
    if(not $file)
    {
        return json_error($c,'INVALIDFILEID');
    }
    my $caption = $c->req->param('caption');

    $file->set_column('caption',$caption);
    $file->update();
    $article->clearCache($c);
    return json_response($c);
}

# Summary: Retrieve a list of taken file spots on a page
sub getTakenFileSpots : Local
{
    my($self,$c) = @_;
    my %taken;
    my $article = $c->req->param('article_id');
    if(defined($article) && length($article))
    {
        $article = get_latest_article($c,$article);

        if(not $article)
        {
            return json_error($c,'INVALIDARTID');
        }

        if ($article->files)
        {
            my $files = $article->files->search({ spot_no => \'IS NOT NULL' });
            while((defined $files) && (my $f = $files->next))
            {
                $taken{$f->spot_no} = $f->file_id;
            }
        }
    }

    return json_response($c, { taken => \%taken });
}

1;
