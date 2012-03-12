package LIXUZ::Schema::LzAction;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';


=head1 NAME

LIXUZ::Schema::LzAction

=cut

__PACKAGE__->table("lz_action");

=head1 ACCESSORS

=head2 action_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 action_path

  data_type: 'varchar'
  is_nullable: 0
  size: 60

=cut

__PACKAGE__->add_columns(
  "action_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "action_path",
  { data_type => "varchar", is_nullable => 0, size => 60 },
);
__PACKAGE__->set_primary_key("action_id");


# Created by DBIx::Class::Schema::Loader v0.07002 @ 2011-01-17 10:17:20
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:lDuWMAJCa3QZt/NNJIS7ZQ

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
sub description
{
    my($self, $c) = @_;
    if(not $c)
    {
        die('$c missing as a parmeter to LzAction->description');
    }
    my $i18n = $c->stash->{i18n};
    my $description;
    my %pathsToActions = $self->getPathsHash($i18n);
    if ($description = $pathsToActions{$self->action_path})
    {
        return $description;
    }
    else
    {
        if ($self->action_path =~ /^STATUSCHANGE_/)
        {
            my $status = $self->action_path;
            $status =~ s/^STATUSCHANGE_//;
            $status = $c->model('LIXUZDB::LzStatus')->find({status_id => $status});
            if ($status)
            {
                $description = $i18n->get_advanced('Change status of an article to "%(STATUS)"',{STATUS => $status->status_name($i18n)});
                return $description;
            }
        }
        elsif($self->action_path =~ /^WORKFLOW_REASSIGN_TO_ROLE_/)
        {
            my $role = $self->action_path;
            $role =~ s/^WORKFLOW_REASSIGN_TO_ROLE_//;
            $role = $c->model('LIXUZDB::LzRole')->find({role_id => $role});
            if ($role)
            {
                $description = $i18n->get_advanced('Reassign an article to the role "%(ROLE)"',{ROLE => $role->role_name});
                return $description;
            }
        }
        $c->log->error('Failed to look up action name for: '.$self->action_path.' ('.$self->action_id.')');
        return $self->action_path;
    }
}

