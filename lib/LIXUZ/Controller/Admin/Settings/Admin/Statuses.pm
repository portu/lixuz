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

package LIXUZ::Controller::Admin::Settings::Admin::Statuses;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
BEGIN { extends 'Catalyst::Controller::FormBuilder' };
with 'LIXUZ::Role::List::Database';

use LIXUZ::HelperModules::Includes qw(add_jsIncl);
use LIXUZ::HelperModules::Forms qw(get_checkboxes);
use List::MoreUtils qw(any);

sub index : Path Args(0) Form('/core/search')
{
    my ( $self, $c ) = @_;
    my $fields = $c->model('LIXUZDB::LzStatus');
    my $obj = $self->handleListRequest({
            c => $c,
            object => $fields,
            objectName => 'status',
            template => 'adm/settings/admin/status_index.html',
            orderParams => [qw(status_id status_name)],
            paginate => 1,
        });
}

# Summary: Completely delete a status
sub delete : Local Args
{
    my ( $self, $c, $uid ) = @_;
    my @systemUIDs = (1,2,3,4);
    if(any { $uid == $_} @systemUIDs)
    {
        return $self->messageToList($c,$c->stash->{i18n}->get('Deleting system UIDs is not allowed'));
    }
    my $status = $c->model('LIXUZDB::LzStatus')->find({status_id => $uid});
    if (not $status)
    {
        return $self->messageToList($c,$c->stash->{i18n}->get('Status id did not exist.'));
    }
    my $aclEntry = $c->model('LIXUZDB::LzAction')->find({action_path => 'STATUSCHANGE_'.$status->status_id});
    if(not $aclEntry)
    {
        $c->log->warn('Failed to locate LzAction object for STATUSCHANGE_'.$status->status_id.' - ignoring and deleting the LzStatus anyway');
    }
    else
    {
        $aclEntry->delete();
    }
    $status->delete();
    return $self->messageToList($c,$c->stash->{i18n}->get('Status deleted.'));
}

# Summary: Forward the article to the list view, and display a status message at the top of it
# Usage: $self->messageToList($c, MESSAGE);
sub messageToList : Private
{
    my ($self, $c, $message) = @_;
    $c->flash->{ListMessage} = $message;
    $c->response->redirect('/admin/settings/admin/statuses');
    $c->detach();
}

sub edit : Local Args Form('/settings/edit_status')
{
    my ( $self, $c, $uid ) = @_;
    my @systemUIDs = (1,2,3,4);
    if(any { $uid == $_} @systemUIDs)
    {
        return $self->messageToList($c,$c->stash->{i18n}->get('Editing system UIDs is not allowed'));
    }
    my $form = $self->formbuilder;
    if ($form->submitted && $form->validate)
    {
        $self->savedata($c,$form);
        return $self->messageToList($c,$c->stash->{i18n}->get('Changes saved'));
    }
    my $status = $c->model('LIXUZDB::LzStatus')->find({status_id => $uid});
    if(not $status)
    {
        return $self->messageToList($c,$c->stash->{i18n}->get('Status id did not exist.'));
    }
    $form->field(
        name => 'status_name',
        value => $status->status_name($c->stash->{i18n}),
    );
    $form->field(
        name => 'uid',
        value => $status->status_id,
    );
    $c->stash->{template} = 'adm/settings/admin/statuses/edit.html';
}

sub add : Local Form('/settings/edit_status')
{
    my ( $self, $c ) = @_;
    my $form = $self->formbuilder;
    $form->submit([$c->stash->{i18n}->get('Create status')]);
    if ($form->submitted && $form->validate)
    {
        $self->savedata($c,$form);
        return $self->messageToList($c,$c->stash->{i18n}->get('Status created'));
    }
    $c->stash->{template} = 'adm/settings/admin/statuses/edit.html';
}

sub prepareform
{
    # We're creating a article
}

sub savedata : Private
{
    my ( $self, $c, $form ) = @_;
    my $i18n = $c->stash->{i18n};
    my $fields = $form->fields;
    my $uid = $fields->{'uid'};
    my $type = (defined $uid and length $uid) ? 'edit' : 'add';
    my $status;
    if ($type eq 'edit')
    {
        $status = $c->model('LIXUZDB::LzStatus')->find({status_id => $uid});
    }
    elsif($type eq 'add')
    {
        $status = $c->model('LIXUZDB::LzStatus')->create(
            {
            }
        );
        my $aclEntry = $c->model('LIXUZDB::LzAction')->create({action_path => 'STATUSCHANGE_'.$status->status_id});
        if(not $aclEntry)
        {
            $c->log->warn('Failed to create LzAction ACL entry for STATUSCHANGE_'.$status->status_id.' - still creating the status');
        }
    }
    else
    {
        return 1;
    }
    foreach my $field(qw(status_name))
    {
        if ($fields->{$field})
        {
            $status->set_column($field,$fields->{$field});
        }
    }
    $status->update();
    return 1;
}

1;
