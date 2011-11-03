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

package LIXUZ::Controller::Admin::Articles::Workflow;

use strict;
use warnings;
use base 'Catalyst::Controller';
use LIXUZ::HelperModules::JSON qw(json_response json_error);
use LIXUZ::HelperModules::Calendar qw(create_calendar datetime_to_SQL datetime_from_SQL);
use LIXUZ::HelperModules::Includes qw(add_jsIncl);
use LIXUZ::HelperModules::Forms qw(select_options_manually);
use LIXUZ::HelperModules::EMail qw(send_email_to);
use LIXUZ::HelperModules::RevisionHelpers qw(article_latest_revisions get_latest_article);
use List::MoreUtils qw(any);
use constant { true => 1, false => 0};

# Summary: Accept an assignment
# Arg: UID of article
sub acceptAssignment : Local Arg
{
    my ($self, $c, $artid) = @_;
    my $article = get_latest_article($c,$artid);
    if(not $article)
    {
        return json_error($c,'INVALIDARTID');
    }
    my $workflow = $article->workflow;
    $self->prepare($c,undef,$workflow);
    if (not $c->stash->{w_can_accept} and not $c->user->can_access('SUPER_USER'))
    {
        return json_error($c,'DENIED');
    }

    $workflow->set_column('assigned_to_user',$c->user->user_id);
    $workflow->set_column('assigned_to_role',undef);
    $workflow->update();
    return json_response($c,{ accepted => 1});
}

# Summary: Check if the current user is allowed to modify the article associated
#   with a workflow
# Usage: bool = obj->can_write($c,$workflow?, $article?);
# $workflow is the workflow object to check, can be undef
# $article is the article object whose workflow object we want, can also be undef
#   if both article and workflow is undef, this will always return true
#   if both article and workflow is supplied then article will be ignored
sub can_write
{
    my ($self, $c, $workflow, $article) = @_;
    # A super user can do anything she likes
    if ($c->user->can_access('SUPER_USER'))
    {
        return 1;
    }
    # If we've got an article, but not a workflow, use that
    if ($article && ! $workflow)
    {
        $workflow = $article->workflow;
    }
    if (not $workflow)
    {
        my $artid = 'unknown';
        eval
        {
            $artid = $article->article_id;
        };
        $c->log->debug('no workflow at the end of can_write() in Workflow.pm for article id '.$artid.' - just returning 1');
        return 1;
    }
    return $workflow->can_write($c);
}

# Summary: Checks if the user can write to the supplied workflow/article,
#   errors out if not
# Usage: same as can_write()
#
# This method will only return if access was granted.
sub writecheck
{
    my($self,$c,$workflow,$article) = @_;
    if (not $self->can_write($c,$workflow,$article))
    {
        $c->user->access_denied();
        return;
    }
    return 1;
}


# Summary: Process a new comment submission
sub submitComment : Local
{
    my ( $self, $c ) = @_;
	my $body = $c->req->param('body');
	my $artid = $c->req->param('artid');
	my $subject = $c->req->param('subject');
	if(not defined $body)
	{
		return json_error($c,'PARAM_MISSING','body');
	}
	elsif(not defined $subject)
	{
		return json_error($c,'PARAM_MISSING','subject');
	}
	elsif(not defined $artid)
	{
		return json_error($c,'PARAM_MISSING','artid');
	}
    my $revision = $c->req->param('revision');
    my $article;
    if (defined $revision)
    {
        $article = $c->model('LIXUZDB::LzArticle')->find({article_id => $artid, revision => $revision});
    }
    else
    {
        $article = get_latest_article($c,$artid);
        $revision = $article->revision;
    }
	if(not $article)
	{
		return json_error($c,'ARTICLE_MISSING');
	}
    if(not $self->can_write($c,undef,$article) and not $c->user->can_access('COMMENT_PREVIEWED_ARTICLES'))
    {
        $c->user->access_denied();
    }

	my $comment = $c->model('LIXUZDB::LzWorkflowComments')->create({
			article_id => $article->article_id,
			comment_subject => $subject,
			comment_body => $body,
			written_time => \'NOW()',
			user_id => $c->user->user_id,
            on_revision => $revision,
		});
	$comment->update();
    $self->notifyAboutComment($c,$artid,$comment);
	return json_response($c,{});
}

