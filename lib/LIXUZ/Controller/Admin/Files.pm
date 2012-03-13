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

package LIXUZ::Controller::Admin::Files;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
BEGIN { extends 'Catalyst::Controller::FormBuilder' };
with 'LIXUZ::Role::List::Dual';

use LIXUZ::HelperModules::Lists qw(reply_json_list);
use LIXUZ::HelperModules::Includes qw(add_jsIncl add_cssIncl add_jsOnLoad);
use LIXUZ::HelperModules::Search;
use constant { true => 1, false => 0 };

# Summary: Show the primary list
sub index : Path Args(0) Form('/core/search')
{
    my ( $self, $c, $query ) = @_;
    my $file = $self->getParamFileObj($c);
    # Order the files by default
    if(not $c->req->param('orderby'))
    {
        $c->req->params->{orderby} = 'file_id';
        $c->req->params->{ordertype} = 'DESC';
    }

    if ($c->req->param('childOf'))
    {
        $file = $file->search({ clone => $c->req->param('childOf') });
        $c->stash->{childOf} = $c->req->param('childOf');
    }
    else
    {
        $file = $file->search({ clone => \'IS NULL' });
    }

    my $obj = $self->handleListRequest({
            c => $c,
            query => $query,
            object => $file,
            objectName => 'file',
            template => 'adm/files/index.html',
            orderParams => [qw(file_id file_name template_id parent external_link display_type_id file_status)],
            searchColumns => [ qw/file_id file_name title caption/ ],
            advancedSearch =>[ qw(status owner) ],
            paginate => 1,
        });
    if ($c->req->param('_JSON_Submit'))
    {
        if ($c->req->param('list_type') && $c->req->param('list_type') eq 'pure')
        {
            return reply_json_list($c,$obj, \&formatFileJSON_PureIconItem,'CODE_ARRAY');
        }
        else
        {
            return reply_json_list($c,$obj, \&formatFileJSON,'SINGLE');
        }
    }
    else
    {
        # Create drag and drop
        my $dnd = LIXUZ::HelperModules::DragDrop->new($c,'LIXUZDB::LzFolder','/admin/files/ajax/',
            {
                name => 'folder_name',
                uid => 'folder_id',
            },
            {
                immutable => 1, # FIXME: Drop
                onclick => 'folderLimit',
            },
        );
        $c->stash->{dragdrop} = $dnd->get_html();
        add_jsIncl($c,$dnd->get_jsfiles());
        add_jsIncl($c,'utils.js','files.js');
        add_cssIncl($c,$dnd->get_cssfiles());
        #add_jsOnLoad($c,@{$dnd->get_onload()}); # FIXME
        $c->stash->{pageTitle} = $c->stash->{i18n}->get('Files');
        $self->init_searchFilters($c);
    }
}

sub init_searchFilters : Private
{
    my ( $self, $c ) = @_;

    my $i18n = $c->stash->{i18n};
    my $userOptions = [];
    my $users = $c->model('LIXUZDB::LzUser');
    while(my $user = $users->next)
    {
        push(@{$userOptions}, {
                value => $user->user_id,
                label => $user->user_name,
            });
    }
    my $statusOptions = [
        {
            value => 'Active',
            label => $i18n->get('Active'),
        },
        {
            value => 'Inactive',
            label => $i18n->get('Inactive'),
        },
    ];
    $c->stash->{searchFilters} = [
        {
            name => $i18n->get('Uploaded by'),
            realname => 'owner',
            options => $userOptions,
            selected => defined $c->req->param('filter_owner') ? $c->req->param('filter_owner') : undef,
            anyString => $i18n->get('(anyone)'),
        },
        {
            name => $i18n->get('Status'),
            realname => 'status',
            options => $statusOptions,
            selected => defined $c->req->param('filter_status') ? $c->req->param('filter_status') : undef,
        },
    ];
}

# Summary: Handle input from ajax
sub ajax: Local
{
    my ($self, $c) = @_;
    $c->stash->{template} = 'adm/core/dummy.html';
    # Create drag and drop
    my $dnd = LIXUZ::HelperModules::DragDrop->new($c,'LIXUZDB::LzFolder','/admin/files/ajax/',
        {
            name => 'folder_name',
            uid => 'folder_id',
        },
        {
            immutable => 1, # FIXME: Drop
            objClass => 'LzFile',
            objColumn => 'file_id',
        },
    );
    $c->stash->{content} = $dnd->handleInput();
    $c->stash->{displaySite} = 0;
}

# Summary: Forward the file to the list view, and display a status message at the top of it
# Usage: $self->messageToList($c, MESSAGE);
sub messageToList
{
    my ($self, $c, $message) = @_;
    $c->flash->{ListMessage} = $message;
    $c->response->redirect('/admin/files');
    $c->detach();
}

# Summary: Delete a file
sub delete: Local Args
{
    my ( $self, $c, $uid ) = @_;
    my $i18n = $c->stash->{i18n};
    my $file;
    # If we don't have an UID then just give up
    if (not defined $uid or $uid =~ /\D/)
    {
        $self->messageToList($c,$i18n->get('Error: Failed to locate UID. The path specified is invalid.'));
    }
    else
    {
        $file = $c->model('LIXUZDB::LzFile')->find({file_id => $uid});
        my $articleFiles = $file->articles;
        while((defined $articleFiles) && (my $af = $file->next))
        {
            $af->delete();
        }
        $file->removeAndDelete($c);
        $self->messageToList($c,$i18n->get('File deleted'));
    }
}

# Summary: Get a file object with parameters depending on childOf
sub getParamFileObj : Private
{
    my ($self,$c) = @_;
    my $file = $c->model('LIXUZDB::LzFile');
    if ($c->req->param('childOf'))
    {
        $file = $file->search({ clone => $c->req->param('childOf') });
        $c->stash->{childOf} = $c->req->param('childOf');
    }
    else
    {
        $file = $file->search({ clone => \'IS NULL' });
    }
    # If we can't edit other peoples articles, *and* we can't preview
    # other peoples articles then limit the results
    if(not $c->user->can_access('EDIT_OTHER_FILES') and not $c->user->can_access('VIEW_OTHER_FILES'))
    {
        $file = $file->search({ owner => $c->user->user_id });
    }
    return $file;
}

# XXX: This is about as far from JSON as one gets

sub formatFileJSON
{
    my($c, $files) = @_;
    my $n = 0;
    my $perLine = 3;
    my $html;
    my $clickAction = 'LZ_OS_ObjectClicked';
    while((defined $files) and (my $file = $files->next))
    {
        next if not $file->can_read($c);
        if ($n++ >= $perLine)
        {
            $html .='</tr><tr>';
            $n = 1;
        }
        $html .= '<td><center>';
        if ($clickAction)
        {
            $html .= '<a href="#" style="text-decoration: none;" onclick="'.$clickAction.'('.$file->file_id.'); return false;">';
        }
        $html .= $file->get_iconItem($c);
        if ($clickAction)
        {
            $html .= '</a>';
        }
        $html .= '</center></td>';
    }
    return $html;
}

sub formatFileJSON_PureIconItem
{
    my($c, $file) = @_;
    return if not $file->can_read($c);
    return [ $file->file_id, $file->get_iconItemTable($c,true)];
}

1;
