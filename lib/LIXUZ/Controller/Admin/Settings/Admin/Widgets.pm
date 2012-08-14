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

package LIXUZ::Controller::Admin::Settings::Admin::Widgets;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
BEGIN { extends 'Catalyst::Controller::FormBuilder' };
use base qw(Catalyst::Controller::FormBuilder);
use LIXUZ::HelperModules::Includes qw(add_jsIncl);
use LIXUZ::HelperModules::Forms qw(get_checkboxes);
use List::MoreUtils qw(any);
with 'LIXUZ::Role::List::Database';

sub index : Private
{
    my ( $self, $c ) = @_;
    if ($c->flash->{ListMessage})
    {
        $c->stash->{widgetMessage} = $c->flash->{ListMessage};
    }
    $c->stash->{template} = 'adm/settings/admin/widget_index.html';
}

sub configure : Local Args
{
    my ($self,$c,$widget) = @_;

    if ($widget eq 'MyAssignments')
    {
        return $self->myAssignmentConfig($c);
    }
    else
    {
        return $self->messageToList($c,$c->stash->{i18n}->get('Unknown widget'));
    }
}

sub myAssignmentConfig
{
    my ($self,$c) = @_;
    my $widget = LIXUZ::HelperModules::Widget->new($c,'MyAssignments');
    if (defined $c->req->param('statusSubmission') and $c->req->param('statusSubmission') eq 'true')
    {
        my @ignored;
        foreach my $param (keys %{$c->req->params})
        {
            next if not $param =~ s/^status_//;
            push(@ignored,$param);
        }
        my $conf = join(',',@ignored);
        $widget->set_config('excludeStatusIds',$conf,1);
        $self->messageToList($c,$c->stash->{i18n}->get('Changes saved'));
    }
    else
    {
        my $excluded = $widget->get_config('excludeStatusIds',1);
        $excluded = $excluded ? $excluded : '2';
        my %activeExclusions = map { $_ => 1 } split(/,/,$excluded);
        $c->stash->{active} = \%activeExclusions;
        $c->stash->{statuses} = $c->model('LIXUZDB::LzStatus')->search(undef,{ order_by => 'status_id' });
        $c->stash->{template} = 'adm/settings/admin/widget_myAssignmentsConfig.html';
    }
}

1;
