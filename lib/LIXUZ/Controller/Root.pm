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

package LIXUZ::Controller::Root;

use strict;
use warnings;
use 5.010;
use Try::Tiny;
use base 'Catalyst::Controller';
use LIXUZ::HelperModules::JSON qw(json_response json_error);
use LIXUZ::HelperModules::AccessControl;
use LIXUZ::HelperModules::TemplateRenderer::URLHandler;

#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in MyApp.pm
#
__PACKAGE__->config->{namespace} = '';

# Purpose: Handle input for the live site
sub default : Private
{
    my ( $self, $c ) = @_;
    my $handler = LIXUZ::HelperModules::TemplateRenderer::URLHandler->new(
        c => $c,
    );
    $handler->handleRequest();
}

# Uncomment to enable exiting the daemon. Ie. for use when profiling.
#sub exitme : Public Path('/exitme')
#{
#    exit(0);
#}

# This can be used to perform simple "are you alive and well?" checks on the
# running Lixuz instance, ie. via monit. If it returns anything other than a
# 200 OK then you know something is wrong, and you can take neccesary steps -
# either automatic or manual.
#
# It will only allow requests from 127.0.0.1, anyone else will be redirected
# to /admin
sub alive : Path('/admin/alive')
{
    my($self,$c) = @_;
    if ($c->req->address eq '127.0.0.1')
    {
        my $db = 0;
        my $status = 200;

        # Make sure our database connection is alive and well
        try
        {
            if ($c->model('LIXUZDB::LzStatus')->search()->first)
            {
                $db = 1;
            }
        };

        # If the database check failed, return an error
        if(!$db)
        {
            $status = 500;
            $c->res->body('EDATABASE');
        }
        else
        # Everything went well, so return success
        {
            $c->res->body('OK');
        }
        $c->res->status($status);
    }
    else
    {
        $c->res->redirect('/admin');
    }
    $c->detach;
}

# Purpose: Populate the stash with some useful defaults
sub auto : Private
{
    my ( $self, $c ) = @_;
    # Let the view know our version number
    $c->stash->{VERSION} = $LIXUZ::VERSION;
    $c->stash->{GITREVISION} = $LIXUZ::GITREV;
    return 1;
}

# Summary: Handle errors and non-Mason data requests, and redirect to the Mason
# view if needed
sub end : Private
{
    my ( $self, $c ) = @_;

    if ( scalar @{ $c->error } and not $c->debug)
    {
        foreach(@{$c->error})
        {
            $c->log->error($_);
        }
        $c->error(0);
        $c->stash->{template} = 'core/renderError.html';
        if(not defined $c->stash->{techie})
        {
            $c->stash->{techie} = 'An exception occurred. Check the logfile for the exception text.';
        }
        $c->detach('LIXUZ::View::Mason');
    }

    return 1 if $c->response->body or $c->response->status =~ /^3\d\d$/;

    if(not defined $c->response->content_type)
    {
        $c->response->content_type('text/html; charset=utf-8');
    }

    $c->forward('LIXUZ::View::Mason');
}
1;
