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

package LIXUZ::Controller::Admin::Articles::Submit;
use Moose;
BEGIN { extends 'Catalyst::Controller::REST' };

# TODO: Make this controller completely RESTful. That is POST for creation of a new article, PUT for updates, DELETE for deletion (at some point)
#       Also use the catalyst RESTFul status methods rather than our json functions

use constant { true => 1, false => 0};
use LIXUZ::HelperModules::JSON qw(json_response json_error);
use LIXUZ::HelperModules::Calendar qw(create_calendar datetime_to_SQL datetime_from_SQL);
use List::MoreUtils qw(any);
use LIXUZ::HelperModules::RevisionControl::Article;
use LIXUZ::HelperModules::RevisionHelpers qw(article_latest_revisions get_latest_article);
use LIXUZ::HelperModules::HTMLFilter qw(filter_string);
use LIXUZ::HelperModules::EMail qw(send_email_to);

sub index : Path : ActionClass('REST') {};

# Summary: Handle article saving via JSON
sub index_POST
{
    my ( $self, $c ) = @_;
    my $jsonReply = {};
    my $i18n = $c->stash->{i18n};
    my $uid = $c->req->data->{'uid'};
    my $type = (defined $uid and length $uid) ? 'edit' : 'add';
    my $article;
    my $workflow;

    if ($type eq 'edit')
    {
        # FIXME: Should fetch from a revision param submitted rather than fetching latest.
        $article = get_latest_article($c,$uid);
        if(not $article)
        {
            return json_error($c,'INVALIDARTID');
        }
        $workflow = $c->model('LIXUZDB::LzWorkflow')->find_or_create({ article_id => $uid, revision => $article->revision });
        if (not $article->can_edit($c))
        {
            $c->user->access_denied();
            return;
        }
    }
    elsif($type eq 'add')
    {
        $article = $c->model('LIXUZDB::LzArticle')->new_result(
            {
                created_time => \'now()',
            }
        );
        $workflow = $c->model('LIXUZDB::LzWorkflow')->new_result({ article_id => $article->article_id });
        $uid = $article->article_id;
    }
    else
    {
        return json_error($c,'TYPE','Invalid type: '.$type);
    }
    if ($article->locked($c))
    {
        return json_error($c,'LOCKED',undef,true,{ lockedBy => $article->lockTable->user->name });
    }
	if(not $article)
	{
        return json_error($c,'NOARTOBJ','Failed to create an article object!');
	}

    my $RCS = LIXUZ::HelperModules::RevisionControl::Article->new( committer => $c->user->user_id );
    $RCS->set_root($article);
    $RCS->add_object($workflow);

    if (!$self->savedata_article($c,$article,$type,$jsonReply,$RCS))
    {
        return json_error($c,$jsonReply->{error},$jsonReply->{verboseError});
    }

    # FIXME: The problem here is that we're returning an error, but it's only a partial failure
    my($result,$sendRoleNotifications,$sendUserNotification) = $self->savedata_workflow($c,$article,$workflow,$type,$jsonReply,$RCS);

    if (!$result)
    {
        return json_error($c,$jsonReply->{error},$jsonReply->{verboseError});
    }

    $self->savedata_relationships($c,$article,$RCS);
    $self->savedata_files($c,$article,$RCS);
    $self->savedata_elements($c,$article,$RCS);
    $self->savedata_tags($c,$article,$RCS);

    $article = $RCS->commit();

    $jsonReply->{uid} = $article->article_id;
    $jsonReply->{revision} = $RCS->revision;

    if ($sendRoleNotifications)
    {
        $c->forward(qw(LIXUZ::Controller::Admin::Articles::Workflow notifyRoleMembers), [ $workflow, $c->model('LIXUZDB::LzRole')->find({ role_id => $workflow->get_column('assigned_to_role') }) ]);
    }
    elsif($sendUserNotification)
    {
        $self->notifyNewAssignee($c,$workflow,$article);
    }

    return json_response($c,$jsonReply);
}

