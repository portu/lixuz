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

package LIXUZ::Controller::Admin::Users::Roles;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
BEGIN { extends 'Catalyst::Controller::FormBuilder' };
with 'LIXUZ::Role::List::Database';

use LIXUZ::HelperModules::Includes qw(add_jsIncl);
use LIXUZ::HelperModules::JSON qw(json_response json_error);

# Summary: Main index function for the roles interface
sub index : Path Args(0) Form('/core/search')
{
    my ( $self, $c, $query ) = @_;
    my $roles = $c->model('LIXUZDB::LzRole');
    $c->stash->{pageTitle} = $c->stash->{i18n}->get('Roles');
    $self->handleListRequest({
            c => $c,
            query => $query,
            object => $roles,
            objectName => 'roles',
            template => 'adm/users/roles/index.html',
            orderParams => [qw(role_id role_name role_status)],
            searchColumns => [qw(role_id role_name role_status)],
            paginate => 1,
        });
}

# Purpose: Forward the user to the list view, and display a status message at the top of it
# Usage: $self->messageToList($c, MESSAGE);
sub messageToList : Private
{
    my ($self, $c, $message) = @_;
    $c->flash->{roleListMessage} = $message;
    $c->response->redirect('/admin/users/roles');
    $c->detach();
}

# Summary: Save form data
# Usage: $self->savedata($c);
sub savedata : Private
{
    my ( $self, $c ) = @_;
    my $role;
    my $new = 0;
    if (defined $c->req->param('role_id'))
    {
        $role = $c->model('LIXUZDB::LzRole')->find({ role_id => $c->req->param('role_id')});
        if(not $role)
        {
            return json_error($c,'ROLENOTFOUND');
        }
    }
    else
    {
        $new = 1;
        $role = $c->model('LIXUZDB::LzRole')->create({ });
    }
    foreach my $field (qw(name status))
    {
        if ($c->req->param($field))
        {
            $role->set_column('role_'.$field,$c->req->param($field));
        }
    }
    # Update the DB
    $role->update();

    my $reRole = 0;

    my %allowed = map { $_  => 1 } split(',',$c->req->param('accessRights'));
    # Run through actions
    my $classes = $c->model('LIXUZDB::LzAction');
    while(my $action = $classes->next)
    {
        my $roleAction = $c->model('LIXUZDB::LzRoleAction')->find_or_create({action_id => $action->action_id, role_id => $role->role_id});
        if ($allowed{$action->action_path})
        {
            $roleAction->set_column('allowed',1);
            if ($action->action_path =~ /^WORKFLOW_REASSIGN_TO_ROLE/)
            {
                $reRole = 1;
            }
        }
        else
        {
            $roleAction->set_column('allowed',0);
        }
        $roleAction->update();
    }

    eval
    {
        my $actid = $c->model('LIXUZDB::LzAction')->find({action_path => 'WORKFLOW_REASSIGN_TO_ROLE'})->action_id;
        my $roleAction = $c->model('LIXUZDB::LzRoleAction')->find_or_create({action_id => $actid, role_id => $role->role_id});
        $roleAction->set_column('allowed',$reRole);
        $roleAction->update();
    };

    if($new)
    {
        my $aclEntry = $c->model('LIXUZDB::LzAction')->find_or_create({action_path => 'WORKFLOW_REASSIGN_TO_ROLE_'.$role->role_id});
        if(not $aclEntry)
        {
            $c->log->error('Failed to create WORKLFOW_REASSIGN_TO_ROLE_'.$role->role_id.' - role will still be created but stuff will not be working well');
        }
        else
        {
            $aclEntry->update();
        }
    }

    return json_response($c);
}

# Purpose: Handle creating a new role
sub add : Local
{
    my ( $self, $c, $uid ) = @_;
    if ($c->req->param('roles_submitted'))
    {
        return $self->savedata($c);
    }
    $self->buildform($c);
    $c->{stash}->{template} = 'adm/users/roles/edit/index.html';
}

