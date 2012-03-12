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

package LIXUZ::Controller::Admin::Login;

use strict;
use warnings;
use base qw(Catalyst::Controller::FormBuilder);
use Digest::MD5 qw(md5);
use LIXUZ::HelperModules::Forms qw(finalize_form);

__PACKAGE__->config(
'Controller::FormBuilder' => {
template_type => 'Mason',    # default is 'TT' (e.g. TT2)
}
);

# Summary: Logout handler
sub logout : Path('/admin/logout')
{
    my ( $self, $c ) = @_;
    my $i18n = $c->stash->{i18n};
    eval
    {
        my $locks = $c->model('LIXUZDB::LzArticleLock')->search({
                locked_by_user => $c->user->user_id,
            });
        while((defined $locks) and (my $lock = $locks->next))
        {
            $lock->delete;
        }
    };

    my $redirFlash = $c->flash->{userRedirTo};
    my $redirFlashErr = $c->flash->{userRedirErr};

    $c->delete_session('Logging out');
    $c->logout();
    $c->stash->{username} = undef;	# Set by an auto action
    $c->stash->{user_id} = undef;
    $c->stash->{message} = $i18n->get('You have been logged out.');
    $c->flash->{userRedirTo} = $redirFlash;
    $c->flash->{userRedirErr} = $redirFlashErr;
    $c->forward('login');
}

# Summary: Login handler, creates the form and other goodies
sub login : Path('/admin/login') Form('/login')
{
    my ( $self, $c ) = @_;
    $c->stash->{pageTitle} = $c->stash->{i18n}->get('Login');
    my $i18n = $c->stash->{i18n};
    my $form = $self->formbuilder;
    my $redirectTo = $c->flash->{userRedirTo};
    $c->stash->{template} = 'adm/core/login.html';
    # If there's a userRedirErr message in the flash, display it
    if ($c->flash->{userRedirErr})
    {
        $c->stash->{message} = $c->flash->{userRedirErr};
    }
    # We want to keep this for now, no matter how the request goes
    $c->keep_flash('userRedirTo');
    # If the form is submitted and validated
    if ($form->submitted && $form->validate)
    {
        # Remove old session data if present
        $c->delete_session('Logging in, cleaning old data');
        # Authenticate
        if ($c->authenticate({
                    user_name => $form->field('user_name'),
                    password => $form->field('password'),
                }))
        {
            # Make sure that the user and role is active
            if(not $c->user->is_active())
            {
                $c->logout();
                $c->stash->{message} = $i18n->get_advanced('<b>Login refused</b>: %(REASON)', { REASON => $i18n->get('This account has been deactivated.')});
            }
            else
            {
                # User logged in, update fields
                $c->user->update({'last_login' => \'now()'});
                $c->stash->{username} = $form->field('user_name');
                # Redirect if userRedirTo exists in flash
                if ($redirectTo)
                {
                    $c->response->redirect($redirectTo);
                }
                else
                {
                    $c->response->redirect('/admin/dashboard');
                }
                $c->detach();
            }
        }
        else
        {
            $c->stash->{message} = $i18n->get('Invalid username or password');
        }
    }
    # Finalize the login form
    finalize_form($form,undef,{
            submit => $i18n->get('Log in'),
            fields =>
            {
                user_name => $i18n->get('Username'),
                password => $i18n->get('Password'),
            }
        });
    # Special case for handling 'ajax' calls.
    if (defined $c->flash->{userRedirTo} and $c->flash->{userRedirTo} =~ m{/ajax/?(\?.*)$})
    {
        $c->stash->{template} = 'adm/core/dummy.html';
        $c->stash->{content} = 'ERR LOGINREQUIRED';
        $c->stash->{displaySite} = 0;
    }
}

1;
