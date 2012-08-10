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
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

package LIXUZ::Controller::Admin::TimeTracker;

use 5.010_000;
use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
BEGIN { extends 'Catalyst::Controller::FormBuilder' };
with 'LIXUZ::Role::List::Database';

use LIXUZ::HelperModules::Forms qw(finalize_form);
use LIXUZ::HelperModules::Lists qw(reply_json_list);
use LIXUZ::HelperModules::Includes qw(add_jsIncl add_cssIncl add_jsOnLoad add_globalJSVar add_jsOnLoadHeadCode);
use LIXUZ::HelperModules::Calendar qw(create_calendar datetime_to_SQL datetime_from_SQL datetime_from_unix);
use LIXUZ::HelperModules::Editor qw(create_editor);
use LIXUZ::HelperModules::JSON qw(json_response json_error);
use LIXUZ::HelperModules::TemplateRenderer;
use constant { true => 1, false => 0};
use LIXUZ::HelperModules::Calendar qw(datetime_from_unix datetime_to_SQL datetime_from_SQL_to_unix datetime_from_SQL);
use HTML::HTMLDoc;

# Summary: Forward the time entry to the list view, and display a status message at the top of it
# Usage: $self->messageToList($c, MESSAGE);
sub messageToList
{
    my ($self, $c, $message) = @_;
    $c->flash->{ListMessage} = $message;
    $c->response->redirect('/admin/timetracker');
    $c->detach();
}

#shows the default timeentry list view, time entry search result list view and PDF generation.
sub index : Path Args(0) Form('/core/search')
{
    my ( $self, $c, $query ) = @_;
    my $i18n = $c->stash->{i18n};
    my $timetrackentry = $c->model('LIXUZDB::LzTimeEntry');

    if (not $c->user->can_access('VIEW_OTHERS_TIME_ENTRY'))
    {
        $timetrackentry = $timetrackentry->search({ user_id => $c->user->user_id });
    }
     
    if (defined $c->req->param('filter_user_id') and length $c->req->param('filter_user_id'))
    {
        if ($c->req->param('filter_user_id') !~ /\D/)
        {
            $timetrackentry = $timetrackentry->search({user_id=> $c->req->param('filter_user_id')});
        }
    }

    if (defined $c->req->param('filter_datetimerange') and length $c->req->param('filter_datetimerange'))
    {
        my $qstring = $c->req->param('filter_datetimerange');
        my @parts = split('-',$qstring);
        my $frmdate = $parts[0];
        my $todate = $parts[1];
        if ((defined $frmdate and length $frmdate) and (defined $todate and length $todate))
        {
            if ($frmdate =~ s/^\s*(\S+\s+\S+)\s*$/$1/ and $todate =~ s/^\s*(\S+\s+\S+)\s*$/$1/)
            {
                $frmdate = datetime_to_SQL($frmdate);
                $todate = datetime_to_SQL($todate);
                my $frmdate_unix = datetime_from_SQL_to_unix($frmdate);
                my $todate_unix = datetime_from_SQL_to_unix($todate);
                if ($todate_unix > $frmdate_unix)
                {
                    $timetrackentry = $timetrackentry->search({ 
                             -and=> [ 
                                 time_start => {'>='=> $frmdate },
                                 time_end => {'<='=> $todate },
                         ],
                     });
                 }
                 else
                 {
                     my $message = $i18n->get('Invalid daterange selected');
                     $self->messageToList($c, $message );
                 }
             }
             else
             {
                 my $message = $i18n->get('Invalid daterange selected');
                 $self->messageToList($c, $message );
             }
         }
         else
         {
             my $message = $i18n->get('Invalid daterange selected');
             $self->messageToList($c, $message );
         }
    }

    if (defined $c->req->param('reports') and $c->req->param('reports') eq 'yes')
    {
        my $reportTitle = $i18n->get('Timetracker');
        $c->stash->{timetrackentry} = $timetrackentry;
        $c->stash->{template} = 'adm/timetracker/pdf_report.html';
        $c->stash->{displaySite} = 0;
        my $html = $c->view('Mason')->render($c,'adm/timetracker/pdf_report.html');

        my $htmldoc = new HTML::HTMLDoc('mode'=>'file','tmpdir'=>'/tmp');

        $htmldoc->set_html_content($html);
        my $pdf = $htmldoc->generate_pdf();
        my $fh =  $pdf->to_string();
        $c->res->body($fh);
    }
    else
    {
        my $list = $self->handleListRequest({
                    c => $c,
                    query => $query,
                    object => $timetrackentry,
                    objectName => 'timetrackentry',
                    template => 'adm/timetracker/index.html',
                    orderParams => [qw(user_id time_start time_end)],
                    searchColumns => [qw(user_id time_start time_end)],
                    advancedSearch =>[ qw(user_id time_start time_end) ],
                    paginate => 1,
                });
        
        if ($c->req->param('_JSON_Submit'))
        {
            return reply_json_list($c,$list,[ 'user_id','time_start','time_end', 'ip_start','ip_end' ]);
        }

        $c->stash->{template} = 'adm/timetracker/index.html';
        $c->stash->{pageTitle} = $i18n->get('Timetracker');
        $self->init_searchFilters($c);
        add_jsIncl($c,'jscalendar.lib.js','timetracker.js');
    }
}