# Purpose: Handle editing an existing role
sub edit : Local
{
    my ( $self, $c, $uid ) = @_;
    if ($c->req->param('roles_submitted'))
    {
        return $self->savedata($c);
    }
    my $i18n = $c->stash->{i18n};
    if (not defined $uid or $uid =~ /\D/)
    {
        $self->messageToList($c,$i18n->get('Error: Failed to locate UID. The path specified is invalid.'));
    }
    else
    {
        # Check if the role exists
        my $role = $c->model('LIXUZDB::LzRole')->find( {'role_id' => $uid} );
        if(not $role)
        {
            # Didn't exist, give up
            $self->messageToList($c,$i18n->get_advanced('Error: Failed to locate a role with the UID %(UID).', { UID => $uid }));
        }
        else
        {
            $self->buildform($c,$role);
        }
    }
    $c->{stash}->{template} = 'adm/users/roles/edit/index.html';
}

sub buildform : Private
{
    my ($self, $c, $role) = @_;

    my %hasAccessTo;
    if ($role and $role->actions)
    {
        my $actions = $role->actions;
        while(my $a = $actions->next)
        {
            if($a->action)
            {
                $hasAccessTo{$a->action->action_path} = $a->allowed;
            }
        }
        $c->stash->{role_id} = $role->role_id;
        $c->stash->{role_name} = $role->role_name;
        $c->stash->{role_status} = $role->role_status;
        $c->stash->{mode} = 'edit';
    }
    else
    {
        $c->stash->{mode} = 'add';
    }
    $c->stash->{hasAccessTo} = \%hasAccessTo;
    $c->stash->{groups} = $self->get_groups($c);
    add_jsIncl($c,'roles.js');
}

# Purpose: Delete a role
sub delete: Local
{
    my ( $self, $c, $uid ) = @_;
    my $i18n = $c->stash->{i18n};
    my $role;
    $c->stash->{template} = 'adm/core/dummy.html';
    if (not defined $uid or $uid =~ /\D/)
    {
        $self->messageToList($c,$i18n->get('Error: Failed to locate UID. The path specified is invalid.'));
    }
    else
    {
        $role = $c->model('LIXUZDB::LzRole')->find({role_id => $uid});
        if(not $role)
        {
            $c->log->error('Tried to delete nonexisting role: '.$uid);
        }
        else
        {
            # TODO: Maybe we should be using delete_all() ?
            $role->delete();
        }
        my $aclEntry = $c->model('LIXUZDB::LzAction')->find({ action_path => 'WORKFLOW_REASSIGN_TO_ROLE_'.$uid });
        if ($aclEntry)
        {
            if(not $role)
            {
                $c->log->error('Strangely though, the nonexisting role had an entry in the ACL list... Deleted.');
            }
            $aclEntry->delete();
        }
        $self->messageToList($c,$i18n->get('Role deleted'));
    }
}