# Summary: Get the list of comments
sub comments : Local Arg
{
	# FIXME: We don't do any error handling whatsoever
    my ( $self, $c, $uid) = @_;
	my $article = $c->model('LIXUZDB::LzArticle')->search({article_id => $uid})->first();
	$self->preparePage($c,$article);
	$c->stash->{template} = 'adm/articles/workflow_comments.html';
	$c->stash->{displaySite} = 0;
}

# Summary: Prepare the main workflow page for output
sub preparePage : Private
{
	my ( $self, $c, $article ) = @_;
	if ($article)
	{
        my $comments = $c->model('LIXUZDB::LzWorkflowComments')->search({ article_id => $article->article_id }, { order_by => 'written_time' });
        my $workflow = $article->workflow;
		$self->prepare($c,$article,$workflow,$comments);
	}
    else
    {
        $self->prepare($c);
    }
    my $canSetDeadline = $article ? $c->user->can_access('WORKFLOW_SETINITIAL_DEADLINE') : $c->user->can_access('WORKFLOW_CHANGE_DEADLINE');
    if ($canSetDeadline)
    {
        $c->stash->{w_deadlineInput} = create_calendar($c,'workflow_deadline', { value => $c->stash->{w_deadline} });
    }
    else
    {
        if ($article && $article->workflow && $article->workflow->deadline)
        {
            $c->stash->{w_deadlineInput} = datetime_from_SQL($article->workflow->deadline);
        }
        else
        {
            $c->stash->{w_deadlineInput} = $c->stash->{i18n}->get('(you do not have permission to set this value)');
        }
    }
	$c->stash->{w_startdateInput} = create_calendar($c,'workflow_startdate', { value => $c->stash->{w_startdate} });
}

