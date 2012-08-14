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

package LIXUZ::Controller::Admin::Articles;

use 5.010_000;
use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
BEGIN { extends 'Catalyst::Controller::FormBuilder' };
with 'LIXUZ::Role::List::Database';

use LIXUZ::HelperModules::Forms qw(finalize_form);
use LIXUZ::HelperModules::DragDrop;
use LIXUZ::HelperModules::Lists qw(reply_json_list);
use LIXUZ::HelperModules::Includes qw(add_jsIncl add_cssIncl add_jsOnLoad add_globalJSVar add_jsOnLoadHeadCode);
use LIXUZ::HelperModules::Calendar qw(create_calendar datetime_to_SQL datetime_from_SQL datetime_from_unix);
use LIXUZ::HelperModules::Editor qw(create_editor);
use LIXUZ::HelperModules::JSON qw(json_response json_error);
use LIXUZ::HelperModules::Fields;
use LIXUZ::HelperModules::HTMLFilter qw(filter_string);
use LIXUZ::HelperModules::TemplateRenderer;
use LIXUZ::HelperModules::RevisionHelpers qw(article_latest_revisions get_latest_article set_other_articles_inactive);
use constant { true => 1, false => 0};

# --------
# The main list
# --------

# Summary: Show the primary list
sub index : Path Args(0) Form('/core/search')
{
    my ( $self, $c, $query ) = @_;
	add_jsIncl($c,'articles.js');
    my $article = $c->model('LIXUZDB::LzArticle');
    $c->stash->{pageTitle} = $c->stash->{i18n}->get('Articles');
    my $i18n = $c->stash->{i18n};
    my $message;
    my $msgStatus;
    my $msgReassign;

    if (defined $c->req->param('articlestatuschange')) 
    {
        foreach my $param (keys %{$c->req->params})
        {
            my $ID = $param;
            if ($ID =~ s/^article_Status_//)
            {
                if (not $ID=~/\D/)
                {
                    my $updatedstatus = $c->req->param($param);
                    my $articleobj = get_latest_article($c,$ID);
                    my $liverevision = $articleobj->get_column('revision');
                    if ($articleobj->can_write($c))
                    {
                        if ($c->user->can_access('STATUSCHANGE_'.$updatedstatus))
                        {
                            $articleobj->set_column('status_id',$updatedstatus);
                            $articleobj->update();
                            if ($updatedstatus == 2)
                            {
                                set_other_articles_inactive($c,$ID,$liverevision);
                            }
                            $msgStatus = 1;
                        }
                    }
                }
            }
            elsif($ID =~ s/^article_ReAssign_//)
            {
                if (not $ID=~/\D/)
                {
                    my $updatedassignedto = $c->req->param($param);
                    my $articleobj = get_latest_article($c,$ID);
                    my $workflow = $articleobj->workflow;
                    my $assigned_by = $workflow->assigned_by;

                    if ($articleobj->can_write($c))
                    {
                        if ((defined $assigned_by && $assigned_by == $c->user->user_id) || (defined $workflow->assigned_to_user && $workflow->assigned_to_user == $c->user->user_id) || $c->user->can_access('SUPER_USER'))
                        {
                            if ($updatedassignedto =~ s/^user_//)
                            {
                                if (not $updatedassignedto=~/\D/)
                                {
                                    my $userid = $c->model('LIXUZDB::LzUser')->find({user_id => $updatedassignedto});
                                    if (defined $userid and $userid->is_active)
                                    {
                                        if ($c->user->can_access('WORKFLOW_REASSIGN_TO_USER'))
                                        {
                                            $workflow->set_column('assigned_to_user',$updatedassignedto);
                                            $workflow->set_column('assigned_to_role',undef);
                                        }
                                    }
                                }
                            }
                            elsif($updatedassignedto =~ s/^role_//)
                            {                                
                                if (not $updatedassignedto=~/\D/)
                                {
                                    my $roleid = $c->model('LIXUZDB::LzRole')->find({role_id => $updatedassignedto});
                                    if (defined $roleid and $roleid->is_active)
                                    {
                                        if ($c->user->can_access('WORKFLOW_REASSIGN_TO_ROLE') and $c->user->can_access('WORKFLOW_REASSIGN_TO_ROLE_'.$updatedassignedto) )
                                        {
                                            $workflow->set_column('assigned_to_user',undef);
                                            $workflow->set_column('assigned_to_role',$updatedassignedto);
                                        }
                                    }
                                }
                            }
                            $workflow->update();
                            $msgReassign = 1;
                        }
                    }
                }
            }
        }

        if ($msgStatus == 1 and  $msgReassign ==1)
        {
            $message = $i18n->get('Article status changed, and article(s) have been reassigned');
        }
        elsif($msgStatus == 1)
        {
            $message = $i18n->get('Article status changed');
        }
        elsif($msgReassign == 1)
        {
            $message = $i18n->get('Article(s) have been reassigned');
        }


        $self->messageToList($c, $message );
    } 

    # Order the articles by default
    if(not $c->req->param('orderby'))
    {
        $c->req->params->{orderby} = 'modified_time';
        $c->req->params->{ordertype} = 'DESC';
        if ($c->model('LIXUZDB::LzBackup')->search({user_id => $c->user->user_id})->count())
        {
            add_jsOnLoad($c,'LZ_ArticleBackupsAvailable');
        }
    }

    # Set the search request as per role and user.
    if (defined $c->req->param('filter_assigned_to'))
    {
        my $qstring = $c->req->param('filter_assigned_to');
        if ($qstring =~ s/^user-//)
        {
            $c->req->params->{filter_assigned_to_user} = $qstring;
        }
        elsif($qstring =~ s/^role-//)
        {
            $c->req->params->{filter_assigned_to_role} = $qstring;
        }
    }        
    # Prepare the list
    my $list = $self->retrieveArticles($c,$article,$query);

    if ($c->req->param('_JSON_Submit'))
    {
        if ($c->req->param('list_type') && $c->req->param('list_type') eq 'pure')
        {
            return reply_json_list($c,$list, sub {
                    my($c,$art) = @_;
                    return if not $art->can_read($c);
                    my %r;
                    $r{article_id} = $art->article_id;
                    $r{title} = $art->title;
                    if ($art->status)
                    {
                        $r{status} = $art->status->status_name($c->stash->{i18n});
                    }
                    else
                    {
                        $r{status} = $c->stash->{i18n}->get('(unknown)');
                    }
                    return \%r; },'CODE_ARRAY');
        }
        else
        {
            return reply_json_list($c,$list,\&formatArticleJSON,'SINGLE');
        }
    }
    else
    {

        # Create drag and drop
        my $dnd = LIXUZ::HelperModules::DragDrop->new($c,'LIXUZDB::LzFolder','/admin/articles/folderAjax/',
            {
                name => 'folder_name',
                uid => 'folder_id',
            },
            {
                immutable => 1, # FIXME: Drop
                onclick => 'folderLimit',
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
        add_cssIncl($c,$dnd->get_cssfiles());
        $self->init_searchFilters($c);
    }
}

sub retrieveArticles : Private
{
    my $self = shift;
    my $c = shift;
    my $baseModel = shift;
    my $query = shift;
    my $formbuilder = shift;
    my $trashed = shift;
    $trashed //= 0;

    $self->c($c);

    $self->handleListRequest({
            query => $query,
            object => $baseModel,
            objectName => 'article',
            template => 'adm/articles/index.html',
            orderParams => [qw(article_id title status_id modified_time assigned_to_user author)],
            autoSearch => 0,
            formbuilder => $formbuilder,
            advancedSearch => [ qw(workflow.assigned_to_user workflow.assigned_by workflow.assigned_to_role status_id) ],
            searchColumns => [qw/title article_id body lead/],
        });
    $self->listAddJoin('workflow');

    # If we can't edit other peoples articles, *and* we can't preview
    # other peoples articles then limit the results
    if(not $c->user->can_access('EDIT_OTHER_ARTICLES') and not $c->user->can_access('PREVIEW_OTHER_ARTICLES'))
    {
        $self->listAddExpr({ '-or', => [
                { 'workflow.assigned_to_user' => $c->user->user_id },
                { 'workflow.assigned_to_role' => $c->user->role->role_id },
                ]});
    }

    $self->listAddJoin('revisionMeta');
    $self->listAddExpr({ 'revisionMeta.is_latest' => 1, trashed => $trashed});

    my $list = $self->listGetResultObject({ paginate => 1 });
    $c->stash->{article} = article_latest_revisions($list);
    return $list;
}

sub init_searchFilters : Private
{
    my ( $self, $c ) = @_;

    my $i18n = $c->stash->{i18n};
    my $userOptions = [];
    my $userOptionAccess = [];
    my $users = $c->model('LIXUZDB::LzUser')->search(undef,{ order_by => 'user_name' });
    while(my $user = $users->next)
    {
        next if !defined($user->user_name) || !length($user->user_name);
        push(@{$userOptions}, {
                value =>  'user-'.$user->user_id,
                label =>  $user->user_name.' '.$i18n->get('(user)'),
            });
        next if not $user->is_active or not $c->user->can_access('WORKFLOW_REASSIGN_TO_USER');
        push(@{$userOptionAccess}, {
                value => 'user_'.$user->user_id,
                label =>  $user->user_name.' '.$i18n->get('(user)'),
            });
    }
    my $roles= $c->model('LIXUZDB::LzRole')->search(undef,{ order_by => 'role_name' });
    while(my $role = $roles->next)
    {
        push(@{$userOptions}, {
            value =>  'role-'.$role->role_id,
            label =>  $role->role_name.' '.$i18n->get('(role)'),
        });
        next if not $role->is_active or not ( $c->user->can_access('WORKFLOW_REASSIGN_TO_ROLE') and $c->user->can_access('WORKFLOW_REASSIGN_TO_ROLE_'.$role->role_id) );
        push(@{$userOptionAccess}, {
                value =>  'role_'.$role->role_id,
                label =>  $role->role_name.' '.$i18n->get('(role)'),
            });
    }

    $c->stash->{userOptions} = $userOptionAccess;

    my $statusOptions = [];
    my $statusOptionAccess = [];
    my $statuses = $c->model('LIXUZDB::LzStatus');
    while(my $status = $statuses->next)
    {
        if ($c->user->can_access('STATUSCHANGE_'.$status->status_id))        
        {
            push(@{$statusOptionAccess}, {
                    value => $status->status_id,
                    label => $status->status_name($i18n),
            });        
        }
        push(@{$statusOptions}, {
                value => $status->status_id,
                label => $status->status_name($i18n),
        });
    }

    $c->stash->{statusOptions} = $statusOptionAccess;
    $c->stash->{searchFilters} = [
        {
            name => $i18n->get('Assigned to'),
            realname => 'assigned_to',
            options => $userOptions,
            selected => defined $c->req->param('filter_assigned_to') ? $c->req->param('filter_assigned_to') : undef,
            anyString => $i18n->get('(any user or role)'),
        },
        {
            name => $i18n->get('In status'),
            realname => 'status_id',
            options => $statusOptions,
            selected => defined $c->req->param('filter_status_id') ? $c->req->param('filter_status_id') : undef,
        },
    ];

    my $folder = $c->req->param('folder');
    if (defined $folder and not $folder =~ /\D/)
    {
        $c->stash->{filter_folder} = $folder;
    }
}
#-----------
# Read
#-----------

sub read : Local Args
{
    my ( $self, $c, $uid ) = @_;
    my $article;
    my $revision = $c->req->param('revision');
    if ($revision)
    {
        $article = $c->model('LIXUZDB::LzArticle')->find({ article_id => $uid, revision => $revision});
    }
    else
    {
        $article = get_latest_article($c,$uid);
    }
    my $i18n = $c->stash->{i18n};

    if(not $article)
    {
        if(get_latest_article($c,$uid))
        {
            return $self->messageToList($c,$i18n->get_advanced('Error: Failed to locate revision %(REVISION) of the article %(UID)', { UID => $uid, REVISION => $revision }));
        }
        return $self->messageToList($c,$i18n->get_advanced('Error: Failed to locate a article with the UID %(UID).', { UID => $uid }));
    }
    else
    {  
        if(not $c->user->can_access('PREVIEW_OTHER_ARTICLES'))
        {
            return $self->messageToList($c,$i18n->get('Permission denied'));
        }
        elsif(not $article->can_read($c))
        {
            return $self->messageToList($c,$i18n->get('Permission denied'));
        }
        else
        {
            my $folder_id;
            my $artid;
            my $revision =1;
            $artid = $article->article_id;
            if ($article && $article->folder)
            {
                $folder_id = $article->folder->folder_id;
            }
            $c->forward('LIXUZ::Controller::Admin::Articles::Workflow','writecheck',[undef, $article]) or $c->detach();
            $c->stash->{artfolder} = $article->primary_folder->folder->get_path();
            $c->stash->{artstatus} = $article->status->status_name($c->stash->{i18n});
            $c->stash->{artpubtime}= $article->human_publish_time();
            $c->stash->{artexptime} = $article->expiry_time;
            $c->stash->{articleUid} = $uid;

            my $files = [];
            if ($article->files)
            {
                my $file = $article->files;
                while(my $f = $file->next)
                {
                    my $caption = $f->caption;
                    my $fileObj = $f->file;
                    if(not defined $fileObj)
                    {
                        $c->log->warn('Failed to locate LzFile entry for file '.$f->file_id.' attached to object '.$f->article_id);
                        next;
                    }
                    if(not defined $caption)
                    {
                        $caption = $fileObj->caption;
                    }
                    my $fileNameSplit = $fileObj->file_name;
                    $fileNameSplit =~ s/(.{17})/$1<br \/>/g;
                    my $info = {
                        iconItem =>$fileObj->get_icon($c),
                        iconItemBody => $fileObj->get_url_aspect($c,250,250),
                        file_id => $fileObj->file_id,
                        file_name => $fileNameSplit,
                        fsize => $fileObj->sizeString($c),
                        caption => $caption,
                        identifier => $fileObj->identifier,
                        fields => {},
                    };
                    my $fields = $fileObj->getAllFields($c);
                    if ($fields)
                    {
                        foreach my $f (keys %{$fields})
                        {
                            my $field = $c->model('LIXUZDB::LzField')->find({ field_id => $f });
                            $info->{fields}->{ $field->field_name } = $fields->{$f};
                        }
                    }
                    push(@{$files},$info);
                }
            }

            $c->stash->{files} = $files;

            my $fieldr = [];
            my $fields = LIXUZ::HelperModules::Fields->new($c,'articles',$article->article_id,{
                folder_id => $article->folder->folder_id,
                revision => $article->revision,
            });


            
            my @fieldList = $fields->get_fields;
            foreach my $field (@fieldList)
            {
                $field = $field->field;
                my $fieldname;
                my $value;
                if ($field->inline)
                {
                    $fieldname = $field->inline;
                    my $val = $c->model('LIXUZDB::LzArticle')->find({ article_id => $article->article_id, revision => $article->revision});
                    if ($fieldname eq 'folder')
                    {
                        $value = $val->primary_folder->folder->get_path();
                    }
                    elsif($fieldname eq 'status_id')
                    {
                        $value = $val->status->status_name($c->stash->{i18n});
                    }
                    elsif($fieldname eq 'template_id')
                    {
                        my $temp_id = $val->template_id;
                        if (defined $temp_id)
                        {
                            my $tmpl =  $c->model('LIXUZDB::LzTemplate')->find({ template_id => $temp_id, type => 'article' });
                            $value = $tmpl->name;
                        }
                        else
                        {
                            $value = $i18n->get('Default Template');
                        }
                    }
                    else
                    {
                        $value =$val->get_column($fieldname);
                    }
                }
                else
                {
                    $fieldname = $field->field_name;
                    $value = $article->getField($c, $field->field_id);
                }
                push(@{$fieldr},{
                        fieldname => $field->human_field_name($c),
                        fieldval => $value
                    });
            }

            $c->stash->{fieldr} = $fieldr;

            $c->stash->{filesInArticle} = $article->files->count();
            $c->stash->{secondaryFoldersForArticle} = $article->secondary_folders->count();
            $c->stash->{commentsForArticle} = $article->comments->count();
            $c->stash->{additionalElementsForArticle} = $article->additionalElements->count();
            $c->stash->{relationships} = $article->relationships;
            $c->stash->{elements} = $article->additionalElements;

            my $deadline = $i18n->get('(none)');
            if ($article->workflow->deadline)
            {
                $deadline = datetime_from_SQL($article->workflow->deadline);
            }
            my $starttime = $i18n->get('(none)');
            if ($article->workflow->start_date)
            {
                $starttime = datetime_from_SQL($article->workflow->start_date);
            }
            $c->stash->{deadline} = $deadline; 
            $c->stash->{starttime} = $starttime;
            $c->stash->{articleRevision} = $article->revision;
            $c->stash->{artid} = $artid;
            $c->forward('LIXUZ::Controller::Admin::Articles::Workflow','preparePage',[ $article ]);
            $c->stash->{rarticle} = $article;
            $c->stash->{template} = 'adm/articles/read/read.html';
            add_jsIncl($c,
                'articles.js',
                'utils.js',
                'files.js',
            );
        }
    }
}

# --------
# Preview
# --------

# Summary: Handle displaying a preview of an existing article
sub preview : Local Args
{
    my ( $self, $c, $uid ) = @_;
    my $revision = $c->req->param('revision');
    my $article;
    if ($revision)
    {
        $article = $c->model('LIXUZDB::LzArticle')->find({ article_id => $uid, revision => $revision});
    }
    else
    {
        $article = get_latest_article($c,$uid);
    }
    my $i18n = $c->stash->{i18n};
    if(not $article)
    {
        if(get_latest_article($c,$uid))
        {
            return $self->messageToList($c,$i18n->get_advanced('Error: Failed to locate revision %(REVISION) of the article %(UID)', { UID => $uid, REVISION => $revision }));
        }
        return $self->messageToList($c,$i18n->get_advanced('Error: Failed to locate a article with the UID %(UID).', { UID => $uid }));
    }
    if (
        (not defined $article->workflow->assigned_to_user or $article->workflow->assigned_to_user != $c->user->user_id) && 
        (not defined $article->workflow->assigned_to_role or $article->workflow->assigned_to_role != $c->user->role->role_id) && 
        (not $c->user->can_access('PREVIEW_OTHER_ARTICLES'))
    )
    {
        return $self->messageToList($c,$i18n->get('Permission denied'));
    }
    elsif(not $article->can_read($c))
    {
        return $self->messageToList($c,$i18n->get('Permission denied'));
    }
    if ($c->req->param('_JSON_Submit'))
    {
        return $self->previewInfo($c,$article);
    }
    my $template = $article->template;
    if(not $template)
    {
        $template = $c->model('LIXUZDB::LzTemplate')->find({ is_default => 1, type => 'article'});
    }
    my $renderer = LIXUZ::HelperModules::TemplateRenderer->new(
        c => $c,
        template => $template,
    );
    my $can_comment = 'false';
    if($c->forward('LIXUZ::Controller::Admin::Articles::Workflow','can_write',[undef, $article]) or $c->user->can_access('COMMENT_PREVIEWED_ARTICLES'))
    {
        $can_comment = 'true';
    }
    my $can_edit = 'false';
    if ($article->can_write($c) and not $article->locked($c))
    {
        $can_edit = 'true';
    }
    my $can_break_lock = 'false';
    my $is_locked = 'false';
    my $lockedBy = '';
    if ($c->req->param('locked') and $c->req->param('locked') eq 'true')
    {
        $is_locked = 'true';
        $lockedBy = $article->lockTable->user->name;
        if ($c->user->can_access('SUPER_USER'))
        {
            $can_break_lock = 'true';
        }
    }

    my $includes = '<!-- Lixuz preview includes -->'."\n";
    $includes .= '<link rel="stylesheet" type="text/css" href="/css/jqueryui/jquery-ui.css" /> ';
    my @scripts = qw( /jquery.plugins.lib.js /core.js /articles-previewUI.js);
    if ($c->stash->{lixuzLang})
    {
        push(@scripts,'/i18n/'.$c->stash->{lixuzLang}.'.js');
    }
    foreach my $script (@scripts)
    {
        $includes .= '<script src="/js'.$script.'" type="text/javascript"></script>';
    }
    $includes .= '<script type="text/javascript">var LZ_PREVIEW_ARTICLE_ID = '.$article->article_id.';';
    $includes .= 'var LZ_PREVIEW_CAN_COMMENT = '.$can_comment.';';
    $includes .= 'var LZ_PREVIEW_CAN_EDIT = '.$can_edit.';';
    $includes .= 'var LZ_PREVIEW_IS_LOCKED = '.$is_locked.';';
    $includes .= 'var LZ_PREVIEW_CAN_BREAK_LOCK = '.$can_break_lock.';';
    $includes .= 'var LZ_PREVIEW_LOCKEDBY = "'.$lockedBy.'";';
    if ($c->stash->{lixuzLang})
    {
        $includes .= 'window._LANGUAGE = "'.$c->stash->{lixuzLang}.'";';
    }
    $includes .= '</script>';
    $includes .= "\n".'<!-- End of Lixuz preview includes -->'."\n";
    $article->clearCache($c);
    $renderer->set_statevar('primaryArticle',$article);
    $renderer->set_statevar('primaryArticleIsValid',1);
    $renderer->resolve_var('lz_preview_mode',$includes);
    $renderer->autorender();
}


sub previewInfo : Private
{
    my($self,$c,$article) = @_;
    my $return = {
        workflow => {},
        article => {},
        elements => {},
        files => [],
        fields => {},
    };

    my $wf = $return->{workflow};
    $wf->{assigned_to} = $article->workflow->assigned_to_string($c);
    $wf->{assigned_by} = $article->workflow->assigned_by_string($c);
    $wf->{deadline} = datetime_from_SQL($article->workflow->deadline); 
    $wf->{start_date} = datetime_from_SQL($article->workflow->start_date); 
    $wf->{priority} = $article->workflow->priority;

    my $art = $return->{article};
    $art->{pubtime} = $article->human_publish_time();
    $art->{exptime} = $article->expiry_time; # Get human_expiry_time ?
    $art->{folder_path} = $article->primary_folder->folder->get_path();
    $art->{status} = $article->status->status_name($c->stash->{i18n});

    my $fields = LIXUZ::HelperModules::Fields->new($c,'articles',$article->article_id,{
            folder_id => $article->folder->folder_id,
            revision => $article->revision,
        });

    my @fieldList = $fields->get_fields;
    foreach my $field (@fieldList)
    {
        $field = $field->field;
        next if $field->inline;
        my $value = $c->model('LIXUZDB::LzFieldValue')->find({ field_id => $field->field_id, module_name => 'articles', module_id => $article->article_id });
        next if not $value;
        $return->{fields}->{$field->field_name} = $value->human_value();
    }

    if ($article->additionalElements)
    {
        my $e = $article->additionalElements;
        while(my $el = $e->next)
        {
            $el = $el->element;
            $return->{elements}->{$el->keyvalue_id} = {
                key => $el->thekey,
                value => $el->value,
                type => $el->type,
            };
        }
    }

    if ($article->files)
    {
        my $files = $article->files;
        while(my $f = $files->next)
        {
            my $caption = $f->caption;
            if(not defined $caption)
            {
                $caption = $f->file->caption;
            }
            my $info = {
                iconItem => $f->file->get_iconItem($c),
                file_id => $f->file->file_id,
                caption => $caption,
                identifier => $f->file->identifier
            };
            push(@{$return->{files}},$info);
        }
    }

    return json_response($c,$return);
}

# --------
# Adding, deleting and editing
# --------

# Summary: Handle creating a new article
sub add: Local
{
    my ( $self, $c ) = @_;
    my $i18n = $c->stash->{i18n};
    $self->buildform($c,'add');
    $c->forward('LIXUZ::Controller::Admin::Articles::Workflow','preparePage',[ undef ]);
}

# Summary: Handle editing an existing article
sub edit: Local Args
{
    my ( $self, $c, $uid ) = @_;
    my $i18n = $c->stash->{i18n};
    # If we don't have an UID then just give up
    if (not defined $uid or $uid =~ /\D/)
    {
        $c->log->warn('Invalid UID supplied to articles/edit: '.$uid);
        $self->messageToList($c,$i18n->get('Error: Failed to locate UID. The path specified is invalid.'));
    }
    else
    {
        # Check if the article exists
        my $article = get_latest_article($c,$uid);
        if(not $article)
        {
            # Didn't exist, give up
            $self->messageToList($c,$i18n->get_advanced('Error: Failed to locate a article with the UID %(UID).', { UID => $uid }));
        }
        else
        {
            # Existed, perform ACL check
            $c->forward('LIXUZ::Controller::Admin::Articles::Workflow','writecheck',[undef, $article]) or $c->detach();

            if (not $article->lock($c,true))
            {
                if ($c->user->can_access('SUPER_USER') and $c->req->param('stealLock') and $c->req->param('stealLock') eq 'true')
                {
                    $article->lock($c,true,true);
                    add_jsOnLoadHeadCode($c,'userMessage("'.$i18n->get('You have stolen the edit lock for this article.').'")');
                }
                else
                {
                    $c->response->redirect('/admin/articles/preview/'.$uid.'?locked=true');
                    $c->detach();
                }
            }
            # Allowed, generate our form and display it
            $c->stash->{articleUid} = $uid;
            $c->stash->{articleRevision} = $article->revision;
            $self->buildform($c,'edit',$article);
            $c->forward('LIXUZ::Controller::Admin::Articles::Workflow','preparePage',[ $article ]);
        }
    }
}

# Summary: Delete a article (and get a confirmation from the article about it)
sub delete: Local Args
{
    my ( $self, $c, $uid ) = @_;
    my $i18n = $c->stash->{i18n};
    my $article;
    $c->stash->{template} = 'adm/core/dummy.html';
    # If we don't have an UID then just give up
    if (not defined $uid or $uid =~ /\D/)
    {
        if ($c->req->param('_JSON_Submit'))
        {
            return json_error($c,'INVALIDUID');
        }
        else
        {
            $self->messageToList($c,$i18n->get('Error: Failed to locate UID. The path specified is invalid.'));
        }
    }
    else
    {
        my $backups = $c->model('LIXUZDB::LzBackup')->search({ backup_source_id => $uid, backup_source => 'article'});
        while(( defined $backups) and (my $backup = $backups->next))
        {
            $backup->delete();
        }
        $article = $c->model('LIXUZDB::LzArticle')->find({article_id => $uid});
        # TODO: Maybe we should be using delete_all() ?
        $article->workflow->delete();
        $article->delete();
        if ($c->req->param('_JSON_Submit'))
        {
            return json_response($c);
        }
        else
        {
            $self->messageToList($c,$i18n->get('Article deleted'));
        }
    }
}

# Summary: Build a form with localized field labels and optionally pre-populate it
# Usage: $self->buildform($c,'TYPE',\%Populate);
# 'TYPE' is one of:
# 	add => we're adding a article
# 	edit => we're editing an existing article
# \%Populate is a hashref in the form:
# 	fieldname => default value
# This will pre-populate fieldname with the value specified
sub buildform: Private
{
    my ( $self, $c, $type, $article) = @_;
    my $i18n = $c->stash->{i18n};
    $c->stash->{template} = 'adm/articles/edit.html';

    my $folder_id;
    my $artid;
    my $revision = 1;

    if ($article && $article->folder)
    {
        $folder_id = $article->folder->folder_id;
    }
    elsif(not $article)
    {
        if (defined $c->req->param('folder_id') && not $c->req->param('folder_id') =~ /\D/)
        {
            $folder_id = $c->req->param('folder_id');
        }
    }
    if ($article)
    {
        $artid = $article->article_id;
        $revision = $article->revision;
    }
    my $fields = LIXUZ::HelperModules::Fields->new($c,'articles',$artid,{
            folder_id => $folder_id,
            revision => $revision,
            inlineFetchHandler => sub
            {
                return $self->art_fetch_fielddata(@_,$article);
            }
        });
    $fields->editorInit();

    if (defined $folder_id)
    {
        my $folder = $c->model('LIXUZDB::LzFolder')->find({ folder_id =>$folder_id});
        if(not $folder and not $article)
        {
            die("Invalid folder\n");
        }
        elsif($folder)
        {
            $folder->check_write($c);
        }
    }

    if ($article && $article->folder)
    {
        $c->stash->{pageTitle} = $i18n->get_advanced('Editing article %(ARTICLE_ID)',{ ARTICLE_ID => $article->article_id});
    }
    elsif ($article)
    {
        $c->stash->{pageTitle} = $i18n->get_advanced('Editing article %(ARTICLE_ID)',{ ARTICLE_ID => $article->article_id});
    }
    else
    {
        $c->stash->{pageTitle} = $i18n->get('Creating article');
    }
    # Name mapping of field name => title
    if ($article)
    {
        $c->stash->{filesInArticle} = $article->files->count();
        $c->stash->{secondaryFoldersForArticle} = $article->secondary_folders->count();
        $c->stash->{commentsForArticle} = $article->comments->count();
        $c->stash->{additionalElementsForArticle} = $article->additionalElements->count();
        $c->stash->{tags} = $article->tags;
    }
    my %NameMap = (
        title => $i18n->get('Title'),
        lead => $i18n->get('Lead'),
        author => $i18n->get('Author'),
        body => $i18n->get('Body'),
        pubtime => $i18n->get('Publish time'),
        exptime => $i18n->get('Expires at'),
        article_order => $i18n->get('Order'),
        template => $i18n->get('Template'),
        article_status => $i18n->get('Status'),
    );
    # Add the type of editing
    $c->stash->{artEditType} = $type;
    my $folderId;
    if ($article)
    {
        $folderId = $article->folder;
        if (defined $folderId)
        {
            $folderId = $folderId->folder_id;
        }
        $c->stash->{liveComments_enabled} = $article->live_comments;
    }
    elsif(defined $c->req->param('folder_id') && not $c->req->param('folder_id') =~ /\D/)
    {
        if ($c->model('LIXUZDB::LzFolder')->find({folder_id => $c->req->param('folder_id')}))
        {
            $folderId = $c->req->param('folder_id')
        }
    }
    # Relationships
    if ($article)
    {
        $c->stash->{relationships} = $article->relationships;
        $c->stash->{files} = $article->files;
        $c->stash->{elements} = $article->additionalElements;
    }

    # TODO: This can probably be cleaned down to a bare minimum, we're not
    # actually using this list, just grabbing deps.
    my $dnd = LIXUZ::HelperModules::DragDrop->new($c,'LIXUZDB::LzFolder','/admin/articles/folderAjax/',
        {
            name => 'folder_name',
            uid => 'folder_id',
        },
        {
            immutable => 1, # FIXME: Drop
            onclick => 'toggleHilight',
        },
    );

    # INCLUDES/ONLOAD
    # Primary
    add_jsIncl($c,
        'articles.js',
        'utils.js',
        'files.js',
    );
    add_jsOnLoad($c,'init_article_backup');
    add_globalJSVar($c,'pollServer_interval_pageDefault',180000);
    # Folders
	add_jsIncl($c,$dnd->get_jsfiles());
	add_cssIncl($c,$dnd->get_cssfiles());
    add_globalJSVar($c,'hilightedFoldersSeed','[]');
}

# --------
# Data fetching and saving
# --------

sub art_fetch_fielddata
{
    my($self,$c, $uid, $field,$article) = @_;

    my $fnam = $field->inline;
    my $i18n = $c->stash->{i18n};

    if(not defined $c->stash->{_art_info})
    {
        $c->stash->{_art_info} = {
            status_id => $i18n->get('Status'),
            title => $i18n->get('Title'),
            body => $i18n->get('Body'),
            lead => $i18n->get('Lead'),
            author => $i18n->get('Author'),
            publish_time => $i18n->get('Publish time'),
            expiry_time => $i18n->get('Expiry time'),
            folder => $i18n->get('Primary folder'),
            template_id => $i18n->get('Template'),
        };
    }

    my $had = 0;

    foreach(qw(status_id title lead body author publish_time expiry_time folder template_id))
    {
        if ($_ eq $fnam)
        {
            $had = 1;
            last;
        }
    }

    if(not $had)
    {
        $c->log->warn('Invalid field requested from Articles.pm: '.$fnam);
        return;
    }

    my $info = $c->stash->{_art_info}->{$fnam};
    if(not defined $article)
    {
        if(not $fnam =~ /(status_id|author|folder|publish_time|template_id)/)
        {
            return(undef,$info);
        }
        else
        {
            if ($fnam eq 'author')
            {
                my $value = $c->user->firstname.' '.$c->user->lastname;
                return($value,$info);
            }
            elsif($fnam eq 'publish_time')
            {
                # TODO: Might want a datetime_to_SQL_from_unix
                return(datetime_to_SQL(datetime_from_unix(time())),$info);
            }
        }
    }

    # TODO: More special handlers
    my $data;
    if($fnam eq 'status_id')
    {
        my @statusList;
        my $statuses = $c->model('LIXUZDB::LzStatus')->search({});
        my $statusId = 1;
        if ($statuses && $statuses->count > 0)
        {
            while(my $status = $statuses->next)
            {
                if ((defined $article && defined $article->status_id && $article->status_id == $status->status_id) or ($c->user->can_access('STATUSCHANGE_'.$status->status_id)))
                {
                    my $sel = 0;
                    if (defined $article && $article && $article->status_id && $article->status_id == $status->status_id)
                    {
                        $sel = 1;
                        $statusId = $article->status_id;
                    }
                    else
                    {
                        if ($status->status_id == 1)
                        {
                            $sel = 1;
                        }
                    }
                    push(@statusList, { name => $status->status_name($i18n), value => $status->status_id, selected => $sel });
                }
            }
        }
        $data = {
            options => \@statusList,
            real_value => $statusId,
        };
    }
    elsif($fnam eq 'folder')
    {
        my $folderId;
        if ($article)
        {
            $folderId = $article->primary_folder->folder_id;
        }
        elsif($c->req->param('folder_id'))
        {
            $folderId = $c->req->param('folder_id');
        }

        if (defined $folderId)
        {
            my $tree = $c->forward(qw(LIXUZ::Controller::Admin::Services buildtree),[ $folderId ]);
            if(not $folderId)
            {
                $tree = '<option value="">'.$i18n->get('-select-').'</option>'.$tree;
            }
            $data = { rawtree => $tree };
        }
    }
    elsif($fnam eq 'template_id')
    {
        my $tree = '<option value="undef">'.$i18n->get('(Default template)').'</option>';

        my $template_id;
        if(defined $article)
        {
            $template_id = $article->template_id;
        }
        elsif(defined $c->req->param('template_id') && $c->req->param('template_id') =~ /^\d+$/)
        {
            $template_id = $c->req->param('template_id');
        }

        my $template = $c->model('LIXUZDB::LzTemplate')->search({ type => 'article' }, { order_by => \'is_default,uniqueid' });
        while((defined $template) && (my $t = $template->next))
        {
            my $default = '';
            if (defined $template_id && $t->template_id == $template_id)
            {
                $default = ' selected="selected"';
            }
            $tree .= '<option value="'.$t->template_id.'"'.$default.'>'.( $t->name || $t->uniqueid ).'</option>';
        }
        $data = { rawtree => $tree };
    }
    elsif(defined($article))
    {
        $data = $article->get_column($fnam);
    }

    return($data,$info);
}

# --------
# Comments service
# --------
# Note: These are the live-site comments made by users. Not to be confused with
# the completely separate Workflow comment system. You will find that in the
# workflow controller.

# Summary: Retrieve a list of comments
sub getCommentListFor : Local Args
{
    my ($self,$c,$articleId) = @_;
    my $article;
    if(not defined $articleId)
    {
        return json_error($c,'NO_ARTID');
    }
    if (! ($article = $c->model('LIXUZDB::LzArticle')->find({article_id => $articleId}, { prefetch => 'comments' })))
    {
        return json_error($c,'INVALID_ARTID');
    }
    my $comments = $article->comments->search(undef,{ order_by => 'created_date'});
    my @data;
    while(my $comment = $comments->next)
    {
        push(@data,{ comment_id => $comment->comment_id,
                ip => $comment->ip,
                author_name => $comment->author_name,
                body => $comment->body,
                subject => $comment->subject,
                datetime => datetime_from_SQL($comment->created_date),
            });
                
    }
    return json_response($c,{ commentList => \@data });
}

# Summary: Delete a comment
sub deleteComment : Local Args
{
    my ($self,$c,$commentId) = @_;
    my $comment;
    if(not ($comment = $c->model('LIXUZDB::LzLiveComment')->find({comment_id => $commentId})))
    {
        return json_error($c,'INVALID_ID');
    }
    my $article = $comment->article;
    $c->forward('LIXUZ::Controller::Admin::Articles::Workflow','writecheck',[undef, $article]) or $c->detach();
    $comment->delete;
    return json_response($c);
}

sub folderMoveCheck : Private
{
    my ($self,$c) = @_;
    my $newFolder = $c->req->param('newFolder');
    my $article_id = $c->req->param('article_id');
    my $article = $c->model('LIXUZDB::LzArticle')->search({ article_id => $article_id }, { order_by => \'revision DESC' })->next;
    if (not $article)
    {
        return json_error($c,'ARTNOTFOUND');
    }

	my $fid;
	if ($article->folder)
	{
		$fid = $article->folder->folder_id;
	}

    if(not defined $fid or not defined $newFolder or $newFolder == $fid)
    {
        return json_response($c, { foundFiles => 0 });
    }

    my $files = $article->files;
    my @filesInSameDir;
    while((defined $files) and (my $f = $files->next))
    {
        if ((not defined $f->file->folder_id) or ($f->file->folder_id eq $fid))
        {
            push(@filesInSameDir,$f->file_id);
        }
    }
    if (@filesInSameDir)
    {
        $c->stash->{'MULTIREQ_STOP_PROCESSING'} = true;
        return json_response($c,{ foundFiles => 1, filesInSameDir => \@filesInSameDir });
    }
    return json_response($c, { foundFiles => 0 });
}

# --------
# Utility methods
# --------

# Summary: Builds a tree of folders into a string of <option></option> pairs
# Usage: $tree = $self->buildtree($c, ($obj), ($currParent));
#
# $folderId is teh folder id to be selected, or undef
#
# $obj is only used internally for recursively calling itself
# $currParent is only used internally for tracking parents
sub buildtree : Private
{
    my ($self, $c, $folderId, $obj, $currParent) = @_;
    $c->log->warn('buildtree in Articles.pm used, forwarding to buildTree in Services.pm');
    shift;shift;
    return $c->forward(qw(LIXUZ::Controller::Admin::Services buildtree),\@_);
}

sub formatArticleJSON
{
    my($c, $articleList) = @_;
    my $articleListHTML = '<table>';
    while(my $art = $articleList->next)
    {
        next if not $art->can_read($c);
        $articleListHTML .= '<tr><td>'.$art->article_id.'</td><td><a href="#" onclick="LZ_OS_ObjectClicked('.$art->article_id.'); return false;">'.$art->title.'</a></td></tr>';
    }
    return $articleListHTML;
}

1;
