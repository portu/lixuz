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

package LIXUZ::Controller::Admin;
use strict;
use warnings;
use 5.010;
use base 'Catalyst::Controller';
use LIXUZ::HelperModules::JSON qw(json_response json_error);
use LIXUZ::HelperModules::I18N;

# Summary: Detect which language to use, and return it
sub detectLang : Private
{
    my($self,$c) = @_;
    my $lang = 'en_US';

    if ($c->user && $c->user->lang)
    {
        return $c->user->lang;
    }

    my $acceptLang = $c->req->headers->header('Accept-Language');
    $acceptLang //= '';
    # If nn is the primary language, use that
    if ($acceptLang =~ /^nn/)
    {
        $lang = 'nn_NO';
    }
    # Otherwise for all other Norwegian users use nb
    elsif ($acceptLang =~ /(nb|no)/)
    {
        $lang = 'nb_NO';
    }
    # Finally if a user does not list nb/no but lists nn, use nn
    elsif ($acceptLang =~ /nn/)
    {
        $lang = 'nn_NO';
    }
    return $lang;
}

# Summary: Base URL handler for admin controllers. Makes sure a user is
# logged in, that the user is active, that the user has access to the URL
# requested, and keeps the session alive.
sub auto : Private
{
    my($self,$c) = @_;

    $self->initI18N($c);

    # Redirect to login if we're not logged in
    if ($c->user_exists && not $c->user->is_active)
    {
        $c->logout();
        if ($c->req->param('_JSON_Submit'))
        {
            return json_error($c,'ACCOUNT_INACTIVE',$c->stash->{i18n}->get('This account has been deactivated.'));
        }
        $c->flash->{userRedirErr} = '<b>'.$c->stash->{i18n}->get('Permission denied').'.</b> '.$c->stash->{i18n}->get('This account has been deactivated.');
        $c->response->redirect('/admin/login');
        $c->detach();
    }
    elsif(not $c->user_exists and not ( $c->controller eq $c->controller('Admin::Login') or $c->controller eq $c->controller('Admin::ForgottenPw')))
    {
        if ($c->req->param('_JSON_Submit'))
        {
            return json_error($c,'NEEDSLOGIN');
        }
        $c->flash->{userRedirErr} = '<b>'.$c->stash->{i18n}->get('Permission denied').'.</b> '.$c->stash->{i18n}->get('You need to log in to access that resource.');
        if(not($c->req->uri eq $c->uri_for('/admin/login') or $c->req->uri eq $c->uri_for('/admin/forgottenpw')))
        {
            $c->flash->{userRedirTo} = $c->req->uri;
        }
        $c->response->redirect('/admin/login');
        $c->detach();
    }

    # If we're logged in, put username into the stash and do ACL.
    if ($c->user)
    {
        $c->stash->{username} = $c->user->user_name;
        $c->stash->{user_id} = $c->user->get_column('user_id');
        # Make sure that the user can access the requested action.
        # check_access() will detach and display an access denied page if
        # access is denied.
        $c->user->set_c($c);
        if(not $c->req->uri eq $c->uri_for('/admin/logout'))
        {
            $c->user->check_access();
        }
        # Reset the session expiration time
        $c->session_expires(1);
    }
    return 1;
}

# Summary: Initializes the i18n object in the stash
sub initI18N : Private
{
    my($self,$c) = @_;

    my $lang = $self->detectLang($c);
    if ($lang ne 'en_US')
    {
        ($c->stash->{lixuzLang} = $lang) =~ s/_.+//;
    }
    # Create the i18n object, which all localizable text should be passed through
    $c->stash->{i18n} = LIXUZ::HelperModules::I18N->new('lixuz',$lang,$c->path_to('i18n','locale')->stringify);
}

# Summary: The 404 error handler for admin pages
sub default : Private
{
    my ( $self, $c ) = @_;
    if ($c->req->param('_JSON_Submit'))
    {
        return json_error($c,'404_ERROR');
    }
    else
    {
        my $i18n = $c->stash->{i18n};
        $c->response->status('404');
        $c->stash->{template} = 'adm/core/dummy.html';
        $c->stash->{pageTitle} = $i18n->get('404 error');
        $c->stash->{content} = '<br /><br /><center><b>'.$i18n->get('404 error').'</b><br /><br />'.
        $i18n->get('The component or object you requested could not be found<br /><br />If you entered the URL manually, please check if you have mistyped something.<br /><br />If you followed a link inside of Lixuz then this is almost certainly a bug,<br />please report it to your administrator or the Lixuz development team.<br /><br />Error information:<br />')
        .'Referrer: '.$c->req->referer.'<br />'
        .'URL: '.$c->req->uri.'<br />'
        .'User ID: '.$c->user->user_id.'<br />'
        .'</center><br />';
    }
}

# Summary: Redirect bare /admin requests to the dashboard
sub index : Private
{
    my ( $self, $c ) = @_;
    $c->response->redirect('/admin/dashboard');
    $c->detach();
}

# Summary: Handle crashes, ensure 3xx responses don't get data from Mason, set
# the correct content-type and forward to the default view if needed.
sub end : Private
{
    my ( $self, $c ) = @_;

    if ( scalar @{ $c->error } && not $c->debug)
    {
        my @errors = @{ $c->error };
        foreach(@{$c->error})
        {
            $c->log->error($_);
        }
        $c->error(0);
        if ($c->req->param('_JSON_Submit'))
        {
            return json_error($c,'INTERNAL_ERROR');
        }
        else
        {

            $c->stash->{displaySite} = 0;
            $c->stash->{template} = '/adm/core/error.html';
            $c->stash->{errorMessages} = \@errors;
            $c->forward('LIXUZ::View::Mason');
        }
    }

    if ($c->response->has_body || $c->stash->{_requestHandled} || $c->response->status =~ /^3\d\d$/)
    {
        return 1;
    }

    if(not defined $c->response->content_type)
    {
        $c->response->content_type('text/html; charset=utf-8');
    }

    $c->forward('LIXUZ::View::Mason');
}

1;