# Summary: Prepare useful values and stash them for use either by the template or JSON code.
sub prepare : Private
{
    my ( $self, $c, $article, $workflow, $comments) = @_;
    my $i18n = $c->stash->{i18n};
	if ($comments)
	{
		$c->stash->{w_comments} = $comments;
	}
    # Fetch population data from workflow object if present
	if ($workflow)
	{
		$c->stash->{w_priority} = $workflow->priority;
		# TODO: The schemas should probably do the conversion themselves
		$c->stash->{w_deadline} = datetime_from_SQL($workflow->deadline);
		$c->stash->{w_startdate} = datetime_from_SQL($workflow->start_date);
        if ($article)
        {
            $c->stash->{w_watched} = $c->model('LIXUZDB::LzArticleWatch')->find({ user_id => $c->stash->{user_id}, article_id => $article->article_id});
        }
        # Make sure that it is not assigned to both a user and a role.
        if ($workflow->assigned_to_user and $workflow->assigned_to_role)
        {
            $c->log->warn("Article is assigned to both a user and a role, deleting role assignment");
            $workflow->set_column('assigned_to_role',undef);
            $workflow->update();
        }

        # Fetch information into w_assigned_to
        if ($workflow->assigned_to_role)
        {
            my $role = $c->model('LIXUZDB::LzRole')->find({role_id => $workflow->assigned_to_role});
            if ($role)
            {
                $c->stash->{w_assigned_to} = $role->role_name.' '.$i18n->get('(role)'); 
            }
            else
            {
                $c->log->error('Article is assigned to a nonexisting role');
            }
        }
        elsif($workflow->assigned_to_user)
        { 
            my $user = $c->model('LIXUZDB::LzUser')->find({user_id => $workflow->assigned_to_user});
            if ($user)
            {
                $c->stash->{w_assigned_to} = $user->firstname.' '.$user->lastname;
            }
            else
            {
                $c->log->error('Article is assigned to a nonexisting user');
            }
        }
        if(not $c->stash->{w_assigned_to})
        {
            $c->stash->{w_assigned_to} = $i18n->get('(nobody)');
        }

        # Find the user it is assigned by
        my $assigned_by = $workflow->assigned_by;
        if(not defined $assigned_by)
        {
            $assigned_by = $c->user->user_id;
        }
        if (defined $assigned_by and my $user = $c->model('LIXUZDB::LzUser')->find({user_id => $assigned_by}))
        {
            $c->stash->{w_assigned_by} = $user->firstname.' '.$user->lastname;
        }
        else
        {
            $c->stash->{w_assigned_by} = $i18n->get('(nobody)');
        }
        # Check if the user can reassign
        if ((defined $assigned_by && $assigned_by == $c->user->user_id) || (defined $workflow->assigned_to_user && $workflow->assigned_to_user == $c->user->user_id) || $c->user->can_access('SUPER_USER'))
        {
            $c->stash->{w_can_reassign} = 1;
            my $ACL = $c->user;
            if ($ACL->can_access('WORKFLOW_REASSIGN_TO_ROLE'))
            {
                $c->stash->{w_assignRoleString} = $i18n->get('Reassign to role');
                $c->stash->{w_can_reassign_toRole} = 1;
            }
            if ($ACL->can_access('WORKFLOW_REASSIGN_TO_USER'))
            {
                $c->stash->{w_assignUserString} = $i18n->get('Reassign to user');
                $c->stash->{w_can_reassign_toUser} = 1;
            }
        }
        else
        {
            $c->stash->{w_can_reassign} = 0;
            if (defined($workflow->assigned_to_role) and $workflow->assigned_to_role == $c->user->role_id)
            {
                $c->stash->{w_can_accept} = 1;
            }
            else
            {
                $c->stash->{w_can_accept} = 0;
            }
        }
	}
    else
    {
        # We are creating a new one, so set some defaults
        $c->stash->{w_assigned_by} = $c->user->firstname.' '.$c->user->lastname;
        $c->stash->{w_assigned_to} = $i18n->get('(nobody)');
        $c->stash->{w_can_reassign} = 1;
        if ($c->user->can_access('WORKFLOW_REASSIGN_TO_ROLE'))
        {
            $c->stash->{w_assignRoleString} = $i18n->get('Assign to role');
            $c->stash->{w_can_reassign_toRole} = 1;
        }
        if ($c->user->can_access('WORKFLOW_REASSIGN_TO_USER'))
        {
            $c->stash->{w_assignUserString} = $i18n->get('Assign to user');
            $c->stash->{w_can_reassign_toUser} = 1;
        }
    }
    # Populate some variables needed if the user can reassign
    if ($c->stash->{w_can_reassign})
    {
        my @users = ({ value => 'null', name => $i18n->get('-select-'), selected => 1});
        my @roles = ({ value => 'null', name => $i18n->get('-select-'), selected => 1});

        my $roleList = $c->model('LIXUZDB::LzRole');
        while(my $role = $roleList->next)
        {
            next if not $role->is_active or not $c->user->can_access('WORKFLOW_REASSIGN_TO_ROLE_'.$role->role_id);
            push(@roles,{
                    value => $role->role_id,
                    name => $role->role_name,
                });
        }
        if (@roles)
        {
            $c->stash->{w_roleOptions} = select_options_manually(\@roles);

            my $userList = $c->model('LIXUZDB::LzUser');
            while(my $user = $userList->next)
            {
                next if not $user->is_active;
                push(@users,{
                        value => $user->user_id,
                        name => $user->user_name,
                    });
            }
            $c->stash->{w_userOptions} = select_options_manually(\@users);
        }
        else
        {
            $c->stash->{w_can_reassign} = 0;
        }
    }
    if ($article)
    {
    	$c->stash->{artid} = $article->article_id;
    }
}

