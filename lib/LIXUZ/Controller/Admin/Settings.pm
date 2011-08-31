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

package LIXUZ::Controller::Admin::Settings;

use strict;
use warnings;
use base 'Catalyst::Controller';

sub index : Private
{
    my ( $self, $c ) = @_;
    shift;

    $c->stash->{pageTitle} = $c->stash->{i18n}->get('Settings');
    if ($c->user->can_access('/settings/admin'))
    {
        return $self->menu(@_);
    }
    else
    {
        return $self->user(@_);
    }
}

sub menu : Private
{
    my ( $self, $c ) = @_;
    $c->stash->{template} = 'adm/settings/menu.html';
}

sub admin : Local Args
{
    my ( $self, $c ) = @_;

    $c->stash->{template} = 'adm/settings/admin.html';
}

sub user : Local
{
    my ( $self, $c ) = @_;
    $c->stash->{template} = 'adm/settings/user.html';
}

1;