# Summary: Save relationship data
sub savedata_relationships
{
    my ($self, $c, $article,$RCS) = @_;

    my $existing = $article->relationships;
    my $submitted = $c->req->data->{relationships} || {};
    isHash($submitted);

    # FIXME: There are better ways to do this
    while(my $rel = $existing->next)
    {
        my $id = $rel->related_article_id;
        if ($submitted->{$id} && $submitted->{$id} eq $rel->relation_type)
        {
            delete($submitted->{$id});
            next;
        }
        $RCS->delete_object($rel);
    }

    foreach my $relID (keys %{$submitted})
    {
        if (not $submitted->{$relID} =~ /^(related|previous)$/)
        {
            $c->log->debug('Submitted relation '.$relID.' provided invalid relation type "'.$submitted->{$relID}.'" - skipping entry. Buggy submission code.');
            next;
        }
        my $related_article = get_latest_article($c,$relID);
        if(not $related_article)
        {
            $c->log->debug('Submitted relation with '.$relID.' is invalid. No such article. Skipping this entry');
            next;
        }
        my $newRelationship = $c->model('LIXUZDB::LzArticleRelations')->new_result({article_id => $article->article_id, related_article_id => $related_article->article_id, relation_type => $submitted->{$relID} });
        $RCS->add_object($newRelationship);
    }
}

# Summary: Save the core article data (ie. lead/body, ..)
sub savedata_article
{
    my ( $self, $c, $article, $type, $jsonReply,$RCS ) = @_;
    my $i18n = $c->stash->{i18n};

	my $origFolder;
	if ($article->folder)
	{
		$origFolder = $article->folder->folder_id,
	}

    my $fields = LIXUZ::HelperModules::Fields->new($c,'articles',$article->article_id,{
            inlineSaveHandler => sub {
                $self->art_save_fielddata(@_,$article,$RCS);
            },
            revisionControl => $RCS,
            revision => $RCS->revision,
        });
    $fields->saveData();

	if (not $origFolder and $article->folder)
	{
		$origFolder = $article->folder->folder_id,
	}
    my $newPrimaryFolder = $c->stash->{newPrimaryFolder};

    # -- Secondary folders --
    if(defined($c->req->data->{'secondaryFolders'}))
    {
        if ($c->req->data->{'secondaryFolders'} ne 'null')
        {
            my %folders;
            # Extract parameters and shove them into %folders
            if(length $c->req->data->{'secondaryFolders'})
            {
                foreach my $folder (split(',',$c->req->data->{'secondaryFolders'}))
                {
                    if(not $folder == $newPrimaryFolder)
                    {
                        $folders{$folder} = 1;
                    }
                }
            }
            # Handle deleting removed folders
            my $sf = $article->secondary_folders;
            while(defined($sf) and (my $f = $sf->next))
            {
                if (not $folders{$f->article_id})
                {
                    $RCS->delete_object($f);
                }
                else
                {
                    delete($folders{$f->article_id});
                }
            }
            # Handle creating new relationships
            foreach my $fid (keys %folders)
            {
                my $art = $c->model('LIXUZDB::LzArticleFolder')->new_result({
                        article_id => $article->article_id,
                        folder_id => $fid,
                        primary_folder => 0,});
                delete($folders{$fid});
                $RCS->add_object($art);
            }
        }
    }
    else
    {
        my $sf = $article->secondary_folders;
        while(defined($sf) and (my $f = $sf->next))
        {
            $RCS->delete_object($f);
        }
    }
    if ($c->req->data->{'LZ_ArticleMoveFilesFound'} and $origFolder != $newPrimaryFolder)
    {
        my $files = $article->files;
        while((defined $files) && (my $f = $files->next))
        {
            my $file = $f->file;
            if ((not defined $file->folder_id) or ($file->folder_id eq $origFolder))
            {
                if(my $secondary = $file->folders->search({ folder_id => $newPrimaryFolder }))
                {
                    $secondary->delete;
                }
                my $primary = $file->primary_folder;
                if ($primary)
                {
                    $primary->set_column('folder_id',$newPrimaryFolder);
                }
                else
                {
                    $primary = $c->model('LIXUZDB::LzFileFolder')->create({
                            file_id => $file->file_id,
                            folder_id => $newPrimaryFolder,
                            primary_folder => 1
                        });
                }
                $primary->update;
            }
        }
    }

    # Live comment settings
    if($c->user->can_access('TOGGLE_LIVECOMMENTS') and defined($c->req->data->{'article_liveComments_enable'}))
    {
        if ($c->req->data->{'article_liveComments_enable'} =~ /^(false|0)$/)
        {
            $article->set_column('live_comments',0);
        }
        else
        {
            $article->set_column('live_comments',1);
        }
    }

    # Delete backups
    my $backup;
    if ($type eq 'add')
    {
        $backup = $c->model('LIXUZDB::LzBackup')->find({user_id => $c->user->user_id, backup_source => 'article', backup_source_id => \'IS NULL'});
    }
    else
    {
        $backup = $c->model('LIXUZDB::LzBackup')->find({user_id => $c->user->user_id, backup_source => 'article', backup_source_id => $article->article_id});
    }
    if ($backup)
    {
        $backup->delete();
    }

        $article->set_column('modified_time',\'NOW()');
        $RCS->add_object($article);
        # XXX: Might not be needed
        $article->clearCache($c);

    if($c->req->data->{'articleSaveAndClose'})
    {
        $article->unlock($c);
    }
    else
    {
        $article->lock($c,true);
    }

	return true;
}

