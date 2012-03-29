# LIXUZ content management system
# Copyright (C) Utrop A/S Portu media & Communications 2012
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

package LIXUZ::Controller::Admin::LogService;

use Moose;
use JSON::XS;
use LIXUZ::HelperModules::JSON qw(json_response);
BEGIN { extends 'Catalyst::Controller' };

sub default : Public
{
    my($self,$c) = @_;
    my $output = 'Received error log from client: ';
    my $json = JSON::XS->new();
    $output .= $json->encode({
            error => $c->req->param('error'),
            backtrace => $c->req->param('backtrace'),
            URL => $c->req->param('URL'),
            UA => $c->req->param('UA'),
            user_id => $c->user ? $c->user->user_id : 'UNKNOWN',
        });
    $c->log->error($output);
    return json_response($c);
}

1;