sub init_searchFilters : Private
{
    my ( $self, $c ) = @_;
    my $i18n = $c->stash->{i18n};
    my $userOptions = [];
    my $users = $c->model('LIXUZDB::LzUser')->search(undef,{ order_by => 'user_name' });
    while(my $user = $users->next)
    {
        next if !defined($user->user_name) || !length($user->user_name);
        push(@{$userOptions}, {
           value =>  $user->user_id,
           label =>  $user->user_name,
        });
    }

    $c->stash->{searchFilters} = [
        {
            type => 'datetimerange',
            name => $i18n->get('From and to date'),
            realname => 'datetimerange',
            dateformat => '%d.%m.%Y %H:%M',
            selected => defined $c->req->param('filter_datetimerange') ? $c->req->param('filter_datetimerange') : undef,
        },

        {
            name => $i18n->get('User'),
            realname => 'user_id',
            options => $userOptions,
            selected => defined $c->req->param('filter_user_id') ? $c->req->param('filter_user_id') : undef,
            anyString => $i18n->get('(any user)'),
        },
    ];
    
    $c->stash->{displaytextfield} = 'no';
}

#Handle adding a new time entry, editing existing time entry
sub entrySave : Local 
{
    my ( $self, $c ) = @_;
    my $timeentry;
    my $timetrackcomment;
    my $time_start = $c->req->param('time_start');
    my $time_end = $c->req->param('time_end');
    my $ip_start = $c->req->address;
    my $ip_end = $c->req->address;
    my $subject = $c->req->param('subject');
    my $comment = $c->req->param('comment');
    my $timeentry_id = $c->req->param('timeentry_id');

    if ($c->user->can_access('/timetracker/entrySave'))
    {
        if ($timeentry_id eq 'new')
        {
            $timeentry = $c->model('LIXUZDB::LzTimeEntry')->create({
                user_id => $c->user->user_id,
                time_start => datetime_to_SQL($time_start),
                time_end => datetime_to_SQL($time_end),
                ip_start => $ip_start,
                ip_end => $ip_end,
            });
            $timeentry->update();
            my $latestentryid = $timeentry->time_id;
            if ($latestentryid)
            {
                $timetrackcomment = $c->model('LIXUZDB::LzComment')->create({
                        user_id => $c->user->user_id,
                        object_id => $latestentryid,
                        object_type => 'time_entry',
                        written_time => \'NOW()',
                        subject => $subject,
                        body => $comment,
                    });
                $timetrackcomment->update();
            }
        }
        else
        {
            $timeentry = $c->model('LIXUZDB::LzTimeEntry')->find({ time_id => $c->req->param('timeentry_id')});
            if(not $timeentry)
            {
                return json_error($c,'INVALID_TIME_ID');
            }
            else
            {
                if(defined $time_start)
                {
                    $timeentry->set_column('time_start',datetime_to_SQL($time_start));
                }
                if(defined $time_end)
                {
                    $timeentry->set_column('time_end',datetime_to_SQL($time_end));
                }
                $timeentry->update();

                if ($c->req->param('timeentry_id'))
                {
                    my $editingtimeentry = $c->req->param('timeentry_id');

                    $timetrackcomment = $c->model('LIXUZDB::LzComment')->create({
                    user_id => $c->user->user_id,
                    object_id => $editingtimeentry,
                    object_type => 'time_entry',
                    written_time => \'NOW()',
                    subject => $subject,
                    body => $comment,
                    });
                    $timetrackcomment->update();
                }
            }
        }
        return json_response($c);
    }
    else
    {
        return(json_error($c,'Permission denied.'));   
    }
}