# Summary: Save article<->files relationships
sub savedata_files
{
    my ($self, $c, $article,$RCS) = @_;

    my $existing = $article->files;
    my $submitted = $c->req->data->{files} || [];
    isArray($submitted);

    my %fileIdList;

    foreach my $e (@{$submitted})
    {
        $fileIdList{$e->{file_id}} = 1;
    }

    # Remove files no longer in the submitted list
    while(my $f = $existing->next)
    {
        if(not $fileIdList{$f->file_id})
        {
            $RCS->delete_object($f);
        }
    }

    foreach my $entry (@{$submitted})
    {
        my $rel = $RCS->find_or_new('LIXUZDB::LzArticleFile',{
                article_id => $article->article_id,
                file_id => $entry->{file_id}
            });
        $rel->set_column('spot_no',$entry->{spot_no});
        $rel->set_column('caption',$entry->{caption});
        $RCS->add_object($rel);
    }
}

# Summary: Save relationships with additional elements
sub savedata_elements
{
    my ($self, $c, $article,$RCS) = @_;

    my $existing = $article->additionalElements;
    my $submitted = $c->req->data->{elements} || {};
    isHash($submitted);

    # Remove elements no longer in the submitted list
    while(my $f = $existing->next)
    {
        if(not $existing->{$f->keyvalue_id})
        {
            $RCS->delete_object($f);
        }
    }

    foreach my $entry (keys %{$submitted})
    {
        my $rel = $RCS->find_or_new('LIXUZDB::LzArticleElements',{
                article_id => $article->article_id,
                keyvalue_id => $entry,
            });
        $RCS->add_object($rel);
    }
}

# Summary: Save relationships with tags
sub savedata_tags
{
    my ($self, $c, $article,$RCS) = @_;

    my $existing = $article->tags;
    my $submitted = $c->req->data->{tags} || [];
    isArray($submitted);

    # Remove elements no longer in the submitted list
    while(my $f = $existing->next)
    {
        if(not $existing->{$f->tag_id})
        {
            $RCS->delete_object($f);
        }
    }

    foreach my $entry (@{$submitted})
    {
        my $rel = $RCS->find_or_new('LIXUZDB::LzArticleTag',{
                article_id => $article->article_id,
                tag_id => $entry,
            });
        $RCS->add_object($rel);
    }
}