sub get_groups : Private
{
    my($self,$c) = @_;
    my $i18n = $c->stash->{i18n};
    my %aclGroups = (
        $i18n->get('Super user (unrestricted access)') => {
            paths => [ 'SUPER_USER' ],
        },
        $i18n->get('Articles') => {
            paths => [ '/articles' ],
            $i18n->get('Add and edit articles') => {
                paths => [ 
                    '/articles/add',
                    '/articles/json',
                    '/articles/json/folderHandler',
                    '/articles/json/ajaxHandler',
                    '/articles/edit',
                    '/articles/submit',
                    '/articles/workflow',
                    '/articles/workflow/acceptAssignment',
                    '/articles/workflow/comments',
                    '/articles/workflow/submit',
                    '/articles/workflow/submitComment',
                    '/articles/json/removeRelationship',
                    '/articles/JSON/addRelationship',
                    '/articles/deleteComment',
                    '/articles/getCommentListFor',
                    '/articles/JSON/assignFileToSpot',
                    '/articles/JSON/setFileCaption',
                    '/services/elements',
                    '/services/poll',
                    '/services/backup',
                    '/services/templateInfo',
                    '/services/templateList',
                    '/articles/JSON/getTakenFileSpots',
                    'TOGGLE_LIVECOMMENTS',
                    ],
            },
            $i18n->get('Set/change deadline') => {
                paths => [
                    'WORKFLOW_CHANGE_DEADLINE',
                    'WORKFLOW_SETINITIAL_DEADLINE',
                ],
            },
            $i18n->get('Edit other users articles') => {
                paths => [
                    'EDIT_OTHER_ARTICLES',
                ],
            },
            $i18n->get('Preview and read own articles') => {
                paths => [ 
                    '/articles/preview',
                    '/articles/read'
                ],
            },
            $i18n->get('Preview others articles') => {
                paths => [ 
                    'PREVIEW_OTHER_ARTICLES',
                    'COMMENT_PREVIEWED_ARTICLES',
                ],
            },
            $i18n->get('Move articles to the trash') => {
                paths => [
                    '/articles/trash',
                    '/articles/trash/move',
                ],
            },
            $i18n->get('Delete trashed articles') => {
                paths => [
                    '/articles/trash',
                    '/articles/trash/delete',
                ],
            },
            $i18n->get('Restore trashed articles') => {
                paths => [
                    '/articles/trash',
                    '/articles/trash/restore',
                ],
            },
        },
        $i18n->get('Manage categories') => {
            paths => [ 
                '/categories',
                '/categories/add',
                '/categories/delete',
                '/categories/edit',
                ],
        },
        $i18n->get('Access the dashboard') => {
            paths => [ '/dashboard' ],
        },
        $i18n->get('Access dictionaries') => {
            paths => [ '/dictionary' ],
            $i18n->get('Add/remove dictionary entries') => {
                paths => [
                    '/dictionary/add',
                    '/dictionary/edit',
                    '/dictionary/delete'
                ],
            },
        },
        $i18n->get('Access essential Lixuz services') => {
            paths => [
                '/services',
                '/services/jsFilter',
                '/services/filesInArticle',
                '/services/folderList',
                '/services/elements',
                '/services/multiRequest',
                '/services/roleanduserlist',
            ],
        },

        $i18n->get('Edit permissions on folders') => {
            paths => [
            '/services/roleanduserlist',
            '/services/permlist',
            ],
        },
        $i18n->get('Delete folders') => {
            paths => [
                '/services/deletefolder'
            ]
        },
        $i18n->get('Rename folders') => {
            paths => [
                '/services/renamefolder'
            ]
        },
        $i18n->get('Files') => {
            paths => [ 
                '/files',
                '/files/get',
                ],
            $i18n->get('Upload or edit files') => {
                paths => [ 
                '/files/edit',
                '/files/upload',
                '/files/upload/upload',
                '/files/ajax',
                '/files/edit/file_edit',
                '/files/edit/image_edit',
                ],
            },
            $i18n->get('Delete files') => {
                paths => [
                    '/files/delete',
                    ],
            },
            $i18n->get('Crop images') => {
                paths => [
                '/files/imgedit',
                '/files/imgedit/resizer',
                '/files/imgedit/saveCrop'
                ],
            },
            $i18n->get('View other users files') => {
                paths => [ 'VIEW_OTHER_FILES' ],
            },
            $i18n->get('Edit other users files') => {
                paths => [ 'EDIT_OTHER_FILES' ],
            },
            $i18n->get('Manage file classes') => {
                paths => [
                    '/files/classes',
                    '/files/classes/edit',
                    '/files/classes/add',
                    '/files/classes/delete',
                ],
            },
        },
        $i18n->get('Newsletter') => {
            paths => [
                '/newsletter',
            ],
            $i18n->get('Send, delete and edit') => {
                paths => [
                    '/newsletter/delete',
                    '/newsletter/groupDelete',
                    '/newsletter/groupInfo',
                    '/newsletter/groupList',
                    '/newsletter/groupSave',
                    '/newsletter/send',
                    '/newsletter/submitManual',
                    '/newsletter/subscriptionGroupEdit',
                    '/newsletter/sentPreviously',
                    '/newsletter/subscriberInfo',
                ],
            },
        },
        #ACL for Time entry (Time Tracker)
        $i18n->get('Access the time entry') => {
            paths => [
                '/timetracker',
            ],
            
            $i18n->get('Add and edit time entry') => {
                paths => [
                    '/timetracker/entrySave',
                    '/timetracker/timeentryInfo',
                    '/timetracker/commentlist',
                ],
            },
            $i18n->get('Delete others time entry') => {
                paths => [
                    'DELETE_OTHERS_TIME_ENTRY',
                ],
            },
            $i18n->get('Add comments on others time entry') => {
                paths => [
                    'COMMENT_ON_TIME_ENTRY',                  
                ],
            },   
            $i18n->get('View others time entry') => {
                paths => [
                    'VIEW_OTHERS_TIME_ENTRY',
                ],
            },
            $i18n->get('Generate time entry report') => {
                paths => [
                    '/timetracker/generate_report',                  
                ],
            },   
        },
        $i18n->get('Access tags') => {
            paths => [ '/tags',
                       '/tags/complete',
                       '/tags/exists',
                       ],
            $i18n->get('Create new tags') => {
                paths => [ '/tags/create' ],
                $i18n->get('Manage tags') => {
                    paths => [ '/tags/list', '/tags/delete', '/tags/edit' ],
                },
            },
        },
        $i18n->get('RSSImport') => {
            paths => [ '/rssimport' ],
        },
        $i18n->get('Administrative settings') => {
            paths => [ 
                '/settings',
                '/settings/admin',
                '/settings/admin/server',
                '/settings/user',
                ],
            $i18n->get('Edit additional fields') => {
                paths => [
                    '/settings/admin/additionalfields',
                    '/settings/admin/additionalfields/add',
                    '/settings/admin/additionalfields/fieldModuleUpdate',
                    '/settings/admin/additionalfields/delete',
                    '/settings/admin/additionalfields/edit',
                    '/settings/admin/additionalfields/fieldeditor',
                    '/settings/admin/additionalfields/submit',
                ],
            },
            $i18n->get('Edit statuses') => {
                paths => [
                    '/settings/admin/statuses',
                    '/settings/admin/statuses/edit',
                    '/settings/admin/statuses/delete',
                    '/settings/admin/statuses/add',
                ],
            },
            $i18n->get('Manage users') => {
                paths => [
                    '/users',
                    '/users/add',
                    '/users/delete',
                    '/users/edit',
                ],
                $i18n->get('Manage roles') => {
                    paths => [
                        '/users/roles',
                        '/users/roles/add',
                        '/users/roles/delete',
                        '/users/roles/edit',
                    ],
                },
            },
        },
        $i18n->get('Manage templates') => {
            paths => [
                '/templates',
                '/templates/add',
                '/templates/ajax',
                '/templates/assign',
                '/templates/delete',
                '/templates/edit',
                '/templates/upload',
                ],
        },
    );
    my $customActions = $c->model('LIXUZDB::LzAction')->search({
            -or => [
            {
                action_path => 
                {
                    -like => '%WORKFLOW_REASSIGN_TO_ROLE%',
                }
            },
            {
                action_path => 
                {
                    -like => '%STATUSCHANGE%',
                }
            },
            {
                action_path => 
                {
                    -like => '%WORKFLOW_REASSIGN_TO_USER%',
                }
            }
            ],

        });
    if ($customActions && $customActions > 0)
    {
        while(my $action = $customActions->next)
        {
            if (not $action->action_path eq 'WORKFLOW_REASSIGN_TO_ROLE')
            {
                $aclGroups{$i18n->get('Articles')}->{$action->description($c)} = { paths => [ $action->action_path ] };
            }
        }
    }
    return \%aclGroups;
}
1;
