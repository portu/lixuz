# Copyright (C) Utrop A/S Portu media & Communications 2008-2012
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

package LIXUZ::Controller::Admin::TimeTracker::Listview;

use 5.010_000;
use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
BEGIN { extends 'Catalyst::Controller::FormBuilder' };
with 'LIXUZ::Role::List::Database';

use LIXUZ::HelperModules::Forms qw(finalize_form);
use LIXUZ::HelperModules::Lists qw(reply_json_list);
use LIXUZ::HelperModules::Includes qw(add_jsIncl add_cssIncl add_jsOnLoad add_globalJSVar add_jsOnLoadHeadCode);
use LIXUZ::HelperModules::Calendar qw(create_calendar datetime_to_SQL datetime_from_SQL datetime_from_unix datetime_from_SQL_to_unix);
use LIXUZ::HelperModules::Editor qw(create_editor);
use LIXUZ::HelperModules::JSON qw(json_response json_error);
use LIXUZ::HelperModules::Fields;
use LIXUZ::HelperModules::HTMLFilter qw(filter_string);
use LIXUZ::HelperModules::TemplateRenderer;
use LIXUZ::HelperModules::RevisionHelpers qw(article_latest_revisions get_latest_article set_other_articles_inactive);
use constant { true => 1, false => 0};
use HTML::HTMLDoc;

# Summary: Forward the time entry to the list view, and display a status message at the top of it
# Usage: $self->messageToList($c, MESSAGE);
sub messageToList
{
    my ($self, $c, $message) = @_;
    $c->flash->{ListMessage} = $message;
    $c->response->redirect('/admin/timetracker/listview');
    $c->detach();
}

#shows the default timeentry list view, time entry search result list view and PDF generation.
sub index : Path Args(0) Form('/core/search')
{
    my($self,$c,$query) = @_;
    my $i18n = $c->stash->{i18n};
    my @arrsts;
    my %info;
    my $timetrackentry = $c->model('LIXUZDB::LzTimeEntry');

    if (defined $c->req->param('filter_user_id') and length $c->req->param('filter_user_id'))
    {
        my $subuserid = $c->req->param('filter_user_id');
        $timetrackentry = $timetrackentry->search({ user_id=> $subuserid });
    }

    if (defined $c->req->param('filter_datetimerange') and length $c->req->param('filter_datetimerange'))
    {
        my $qstring = $c->req->param('filter_datetimerange');
        my @parts = split('-',$qstring);
        my $frmdate = $parts[0];
        my $todate = $parts[1];
        if ((defined $frmdate and length $frmdate) and (defined $todate and length $todate))
        {
            $frmdate = $frmdate.' 00:00';
            $todate = $todate.' 23:59';

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
                        }
                    );
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

    $timetrackentry = $timetrackentry->search({ },{ order_by => {-desc => \'DATE(time_start)'} });

    $timetrackentry = $timetrackentry->search({ },{ group_by => \'DATE(time_start)' });

    if ($timetrackentry)
    {
        my $i=0;   
        while(my $timetracks = $timetrackentry->next)
        {
            my @userArray = ();
            $i++;
            my $record_date = $timetracks->time_start;
            $record_date =~ s/\s+\S+$//;
            my $changed_record_date = datetime_from_SQL($timetracks->time_start);
            $changed_record_date =~ s/\s+\S+$//;

            my $inuserid = $timetracks->user_id;

            $info{$i}{recdate} = $changed_record_date;
            my $datewise_entry = $c->model('LIXUZDB::LzTimeEntry')->search_like({ time_start => $record_date.'%',user_id => $inuserid });
            if ($datewise_entry)
            {
                while(my $dateentry = $datewise_entry->next)
                {
                    push(@userArray,$dateentry->user_id);
                    my $username = $dateentry->timeEntryUser->name;
                    if(not defined $username or not length $username)
                    {
                        $username = $i18n->get('(none)');
                    }
                    my $start_datetime = $dateentry->time_start;
                    my $end_datetime = $dateentry->time_end;
                    (my $strtime = $start_datetime) =~ s/^\S+\s+//;
                    (my $endtime = $end_datetime) =~ s/^\S+\s+//;

                    (my $strhour = $strtime) =~ s/\:\d+$//;
                    (my $endhour = $endtime) =~ s/\:\d+$//;

                    my $from_to = $strhour.'-'.$endhour;

                    my $unx_start_datetime = datetime_from_SQL_to_unix($start_datetime);
                    my $unx_end_datetime = datetime_from_SQL_to_unix($end_datetime);

                    my $tdiff = $unx_end_datetime-$unx_start_datetime;
                    my $seconds = $tdiff % 60;
                    $tdiff = ($tdiff - $seconds)/60;
                    my $minutes = $tdiff % 60;
                    $tdiff = ($tdiff - $minutes)/60;
                    my $hours = $tdiff % 24;

                    push(@{$info{$i}{timedata}}, {
                            timeentry_id => $dateentry->time_id,
                            username => $username ,
                            from_to => $from_to,
                            duration =>$hours.':'.$minutes,
                            entry_type => $dateentry->entry_type,
                        });
                }
            }

            my $articledata = $c->model('LIXUZDB::LzArticle');
            $articledata = article_latest_revisions($articledata);
            if (defined $c->req->param('filter_status_id') and length $c->req->param('filter_status_id'))
            {
                @arrsts = $c->req->param('filter_status_id');
                $articledata = $articledata->search({
                    status_id => {
                        -IN => [ @arrsts ],
                    }
                });
            }
            $articledata = $c->model('LIXUZDB::LzArticle')->search({ 
                    'revisionMeta.committer' => {
                        -IN => [ @userArray ],
                    },
                    'DATE(revisionMeta.created_at)' => $record_date
                }, 
                { join => 'revisionMeta' });

            if ($articledata)
            {
                while(my $artdt = $articledata->next)
                {
                    my $wordcount;
                    if(length $artdt->body)
                    {
                        my  $string  = $artdt->text_body();
                        $wordcount = () = split(/\s+/,$string,-1);
                    }

                    push(@{$info{$i}{articledata}}, {
                            article_id => $artdt->article_id ,
                            path => $artdt->primary_folder->folder->get_path() ,
                            title => $artdt->title,
                            wordcount => $wordcount,
                            revision =>$artdt->revision,
                        });
                }
            }

        }
    }

    my $list = $self->handleListRequest($c,{
        query => $query,
        object => $timetrackentry,
        objectName => 'timetrackentry',
        template => 'adm/timetracker/listview/index.html',
        orderParams => [qw(user_id time_start time_end)],
        searchColumns => [qw(user_id time_start time_end)],
        advancedSearch =>[ qw(user_id time_start time_end) ],
        paginate => 1,
    });

    if ($c->req->param('_JSON_Submit'))
    {
        return reply_json_list($c,$list,[ 'user_id','time_start','time_end', 'ip_start','ip_end' ]);
    }

    $c->stash->{retarray} = \%info;

    if (defined $c->req->param('reports') and $c->req->param('reports') eq 'yes')
    {
        my $reportTitle = $i18n->{"List view"};
        $c->stash->{template} = 'adm/timetracker/listview/pdf_data.html';
        $c->stash->{displaySite} = 0;
        my $html = $c->view('Mason')->render($c,'adm/timetracker/listview/pdf_data.html');
        my $htmldoc = new HTML::HTMLDoc('mode'=>'file','tmpdir'=>'/tmp');
        $htmldoc->title($reportTitle);
        $htmldoc->set_logoimage('/static/images/lixuz.png');
        $htmldoc->set_header('-','l','-');
        $htmldoc->set_html_content($html);
        my $pdf = $htmldoc->generate_pdf();
        my $fh = $pdf->to_string();
        $c->res->content_type('application/octet-stream');
        $c->res->body($fh);
    }
    else
    {
        $c->stash->{template} = 'adm/timetracker/listview/index.html';
        $c->stash->{pageTitle} = $i18n->{'List view'};
        add_jsIncl($c,'jscalendar.lib.js','listview.js');
        $self->init_searchFilters($c);
    }
}