sub getPathsHash
{
    my($self,$i18n) = @_;
    my %pathsToActions = (
          '/articles' => 'View articles',
          '/articles/add' => 'Access the new article form',
          '/articles/json' => 'Access article data',
          '/articles/json/folderHandler' => 'Perform actions on folders',
          '/articles/json/ajaxHandler' => 'Perform essential tasks on articles they can edit',
          '/articles/trash' => 'Access the trash',
          '/articles/trash/move' => 'Move an article to trash',
          '/articles/trash/restore' => 'Restore an article from the trash',
          '/articles/trash/delete' => 'Delete an article from the trash',
          '/articles/edit' => 'Edit an article',
          '/articles/preview' => 'Preview articles',
          '/articles/submit' => 'Submit article data',
          '/articles/workflow' => 'View article workflow information',
          '/articles/workflow/acceptAssignment' => 'Accept assignments',
          '/articles/workflow/comments' => 'Retrieve comments without reloading the article',
          '/articles/workflow/submit' => 'Submit changes to the article workflow',
          '/articles/workflow/submitComment' => 'Submit comments on articles',
          '/articles/json/removeRelationship' => 'Remove relationships from an article',
          '/articles/JSON/addRelationship' => 'Add relationships to an article',
          '/articles/JSON/getTakenFileSpots' => 'Retrieve list of taken file spots',
          '/articles/JSON/assignFileToSpot' => 'Assign a file to a spot',
          '/articles/JSON/setFileCaption' => 'Set a file caption',
          '/articles/deleteComment' => 'Delete a comment from the live site',
          '/articles/getCommentListFor' => 'View a list of comments on the live site for articles',
          '/categories' => 'View categories',
          '/categories/add' => 'Add a new category',
          '/categories/delete' => 'Delete a category',
          '/categories/edit' => 'Edit a category',
          '/dashboard' => 'Access the dashboard',
          '/dictionary' => 'View the list of dictionary entries',
          '/dictionary/add' => 'Add a dictionary entry',
          '/dictionary/edit' => 'Edit a dictionary entry',
          '/dictionary/delete' => 'Delete a dictionary entry',
          '/services' => 'Access services (required for spellchecking)',
          '/services/multiRequest' => 'Retrieve multiple service replies in a single request',
          '/services/templateList' => 'Retrieve a list of templates',
          '/services/spellcheck' => 'Spellcheck articles',
          '/services/jsFilter' => 'Access filtering rules in lists',
          '/services/filesInArticle' => 'List files associated with articles',
          '/services/folderList' => 'Fetch the list of folders (required for files)',
          '/services/poll' => 'Server polling (required for auto-backup)',
          '/services/backup' => 'Access auto-backup functionality (create, list, restore)',
          '/services/elements' => 'Perform actions on elements (dictionary entries and so on) inside articles',
          '/services/templateInfo' => 'Retrieve template information',
          '/services/roleanduserlist' => 'Retrieve a list of all roles and users',
          '/services/permlist' => 'Retrieve a list of folder/object permissions for roles/users',
          '/services/setperm' => 'Set permissions on folders/objects for roles/users',
          '/services/deletefolder' => 'Delete folders',
          '/services/renamefolder' => 'Rename folders',
          '/files' => 'View files',
          '/files/imgedit' => 'Crop files',
          '/files/imgedit/resizer' => 'View preview of cropped files',
          '/files/imgedit/saveCrop' => 'Save cropped files',
          '/files/edit' => 'Edit files',
          '/files/upload' => 'Upload new files',
          '/files/upload/upload' => 'Upload new files',
          '/files/ajax' => 'Alter file data and move files',
          '/files/delete' => 'Delete files',
          '/files/edit/file_edit' => 'Edit normal files',
          '/files/edit/image_edit' => 'Edit images',
          '/files/get' => 'Retrieve files',
          '/files/classes' => 'Access file classes list',
          '/files/classes/add' => 'Add a file class',
          '/files/classes/edit' => 'Edit a file class',
          '/files/classes/delete' => 'Delete a file class',
          '/newsletter' => 'Access the newsletter list',
          '/newsletter/delete' => 'Delete newsletter subscriptions',
          '/newsletter/groupDelete' => 'Delete newsletter subscription groups',
          '/newsletter/groupInfo' => 'Retrieve information about newsletter subscription groups',
          '/newsletter/groupList' => 'Retrieve the list of newsletter subscription groups',
          '/newsletter/groupSave' => 'Edit or create newsletter subscription groups',
          '/newsletter/send' => 'Access the manual newsletter form',
          '/newsletter/submitManual' => 'Send manual newsletters',
          '/newsletter/subscriptionGroupEdit' => 'Add/remove people from newsletter subscription groups',
          '/newsletter/sentPreviously' => 'List newsletters that have been sent previously',
          '/rssimport' => 'Read and import data from RSS feeds',
          '/settings' => 'Access personal settings',
          '/settings/admin' => 'Access administrative settings',
          '/settings/admin/additionalfields' => 'View list of additional fields',,
          '/settings/admin/additionalfields/add' => 'Add a new additional field',
          '/settings/admin/additionalfields/fieldModuleUpdate' => 'Add or remove additional fields from a module',
          '/settings/admin/additionalfields/delete' => 'Delete a field',
          '/settings/admin/additionalfields/edit' => 'Edit contents of a field',
          '/settings/admin/additionalfields/fieldeditor' => 'Edit fields',
          '/settings/admin/additionalfields/submit' => 'Submit field information',
          '/settings/admin/server' => 'Edit server settings',
          '/settings/admin/statuses' => 'Edit available statuses',
          '/settings/admin/statuses/edit' => 'Edit existing statuses',
          '/settings/admin/statuses/delete' => 'Delete statuses',
          '/settings/admin/statuses/add' => 'Add new statuses',
          '/settings/user' => 'Edit their own personal settings',
          '/templates' => 'View templates',
          '/templates/add' => 'Add templates',
          '/templates/ajax' => 'Save template data',
          '/templates/assign' => 'Assign categories to a template',
          '/templates/delete' => 'Delete templates',
          '/templates/edit' => 'Edit templates',
          '/templates/upload' => 'Upload a new template',
          '/tags' => 'Tags support',
          '/tags/complete' => 'Autocomplete tags',
          '/tags/exists' => 'Check if a tag exists',
          '/tags/create' => 'Create a new tag',
          '/tags/delete' => 'Delete a tag',
          '/tags/edit' => 'Rename a tag',
          '/tags/list' => 'Manage tags',
          '/users' => 'View users',
          '/users/add' => 'Add a new user',
          '/users/delete' => 'Delete a user',
          '/users/edit' => 'Edit users',
          '/users/roles' => 'View roles',
          '/users/roles/add' => 'Add new roles',
          '/users/roles/delete' => 'Delete roles',
          '/users/roles/edit' => 'Edit roles',
          'TOGGLE_LIVECOMMENTS' => 'Enable/disable commenting on live articles',
          'SUPER_USER' => '<b>'.'Super user access. No restrictions'.'</b>',
          'WORKFLOW_CHANGE_DEADLINE' => 'Change the deadline of an article',
          'WORKFLOW_SETINITIAL_DEADLINE' => 'Set the initial deadline of an article',
          # The only one that needs to be labelled translatable
          'WORKFLOW_REASSIGN_TO_USER' => $i18n->get('Assign articles to users'),
          'WORKFLOW_REASSIGN_TO_ROLE' => 'Assign articles to roles',
          'EDIT_OTHER_ARTICLES' => 'Edit other peoples articles',
          'PREVIEW_OTHER_ARTICLES' => 'Preview other peoples articles',
          'COMMENT_PREVIEWED_ARTICLES' => 'Comment on previewed articles',
          'VIEW_OTHER_FILES' => 'View files owned by other users',
          'EDIT_OTHER_FILES' => 'Edit files owned by other users',
    );
    return %pathsToActions;
}

# You can replace this text with custom content, and it will be preserved on regeneration
1;


# You can replace this text with custom content, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
