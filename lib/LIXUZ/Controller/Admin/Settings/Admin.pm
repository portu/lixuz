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

package LIXUZ::Controller::Admin::Settings::Admin;

use strict;
use warnings;
use base 'Catalyst::Controller';

sub server : Local
{
    my ( $self, $c ) = @_;
    $c->stash->{template} = 'adm/core/dummy.html';
    $c->stash->{content} = 'Not implemented';
    $c->stash->{pageTitle} = $c->stash->{i18n}->get('Server settings');
}

1;
