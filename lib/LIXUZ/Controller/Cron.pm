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

package LIXUZ::Controller::Cron;
use 5.010;
use Moose;
use Try::Tiny;
use LIXUZ::HelperModules::Calendar qw(datetime_from_SQL datetime_from_unix datetime_to_SQL);
use LIXUZ::HelperModules::TemplateRenderer::EMail;
use POSIX qw(strftime);
BEGIN { extends 'Catalyst::Controller' };

sub default : Path('/cron')
{
    my($self,$c) = @_;
    my $trigger = $c->req->param('schedule_trigger');
    if ($c->req->address ne '127.0.0.1' || !defined($trigger))
    {
        $c->res->body('ERR');
        $c->detach;
    }

    if ($trigger eq 'lixuz_daily_cron')
    {
        $self->daily($c);
    }
    elsif($trigger eq 'lixuz_daily_cron_two')
    {
        $self->twiceAday($c);
    }
    elsif($trigger eq 'rss')
    {
        $self->fetchRSS($c);
    }
    else
    {
        $c->res->body('ERR');
        $c->detach;
    }
    $c->res->body('OK');
    $c->detach;
}

sub daily : Private
{
    my($self,$c) = @_;

    try
    {
        $self->_newsletterDaily($c);
    }
    catch
    {
        $c->log->error('Cron: _newsletterDaily crashed: '.$_);
    };
    $self->twiceAday($c);
}

sub twiceAday : Private
{
    my($self,$c) = @_;

    try
    {
        $self->fetchRSS($c);
    }
    catch
    {
        $c->log->error('Cron: twiceAday crashed: '.$_);
    };
}

sub fetchRSS : Private
{
    my($self,$c) = @_;

    try
    {
        $c->forward(qw(LIXUZ::Controller::Admin::RSSImport importAllFeeds));
    }
    catch
    {
        $c->log->error('Cron: fetchRSS crashed: '.$_);
    };
}

sub _newsletterDaily : Private
{
    my($self,$c) = @_;

    my $newsletters = $c->model('LIXUZDB::LzNewsletterSubscription')->search({validated => 1});
    if(not defined $newsletters)
    {
        return;
    }

    my $daily = { send_every => 'day', last_sent => { '<', datetime_to_SQL(datetime_from_unix(time - 86300)) } };
    my $weekly  = { send_every => 'week', last_sent => { '<', datetime_to_SQL(datetime_from_unix(time - 86400)) } };
    my $monthly = { send_every => 'month', last_sent => { '<', datetime_to_SQL(datetime_from_unix(time - 86400)) } };
    my $catchAllNew = { last_sent => \'IS NULL' };

    my @search;
    push(@search,$daily);
    push(@search,$catchAllNew);

    if (strftime('%d',localtime) == 1)
    {
        push(@search,$monthly);
    }

    if (strftime('%u',localtime) == 1)
    {
        push(@search,$weekly);
    }

    my $sendThese = $newsletters->search({ -or => \@search },{ order_by => 'send_every,format'});

    while((defined $sendThese) && (my $n = $sendThese->next))
    {
        my $renderer = LIXUZ::HelperModules::TemplateRenderer::EMail->new( c => $c, subscription => $n);
        $renderer->autoSendNewsletter();
    }
}

1;
