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

package LIXUZ::Controller::Admin::Dashboard;

use strict;
use warnings;
use base 'Catalyst::Controller';
use LIXUZ::HelperModules::RevisionHelpers qw(article_latest_revisions);
use LIXUZ::HelperModules::Includes qw(add_jsIncl add_jsOnLoad);
use LIXUZ::HelperModules::Widget;

# Summary: Handle the request
sub index : Private
{
    my ( $self, $c ) = @_;
    #my $cont = 'Hi, '.$c->user->get('firstname').' '.$c->user->get('lastname');
    #  $cont .= '<br /><a href="/logout">Log out</a>';
    $self->prepareMyAssignments($c);
    $self->prepareAvailableAssignments($c);
    $self->prepareRecentComments($c);
    foreach my $status(1..2)
    {
        $self->prepareArticlesInStatus($c,$status);
    }
    $c->stash->{template} = 'adm/dashboard/main.html';
    $c->stash->{pageTitle} = $c->stash->{i18n}->get('Dashboard');
    add_jsIncl($c,'dashboard.js');

    #$c->stash->{content} = $cont;

    # If there's a ListMessage in the flash, fetch it and stash it
    if ($c->flash->{'ListMessage'})
    {
        if ($c->flash->{'ListMessage'} eq 'USER_DATA_SAVED')
        {
            $c->stash->{message} = $c->stash->{i18n}->get('User data saved');
        }
        else
        {
            $c->stash->{message} = $c->flash->{'ListMessage'};
        }
    }
}

# Summary: Prepare any data required for the "my assignments" widget
sub prepareMyAssignments : Private
{
    my ( $self, $c ) = @_;
    my $widget = LIXUZ::HelperModules::Widget->new($c,'MyAssignments');
    my $ignore = $widget->get_config_or('excludeStatusIds','2');
    my $results = $widget->get_config_or('rows',30);
    my @ignoredStatuses = split(',',$ignore);
    my @finalIgnore;
    while(my $status = shift(@ignoredStatuses))
    {
        push(@finalIgnore,{ status_id => { '!=' => $status } });
    }
    my $assignments;
    if ($assignments = $c->model('LIXUZDB::LzWorkflow')->search({'me.assigned_to_user' => $c->user->user_id, 'article.trashed' => { '!=' => '1' }}))
    {
        $assignments = $assignments->search_related('article',{ -and => \@finalIgnore }, { order_by => 'modified_time DESC' });
    }
    $c->stash->{dashboard_MyAssignments} = article_latest_revisions($assignments);
}

# Summary: Prepare any data required for the "available assignments" widget
sub prepareAvailableAssignments : Private
{
    my ( $self, $c ) = @_;
    my $assignments = $c->model('LIXUZDB::LzWorkflow')->search({assigned_to_role => $c->user->role->role_id, assigned_by => { '!=',$c->user->user_id}}, { rows => 30, order_by => 'deadline,start_date DESC'});
    $assignments = article_latest_revisions($assignments->search_related('article'));
    $c->stash->{dashboard_AvailableAssignments} = $assignments;
}

# Summary: Fetch lists of articles that are in the status specified
sub prepareArticlesInStatus : Private
{
    my ( $self, $c, $status ) = @_;
    my $status_obj = $c->model('LIXUZDB::LzStatus')->find({status_id => $status});
    my $articles = $status_obj->articles->search({ 'me.trashed' => { '!=' => '1' }},{ order_by => 'modified_time DESC', rows => 30 });
    if (not $c->user->can_access('EDIT_OTHER_ARTICLES') and not $c->user->can_access('PREVIEW_OTHER_ARTICLES'))
    {
        if($articles = $articles->search_related('workflow',{ '-or' => [{'workflow.assigned_to_user' => $c->user->user_id}, {'workflow.assigned_to_role' => $c->user->role->role_id}]}))
        {
            $articles = $articles->search_related('article');
        }
    }
    $articles = article_latest_revisions($articles);
    $articles = $articles->search(undef,{prefetch => 'workflow'});
    $c->stash->{"dashboard_articlesInStatus$status"} = $articles;
    if (!$c->stash->{statusMap})
    {
        $c->stash->{statusMap} = {};
    }
    $c->stash->{statusMap}->{$status} = $status_obj->status_name($c->stash->{i18n});
}

# Summary: Prepare any data required for the "recent comments" widget
sub prepareRecentComments : Private
{
    my ( $self, $c ) = @_;
    my $dashboard_comments = $c->model('LIXUZDB::LzLiveComment')->search(undef,{ order_by => 'created_date DESC', rows => 30 });
    $c->stash->{dashboard_comments} = $dashboard_comments;
}

1;