sub init_searchFilters : Private
{
    my ( $self, $c ) = @_;
    my $i18n = $c->stash->{i18n};
    my $userOptions = [];
    my @selectedarray;
    my $selectedstring;
    if(defined $c->req->param('filter_status_id'))
    {
     @selectedarray = $c->req->param('filter_status_id');
     $selectedstring = join(",",@selectedarray);
    } 
    my $users = $c->model('LIXUZDB::LzUser')->search(undef,{ order_by => 'user_name' });
    while(my $user = $users->next)
    {
        next if !defined($user->user_name) || !length($user->user_name);
        push(@{$userOptions}, {
                value =>  $user->user_id,
                label =>  $user->user_name,
            });
    }
    my $statusOptions = [];
    my $statuses = $c->model('LIXUZDB::LzStatus');
    while(my $status = $statuses->next)
    {
        push(@{$statusOptions}, {
                value => $status->status_id,
                label => $status->status_name($i18n),
            });
    }
    $c->stash->{statusOptions} = $statusOptions;

    $c->stash->{searchFilters} = [
        {
            type => 'datetimerange',
            name => $i18n->get('From and to date'),
            realname => 'datetimerange',
            dateformat => '%d.%m.%Y',
            selected => defined $c->req->param('filter_datetimerange') ? $c->req->param('filter_datetimerange') : undef,
        },
        {
            name => $i18n->get('User'),
            realname => 'user_id',
            options => $userOptions,
            selected => defined $c->req->param('filter_user_id') ? $c->req->param('filter_user_id') : undef,
            anyString => $i18n->get('(any user)'),
        },
        {
            realname => 'status_id',
            options => $statusOptions,
            selected => defined $c->req->param('filter_status_id') ? $selectedstring : undef,
            multiple => 'true',
            anyString => ' ',
        },
    ];

    $c->stash->{displaytextfield} = 'no';
}
