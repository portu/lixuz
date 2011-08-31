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

package LIXUZ::Controller::Admin::ACL;

use strict;
use warnings;
use base qw(Catalyst::Controller);
use LIXUZ::HelperModules::JSON qw(json_error);

sub access_denied: Private
{
    my($self,$c) = @_;
    if ($c->req->param('_JSON_Submit'))
    {
        return json_error($c,'ACCESS_DENIED','Access to the requested file, component or resource was denied for your role',undef, { path_denied => $c->user->last_denied});
    }
    my $i18n = $c->stash->{i18n};
    $c->stash->{template} = 'adm/core/dummy.html';
    $c->stash->{content} = '<br /><br /><center>'.$i18n->get('<b>Access denied</b>: You are not allowed to access that resource').'</center><br /><br />';
    $c->stash->{pageTitle} = $c->stash->{i18n}->get('Access denied');
    # Return 403 forbidden status
    $c->response->status(403);
    $c->detach('LIXUZ::View::Mason');
}
1;