# TODO: We need to have some way to check if the use had the latest version of the data, prior to
# 		the change. Perhaps some form of checksum or something that it can submit along with the new data,
# 		and if it doesn't match the latest one in the DB, refuse to commit changes and return the information
# 		to the client.
# FIXME: We need some additional permission checks
# Summary: Process data submitted from client code
sub savedata_workflow
{
    my ( $self, $c, $article, $workflow, $type, $jsonReply,$RCS ) = @_;

	my ($priority, $startdate, $deadline, $watch);

	my $created = $type eq 'add' ? 1 : 0;

    my $sendRoleNotifications = false;
    my $sendUserNotification = false;

	my %PriorityMap = (
		'low' => 1,
		'medium' => 2,
		'high' => 3,
	);

	$priority = $c->req->data->{'workflow_priority'};
    if(defined  $c->req->data->{'workflow_watch_article'} && $c->req->data->{'workflow_watch_article'} eq 'true')
    {
        $watch = 1;
    }
    else
    {
        $watch = 0;
    }
	$startdate = $c->req->data->{'workflow_startdate'};
	$deadline = $c->req->data->{'workflow_deadline'};

    my $reassign = {
        role => $c->req->data->{'workflow_reassignToRole'} ? $c->req->data->{'workflow_reassignToRole'} : 'null',
        user => $c->req->data->{'workflow_reassignToUser'} ? $c->req->data->{'workflow_reassignToUser'} : 'null'
    };
    # Ensure we're not trying to reassign to two at the same time
    if(not ($reassign->{role} eq 'null') && not ($reassign->{user} eq 'null'))
    {
        return json_error($c,'REASSIGN','Can only reassign to a user, or a role. Never both.');
    }
    # Make sure both reassign fields are valid.
    foreach my $part (keys %{$reassign})
    {
        if (not $reassign->{$part} eq 'null' and $reassign->{$part} =~ /\D/)
        {
            $jsonReply->{error} = 'REASSIGN';
            $jsonReply->{verboseError} = 'Unable to reassign to the invalid value: '.$reassign->{$part};
            return false;
        }
        elsif(not $reassign->{$part} eq 'null')
        {
            my $obj;
            if ($part eq 'user')
            {
                if ($c->user->can_access('WORKFLOW_REASSIGN_TO_USER'))
                {
                    $obj = $c->model('LIXUZDB::LzUser')->find({ user_id => $reassign->{$part} });
                }
                else
                {
                    return json_error($c,'REASSIGN','Permission denied');
                }
            }
            elsif ($part eq 'role')
            {
                if ($c->user->can_access('WORKFLOW_REASSIGN_TO_ROLE') and $c->user->can_access('WORKFLOW_REASSIGN_TO_ROLE_'.$reassign->{$part}))
                {
                    $obj = $c->model('LIXUZDB::LzRole')->find({ role_id => $reassign->{$part} });
                }
                else
                {
                    return json_error($c,'REASSIGN','Permission denied');
                }
            }
            if(not $obj)
            {
                return json_error($c,'REASSIGN','Failed to look up the user or role supplied');
            }
        }
    }


	if (! ($priority = $PriorityMap{$priority}))
	{
		return json_error($c,'PRIORITY','Unknown priority supplied');
	}
	foreach my $e ($priority, $watch, $startdate, $deadline)
	{
		if(not defined $e)
		{
			return json_error($c,'PARAMS','Parameter mismatch, missing data');
		}
	}
	if ($created)
	{
        $workflow->set_column('assigned_by',$c->user->user_id);
        $workflow->set_column('assigned_to_user',$c->user->user_id);
        $RCS->add_object($workflow);
	}


    # Reassign if required
    if (not $reassign->{user} eq 'null')
    {
        if ( (not defined $workflow->assigned_to_user) or (not $workflow->assigned_to_user == $reassign->{user}))
        {
            $sendUserNotification = true;
        }
        $workflow->set_column('assigned_by',$c->user->user_id);
        $workflow->set_column('assigned_to_user',$reassign->{user});
        $workflow->set_column('assigned_to_role',undef);
    }
    elsif(not $reassign->{role} eq 'null')
    {
        my $wasAssignedToRole = $workflow->assigned_to_role;
        if (!$wasAssignedToRole || $wasAssignedToRole != $reassign->{role})
        {
            $sendRoleNotifications = 1;
        }
        $workflow->set_column('assigned_by',$c->user->user_id);
        $workflow->set_column('assigned_to_role',$reassign->{role});
        $workflow->set_column('assigned_to_user',undef);
    }

	$workflow->set_column('priority',$priority);
    my $canSetDeadline = $created ? $c->user->can_access('WORKFLOW_SETINITIAL_DEADLINE') : $c->user->can_access('WORKFLOW_CHANGE_DEADLINE');
    if ($canSetDeadline)
    {
        if(length($deadline))
        {
            $workflow->set_column('deadline',datetime_to_SQL($deadline));
        }
        else
        {
            $workflow->set_column('deadline',undef);
        }
    }
    $workflow->set_column('start_date',datetime_to_SQL($startdate));

    # Run the preparation method to get information for json_response
    $c->forward('LIXUZ::Controller::Admin::Articles::Workflow','prepare', [undef,$workflow]);

    my $watched = $c->model('LIXUZDB::LzArticleWatch')->find({ user_id => $c->stash->{user_id}, article_id => $article->article_id });
    if ($watched and not $watch)
    {
        $watched->delete();
    }
    elsif(!$watched && $watch)
    {
        $watched = $c->model('LIXUZDB::LzArticleWatch')->create({ user_id => $c->stash->{user_id}, article_id => $article->article_id });
        $watched->update();
    }

#    if ($workflowDiff->has_changed() || $c->flash->{articleAutoDiff})
#    {
#        $workflow->update() if ($workflowDiff->has_changed());
#
#        $self->createChangeLog($c,$workflow,$workflowDiff);
#
#        $self->notifyWatchers($c,$workflowDiff,$article->article_id);
#    }

    $jsonReply->{assigned_to} = $c->stash->{w_assigned_to};
    $jsonReply->{assigned_by} = $c->stash->{w_assigned_by};
    return (true,$sendRoleNotifications,$sendUserNotification);
}