# Summary: Generate and send e-mails to people when reassigning to roles
# Usage: self->notifyRoleMembers($c,$article,$role);
sub notifyRoleMembers
{
    my($self,$c,$workflow,$role) = @_;
    my $article = $workflow->article;
    my $i18n = $c->stash->{i18n};
    my $subject = $i18n->get_advanced('A new article (%(ARTICLE_NAME) (%(ARTICLE_ID)) is available',{ ARTICLE_NAME => $article->title, ARTICLE_ID => $article->article_id});
    my $message = $i18n->get_advanced("An article has just been reassigned to the role that you belong to.\n\nYou may accept this assignment on its page, %(PAGE),\nor your Lixuz dashboard.",{PAGE => $c->uri_for('/admin/edit/'.$article->article_id) });
    my $users = $role->users;
    my @recipients;
    while(my $user = $users->next)
    {
        # Don't send an e-mail to the user that triggered this change.
        if ($c->user->user_id == $user->user_id)
        {
            next;
        }

        push(@recipients,$user->firstname.' '.$user->lastname.' <'. $user->email.'>');
    }
    if (@recipients)
    {
        send_email_to($c,undef, $subject, $message, @recipients);
    }
}

sub notifyAboutComment
{
    my ($self, $c, $artid, $comment) = @_;
    my $i18n = $c->stash->{i18n};
    my $article = $c->model('LIXUZDB::LzArticle')->find({article_id => $artid},{columns => ['title'], prefetch => [ 'workflow' ]});
    my $workflow = $article->workflow;
    my $watchers = $c->model('LIXUZDB::LzArticleWatch')->search({ article_id => $artid },{prefetch => ['user']});
    my $subject = $i18n->get_advanced('%(FIRSTNAME) %(LASTNAME) (%(USERNAME)) commented on the article %(ARTID) (%(ARTICLE_TITLE))',{
            ARTID => $artid,
            ARTICLE_TITLE => $article->title,
            FIRSTNAME => $c->user->firstname,
            LASTNAME => $c->user->lastname,
            USERNAME => $c->user->user_name
        });
    my $message = $i18n->get_advanced("%(SUBJECT) by %(FIRSTNAME) %(LASTNAME) (%(USERNAME)):\n%(BODY)",{
            ARTICLE_ID => $artid,
            SUBJECT => $comment->comment_subject,
            BODY => $comment->comment_body,
            FIRSTNAME => $c->user->firstname,
            LASTNAME => $c->user->lastname,
            USERNAME => $c->user->user_name
        });
    my $autoMessage = $i18n->get("This message has been automatically generated by Lixuz because you\nare either watching this article, or you are the assignee.\n");

    my @recipients;
    my $assignee;
    if ($workflow->assigned_to_user)
    {
        $assignee = $workflow->assigned_to_user;
    }
    while(my $watcher = $watchers->next)
    {
        # Don't send an e-mail to the user that triggered this change,
        # and if the assignee is also watching (which I guess is likely) we don't add her
        # to the recipients list, she will be added later anyway.
        if ($c->user->user_id == $watcher->user->user_id || (defined $assignee && $assignee == $watcher->user->user_id))
        {
            next;
        }

        push(@recipients,$watcher->user->firstname.' '.$watcher->user->lastname.' <'. $watcher->user->email.'>');
    }
    if(($workflow->user) && (not $workflow->user->user_id == $c->user->user_id))
    {
        push(@recipients,$workflow->user->firstname.' '.$workflow->user->lastname.' <'. $workflow->user->email.'>');
    }

    if (@recipients)
    {
        send_email_to($c, $autoMessage,$subject,$message,@recipients);
    }
}

1;