# Adding a new time entry when user start timetracker
sub addTimeEntry : Local
{
    my ( $self, $c, $action ) = @_;
    my $timeentry;
    my $tt_status;
    my $current_date_time = datetime_from_unix(time());
    $current_date_time = datetime_to_SQL($current_date_time);
    my $ip = $c->req->address;
    my $current_time = get_current_time();

    if ($action eq 'start')
    {
        $timeentry = $c->model('LIXUZDB::LzTimeEntry')->create({
                user_id => $c->user->user_id,
                time_start => $current_date_time,
                ip_start => $ip,
                tt_status => 1,
            });
    }
    else
    {
        $timeentry = $c->model('LIXUZDB::LzTimeEntry')->find({ user_id => $c->user->user_id, tt_status => 1});
        $timeentry->set_column('time_end',$current_date_time);
        $timeentry->set_column('ip_end',$ip);
        $timeentry->set_column('tt_status',0);
    }
    $timeentry->update();

    my $info = {
                tt_status => $timeentry->tt_status,
                current_time => $current_time,
                };
    return json_response($c,$info);
}

# using timeentry_id ,it retrive timeentry information for edit functionality
# This will pre-populate fieldname with the value specified
sub timeentryInfo : Local Param
{
    my ( $self, $c, $timeentry_id ) = @_;
    my $i18n = $c->stash->{i18n};
    my $dbsubject;
    my $dbcomments;
    my $author = '(unknown)';
    my $timeentry = $c->model('LIXUZDB::LzTimeEntry')->find({ time_id => $timeentry_id });
    if(not $timeentry)
    {
        return(json_error($c,'INVALIDID'));
    }
    my $info = {
        time_start => datetime_from_SQL($timeentry->time_start),
        time_end => datetime_from_SQL ($timeentry->time_end),
        timeentry_id => $timeentry->time_id,
        ip_start => $timeentry->ip_start,
        ip_end => $timeentry->ip_end,
        subject => $dbsubject,
        comment => $dbcomments,
    };

    return json_response($c,$info);
}

# Purpose: Delete a time entry.
sub deletetimeEntry : Local Param
{
    my ($self,$c,$timeentryid) = @_;
    my $i18n = $c->stash->{i18n};
    if (not defined $timeentryid or $timeentryid =~ /\D/)
    {
        return json_error($c, $i18n->get('Failed to locate timeentry id. The path specified is invalid.'));
    }
    else
    {
        my $timeentry = $c->model('LIXUZDB::LzTimeEntry')->find({ time_id => $timeentryid });
        if(not $timeentry)
        {
            return json_error($c);
        }
        if ($c->user->can_access('DELETE_OTHERS_TIME_ENTRY'))
        {
            $timeentry->delete();
            return json_response($c);
        }
        else
        {
            if ($c->user->user_id == $timeentry->user_id)
            {
                $timeentry->delete();
                return json_response($c);
            }
            else
            {
                return json_error($c);
            }
        }
    }
}

# Retrieve a list of comments
sub commentlist : Local Arg
{
    my ( $self, $c, $teid) = @_;
    my $commentsobj;
    if ($c->user->can_access('VIEW_OTHERS_TIME_ENTRY'))
    {
        $commentsobj = $c->model('LIXUZDB::LzComment')->search({ object_id => $teid },{order_by => 'written_time'});
    }
    else
    {
        my  $timeentry = $c->model('LIXUZDB::LzTimeEntry')->find({time_id => $teid, user_id => 5 });

        if (defined $timeentry and $timeentry->user_id == $c->user->user_id)
        {
            $commentsobj = $c->model('LIXUZDB::LzComment')->search({ object_id => $teid },{order_by => 'written_time'});
        }
    }
    $c->stash->{commentsobj} = $commentsobj;
    $c->stash->{template} = 'adm/timetracker/timetracker_comments.html';
    $c->stash->{displaySite} = 0;
}

# Check the on/off timetracker status of logged in users.
sub checkTimeTrackerStatus : Local
{
    my ( $self, $c) = @_;
    my $tt_status = 0;
    my $current_time = get_current_time();
    my $timeentry = $c->model('LIXUZDB::LzTimeEntry')->find({ user_id => $c->user->user_id, tt_status => 1});
    if ($timeentry)
    {
        $tt_status = $timeentry->tt_status;
    }
    my $info = {
        tt_status => $tt_status,
        current_time => $current_time,
    };

    return json_response($c,$info);
}       