# Summary: Generate and send an e-mail to the person that recieves an assignment
# Usage: self->notifyNewAssignee($c,$article,$diff);
sub notifyNewAssignee
{
    my($self,$c,$workflow,$article) = @_;

    my $i18n = $c->stash->{i18n};
    my $assignedBy = $c->user;
    my $assignedTo = $c->model('LIXUZDB::LzUser')->find({ user_id => $workflow->get_column('assigned_to_user')});

    if ($assignedBy->user_id == $assignedTo->user_id)
    {
        return;
    }
    if ( !$workflow)
    {
        $c->log->error('notifyNewAssignee called without $workflow');
        return;
    }
    elsif ( !$article)
    {
        $c->log->error('notifyNewAssignee called without $article');
        return;
    }

    my $subject = $i18n->get_advanced('%(USER) has assigned article %(ARTICLE_ID) (%(ARTICLE_NAME)) to you',
        {
            ARTICLE_NAME => $article->title,
            ARTICLE_ID   => $article->article_id,
            USER         => $assignedBy->name
        });
    my $message = $i18n->get_advanced('The article "%(ARTICLE_NAME)" (%(ARTICLE_ID)) has been'."\n".'assigned to you by %(USER). You may now edit'."\n".'and manage this article in Lixuz at %(PAGE).', {
            PAGE         => $c->uri_for('/admin/articles/edit/'.$article->article_id),
            ARTICLE_NAME => $article->title,
            ARTICLE_ID   => $article->article_id,
            USER         => $assignedBy->verboseName
        });

    send_email_to($c,undef, $subject, $message, $assignedTo->verboseEmail);
}

# Summary: Generate and send e-mails to watchers
# Usage: self->notifyWatchers($c,$workflowDiff,$articleId);
# This takes care of notifying watchers about changes to both article
# and workflow.
sub notifyWatchers : Private
{
    my ($self, $c, $workflowDiff,$artid) = @_;

    return;
    # FIXME

    my $i18n = $c->stash->{i18n};
    my $watchers = $c->model('LIXUZDB::LzArticleWatch')->search({ article_id => $artid });
    my $hasContent = false;
    if (not $watchers)
    {
        return;
    }

    # -- Generate the message --
    my $message = $i18n->get_advanced("Some changes has been made by %(FIRSTNAME) %(LASTNAME) (%(USERNAME))\nto an article (ID %(ARTICLE_ID)) you are watching:",{ ARTICLE_ID => $artid, FIRSTNAME => $c->user->firstname, LASTNAME => $c->user->lastname, USERNAME => $c->user->user_name })."\n\n";

    # First, process article diffs
    my $artDiff = $c->flash->{articleAutoDiff};
    delete($c->flash->{articleAutoDiff});
    if ($artDiff)
    {
        foreach my $key (sort keys %{$artDiff})
        {
            my $diffMessage;
            if (not defined $artDiff->{$key})
            {
                $c->log->error('the value hash for '.$key.' was undef in the article diff. Ignoring in diff mail for artid '.$artid);
                next;
            }
            elsif(not defined $artDiff->{$key}->{'new'})
            {
                if(not defined $artDiff->{$key}->{'old'})
                {
                    $c->log->error('the new and old value was undef for '.$key.' in the article diff. Ignoring in diff mail for artid '.$artid);
                }
                else
                {
                    $c->log->error('the new value was undef for '.$key.' in the article diff. Ignoring in diff mail for artid '.$artid);
                }
                next;
            }
            # To ensure that empty 'old's are handled properly
            elsif(not defined $artDiff->{$key}->{'old'})
            {
                $artDiff->{$key}->{'old'} = '';
            }
            if ($key eq 'title')
            {
                $diffMessage = $i18n->get_advanced('Title change: "%(old)" => "%(new)."',$artDiff->{$key});
            }
            elsif($key eq 'lead')
            {
                $diffMessage = $i18n->get('The lead has been changed.');
            }
            elsif($key eq 'body')
            {
                $diffMessage = $i18n->get('The body has been changed.');
            }
            elsif($key eq 'author')
            {
                $diffMessage = $i18n->get_advanced('Author change: "%(old)" => "%(new)."',$artDiff->{$key});
            }
            elsif($key eq 'publish_time')
            {
                # TODO: We may want to convert the old and new values into the same as would have been
                # shown in the main UI. The same counts for expiry_time
                $diffMessage = $i18n->get_advanced('Publish time has changed: "%(old)" => "%(new)."',$artDiff->{$key});
            }
            elsif($key eq 'expiry_time')
            {
                $diffMessage = $i18n->get_advanced('Expiry time has changed: "%(old)" => "%(new)".',$artDiff->{$key});
            }
            elsif($key eq 'template_id')
            {
                my $template;
                foreach my $k (qw(old new))
                {
                    $template = $c->model('LIXUZDB::LzTemplate')->find({ template_id => $artDiff->{$key}->{$k} });
                    if ($template)
                    {
                        $artDiff->{$key}->{$k} = $template->name;
                    }
                    else
                    {
                        $artDiff->{$key}->{$k} = $i18n->get('(default)');
                    }
                }
                # FIXME: Delete cache keys
                $diffMessage = $i18n->get_advanced('Template change: "%(old)" => "%(new)".',$artDiff->{$key});
            }
            elsif($key eq 'status_id')
            {
                my $status;
                foreach my $k (qw(old new))
                {
                    $status = $c->model('LIXUZDB::LzStatus')->find({ status_id => $artDiff->{$key}->{$k} });
                    if ($status)
                    {
                        $artDiff->{$key}->{$k} = $status->status_name($i18n);
                    }
                    else
                    {
                        if (defined $artDiff->{$key}->{$k} && length($artDiff->{$key}->{$k}))
                        {
                            $c->log->warn('Failed to locate a status object for status_id: '.$artDiff->{$key}->{$k});
                        }
                        $artDiff->{$key}->{$k} = $i18n->get('(none)');
                    }
                }
                $diffMessage = $i18n->get_advanced('Status change: "%(old)" => "%(new)".',$artDiff->{$key});
            }
            else
            {
                $c->log->warn('The key '.$key.' from the Article changelog was unhandled');
                next;
            }
            if ($diffMessage)
            {
                $message .= $diffMessage."\n";
                $hasContent = true;
            }
        }
    }

    if ($workflowDiff->has_changed())
    {
        my $wfDiff = $workflowDiff->get_diff();
        foreach my $key (sort keys %{$wfDiff})
        {
            my $diffMessage;
            if (not defined $wfDiff->{$key})
            {
                $c->log->error('the value hash for '.$key.' was undef in the workflow diff. Ignoring in diff mail for artid '.$artid);
                next;
            }
            elsif(not defined $wfDiff->{$key}->{'new'})
            {
                if(not defined $wfDiff->{$key}->{'old'})
                {
                    $c->log->error('the new and old value was undef for '.$key.' in the workflow diff. Ignoring in diff mail for artid '.$artid);
                }
                else
                {
                    $c->log->error('the new value was undef for '.$key.' in the workflow diff. Ignoring in diff mail for artid '.$artid);
                }
                next;
            }
            # To ensure that empty 'old's are handled properly
            elsif(not defined $wfDiff->{$key}->{'old'})
            {
                $wfDiff->{$key}->{'old'} = '';
            }
            if ($key eq 'priority')
            {
                my %PriorityMap = (
                    1 => $i18n->get('Low'),
                    2 => $i18n->get('Medium'),
                    3 => $i18n->get('High'),
                );
                foreach my $k (qw(old new))
                {
                    my $v = $wfDiff->{$key}->{$k};
                    if (defined $v)
                    {
                        $wfDiff->{$key}->{$k} = $PriorityMap{$v} ? $PriorityMap{$v} : $v;
                    }
                    else
                    {
                        $wfDiff->{$key}->{$k} = $i18n->get('(none)');
                    }
                }
                $diffMessage = $i18n->get_advanced('Priority change: "%(old)" => "%(new)".',$wfDiff->{$key});
            }
            elsif($key eq 'start_date')
            {
                $diffMessage = $i18n->get_advanced('The start date changed: "%(old)" => "%(new)".',$wfDiff->{$key});
            }
            elsif($key eq 'deadline')
            {
                $diffMessage = $i18n->get_advanced('The deadline changed: "%(old)" => "%(new)".',$wfDiff->{$key});
            }
            # Skip for now
            elsif($key eq 'assigned_to_user')
            {
                next;
            }
            else
            {
                $c->log->warn('The key '.$key.' from the Workflow changelog was unhandled');
                next;
            }
            if ($diffMessage)
            {
                $message .= $diffMessage."\n";
                $hasContent = true;
            }
        }
    }

    # Don't send empty e-mails
    if(not $hasContent)
    {
        return;
    }

    if ($message =~ /%\((old|new)\)/)
    {
        $c->log->warn('The diff message for artid '.$artid.' contained an %(old) or %(new) placeholder');
    }

    my $from_address = $c->config->{LIXUZ}->{from_email};
    if(not $from_address)
    {
        $c->log->error('from_email is not set in the config, using dummy e-mail');
        $from_address = 'EMAIL_NOT_SET_IN_CONFIG@localhost';
    }

    my @recipients;
    while(my $watcher = $watchers->next)
    {
        next if not $watcher->user;
        # Don't send an e-mail to the user that triggered this change.
        if ($c->user->user_id == $watcher->user->user_id)
        {
            next;
        }

        push(@recipients,$watcher->user->firstname.' '.$watcher->user->lastname.' <'. $watcher->user->email.'>');
    }
    if (@recipients)
    {
        send_email_to($c, $i18n->get("This message has been automatically generated by Lixuz because you\nare watching this article. You can stop watching this article\nby going to its edit page."), $i18n->get_advanced('An article you are watching (%(ARTID)) has been edited',{ ARTID => $artid }), $message,@recipients);
    }
}

# Summary: Handle saving a single article field (inline or not)
sub art_save_fielddata
{
    my($self,$c,$uid, $field,$value, $obj,$RCS) = @_;
    my $had = 0;
    my $fnam = $field->inline;
    my %FieldMap = (
        exptime => 'expiry_time',
        pubtime => 'publish_time',
    );
    my $rfnam = defined $FieldMap{$fnam} ? $FieldMap{$fnam} : $fnam;
    foreach (qw(title lead body author modified_time publish_time article_order status_id expiry_time folder template_id))
    {
        if ($_ eq $fnam)
        {
            $had = 1;
            last;
        }
    }

    if(not $had)
    {
        $c->log->debug('Invalid field requested for saving in Articles.pm/art_save_fielddata: '.$fnam);
        return;
    }

    if(not length $value)
    {
        $value = undef;
    }

    if(defined $value)
    {
        if ($fnam eq 'lead' or $fnam eq 'body')
        {
            $obj->set_column($rfnam,filter_string($value));
        }
        elsif($fnam eq 'folder')
        {
            my $f = $obj->folder;
            if ($f)
            {
                $RCS->delete_object($f);
            }
            $f = $c->model('LIXUZDB::LzArticleFolder')->new_result({ folder_id => $value, article_id => $obj->article_id, primary_folder => 1});
            $RCS->add_object($f);
            $c->stash->{newPrimaryFolder} = $value;
        }
        elsif($fnam eq 'status_id')
        {
            my $status = $c->model('LIXUZDB::LzStatus')->find({status_id => $value});
            if ($status)
            {
                if(not defined $obj->status_id or not $status->status_id == $obj->status_id)
                {
                    # FIXME: What if we just created this article?
                    if (not $c->user->can_access('STATUSCHANGE_'.$status->status_id))
                    {
                        return 'STATUSCHANGE_DENIED';
                    }
                    $obj->set_column('status_id',$status->status_id);
                    # This bit of code is for special handling of status
                    # changes from live to anything else.  Usually we just let
                    # the old revision stay in whichever status it's in, but
                    # it's been said that this is confusing when one wants to
                    # remove a live article from the website - so this special
                    # casing was decided upon instead.
                    my $latest = get_latest_article($c,$obj->article_id);
                    if ($latest && $latest->status_id == 2 && $status != 2)
                    {
                        $latest->set_column('status_id',$status->status_id);
                        $latest->update();
                    }
                }
            }
            else
            {
                $c->log->error('Failed miserably when looking up status_id => '.$value);
                # FIXME: We need to handle this somehow
            }
        }
        elsif($fnam eq 'template_id')
        {
            # TODO: we should probably make sure the template exists
            my $template = $value eq 'undef' ? undef : $value;
            $obj->set_column('template_id',$template);
        }
        else
        {
            $obj->set_column($rfnam,$value);
        }
    }
    else
    {
        $obj->set_column($rfnam,$value);
    }
}

# TODO: These helpers should be provided elsewhere
sub isArray
{
    my $r = shift;
    if(not ref($r) eq 'ARRAY')
    {
        die('isArray got non-array: '.ref($r));
    }
}

sub isHash
{
    my $r = shift;
    if(not ref($r) eq 'HASH')
    {
        die('isArray got non-hash '.ref($r));
    }
}

1;
