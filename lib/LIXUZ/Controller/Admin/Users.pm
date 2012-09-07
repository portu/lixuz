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

package LIXUZ::Controller::Admin::Users;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
BEGIN { extends 'Catalyst::Controller::FormBuilder' };
with 'LIXUZ::Role::List::Database';

use LIXUZ::HelperModules::Search qw(cross);
use LIXUZ::HelperModules::Forms qw(finalize_form);
use LIXUZ::HelperModules::Fields;

# Summary: Main index function for the users interface
sub index : Path Args(0) Form('/core/search')
{
    my ( $self, $c, $query ) = @_;
    my $users = $c->model('LIXUZDB::LzUser');
    $c->stash->{pageTitle} = $c->stash->{i18n}->get('Users');
    $self->handleListRequest($c,{
            c => $c,
            query => $query,
            object => $users,
            objectName => 'users',
            template => 'adm/users/index.html',
            orderParams => [qw(user_id user_name firstname lastname user_status email)],
            paginate => 1,
            advancedSearch => [ qw(role_id user_status) ],
            searchColumns => [ qw/user_name firstname lastname email/ ],
        });
    $self->init_searchFilters($c);
}

# Summary: Initialize search filters
sub init_searchFilters : Private
{
    my ( $self, $c ) = @_;

    my $i18n = $c->stash->{i18n};
    my $roleOptions = [];
    my $roles= $c->model('LIXUZDB::LzRole');
    while(my $role = $roles->next)
    {
        push(@{$roleOptions}, {
                value => $role->role_id,
                label => $role->role_name,
            });
    }
    my $statusOptions = [
        {
            value => 'Active',
            label => $i18n->get('Active'),
        },
        {
            value => 'Inactive',
            label => $i18n->get('Inactive'),
        },
    ];
    $c->stash->{searchFilters} = [
        {
            name => $i18n->get('Role'),
            realname => 'role_id',
            options => $roleOptions,
            selected => defined $c->req->param('filter_role_id') ? $c->req->param('filter_role_id') : undef,
        },
        {
            name => $i18n->get('Status'),
            realname => 'user_status',
            options => $statusOptions,
            selected => defined $c->req->param('filter_user_status') ? $c->req->param('filter_user_status') : undef,
        },
    ];
}

# Purpose: Forward the user to the list view, and display a status message at the top of it
# Usage: $self->messageToList($c, MESSAGE);
sub messageToList
{
    my ($self, $c, $message) = @_;
    $c->flash->{ListMessage} = $message;
    if ($c->stash->{myAccountMode})
    {
        $c->response->redirect('/admin/dashboard');
    }
    else
    {
        $c->response->redirect('/admin/users');
    }
    $c->detach();
}

# Summary: Build a form with localized field labels and optionally pre-populated
# Usage: $self->buildform($c,'TYPE',\%Populate);
# 'TYPE' is one of:
# 	add => we're adding a user
# 	edit => we're editing an existing user
# \%Populate is a hashref in the form:
# 	fieldname => default value
# This will pre-populate fieldname with the value specified
sub buildform: Private
{
    my ( $self, $c, $type, $populate, $user_id ) = @_;
    my $form = $self->formbuilder;
    my $i18n = $c->stash->{i18n};
    $c->stash->{template} = 'adm/users/edit.html';
    my $fieldObj = LIXUZ::HelperModules::Fields->new($c,'users',$user_id);
    $fieldObj->editorInit();
    # Name mapping of field name => title
    my %NameMap = (
        firstname => $i18n->get('First name'),
        lastname => $i18n->get('Last name'),
        email => $i18n->get('E-mail'),
        user_name => $i18n->get('User name'),
        password => $i18n->get('Password'),
        role => $i18n->get('Role'),
        language => {
            label => $i18n->get('Language'),
            options => [
                'default',
                'nb_NO',
                'nn_NO',
                'en_US'
            ]
        },
        user_status => {
            label => $i18n->get('Status'),
            options => [
            $i18n->get('Active'),
            $i18n->get('Inactive'),
            ],
        },
    );
    # Set some context dependant settings
    if ($type eq 'add')
    {
        # We're creating a user
        $form->submit([$i18n->get('Create user')]);
        $c->stash->{pageTitle} = $i18n->get('Create user');
    }
    elsif ($type eq 'edit')
    {
        if ($c->stash->{myAccountMode})
        {
            $c->stash->{pageTitle} = $i18n->get('Edit account information');
        }
        else
        {
            $c->stash->{pageTitle} = $i18n->get_advanced('Editing user %(USER_ID)',{ USER_ID => $user_id});
        }
        # Editing a user
        $form->submit([$i18n->get('Save changes')]);
        # The password field is by default empty here, so change its label
        $NameMap{password} = $i18n->get('Change password to');
        # It's not possible to edit the username
        $form->field(
            name => 'user_name',
            disabled => 1,
        );
    }
    else
    {
        die("Got invalid type in Users.pm: $type");
    }
    # Add a hidden field with the type
    $form->field(
        name => 'type',
        value => $type,
    );
    $c->stash->{editType} = $type;
    # Query for roles
    my $roles = $c->model('LIXUZDB::LzRole')->search({role_status => 'Active'});
    my @roleList;
    if ($roles && $roles->count > 0)
    {
        while(my $role = $roles->next)
        {
            push(@roleList,$role->role_name);
        }
    }
    else
    {
        $self->messageToList($c,$i18n->get('You have not defined any roles. You need to add some roles before you can add a new user.'));
    }
    $form->field(
        name => 'role',
        options => \@roleList,
    );
    # Create a default population if it doesn't already exist
    if(not defined $populate)
    {
        $populate = {
            user_status => $i18n->get('Active'),
        };
    }
    # Set default role for a user if it exists
    else
    {
        if ($populate->{role} && ref($populate->{role}))
        {
            $populate->{role} = $populate->{role}->role_name;
        }
        else
        {
            $populate->{role} = $populate->{role};
        }
        if ($populate->{user_status})
        {
            $populate->{user_status} = $i18n->get($populate->{user_status});
        }
        if ($populate->{lang})
        {
            $populate->{language} = $populate->{lang};
        }
    }
    # Finally, add names as defined in the NameMap, and populate the
    # fields if possible
    finalize_form($form,$c,{
            fields => \%NameMap,
            fieldvalues => $populate,
        });
}

# Summary: Save form data
# Usage: $self->savedata($c,$form);
# Assumes that you have already checked $form->validate
sub savedata: Private
{
    my ( $self, $c, $form ) = @_;
    my $i18n = $c->stash->{i18n};
    my $fields = $form->fields;
    my $uid = $fields->{'uid'};
    my $type = $fields->{'type'};
    if ($c->stash->{myAccountMode})
    {
        $type = 'edit';
        $uid = $c->user->user_id;
        $fields->{role} = undef;
        $fields->{user_status} = undef;
    }
    my $user;
    if ($type eq 'edit')
    {
        $user = $c->model('LIXUZDB::LzUser')->find({user_id => $uid});
    }
    elsif($type eq 'add')
    {
        $user = $c->model('LIXUZDB::LzUser')->new_result(
            {
                created => \'now()',
            }
        );
    }
    else
    {
        die("Invalid type in Users.pm: $type");
    }
    foreach my $field (qw(firstname lastname user_name email))
    {
        if ($fields->{$field})
        {
            $user->set_column($field,$fields->{$field});
        }
    }
    if ($fields->{password})
    {
        if ($c->stash->{myAccountMode})
        {
            if(not $c->user->check_password($c->req->param('oldPassword')))
            {
                $self->redirWithError($c,$uid,
                    $c->stash->{i18n}->get('Your current password was incorrect'),
                );
            }
        }
        if(length($fields->{password}) < 5)
        {
            $self->redirWithError($c,$uid,
                $c->stash->{i18n}->get('Your new password is too short'),
                $c->stash->{i18n}->get('The new password is too short'),
                $c->stash->{i18n}->get('The password is too short'),
            );
        }
        $user->set_password($fields->{password});
    }
    if ($fields->{role})
    {
        my $role = $c->model('LIXUZDB::LzRole')->find({role_name => $fields->{role}});
        if ($role)
        {
            $user->set_column('role_id',$role->role_id);
        }
    }
    if ($fields->{user_status})
    {
        if ($fields->{user_status} eq $i18n->get('Inactive'))
        {
            $user->set_column('user_status','Inactive');
        }
        else
        {
            $user->set_column('user_status','Active');
        }
    }
    if(defined $fields->{language})
    {
        if ($fields->{language} =~ /^(en_US|nn_NO|nb_NO)$/)
        {
            $user->set_column('lang',$fields->{language});
        }
        else
        {
            $user->set_column('lang',undef);
        }
    }
    # Update the DB
    if($type eq 'add')
    {
        $user->insert;
    }
    else
    {
        $user->update();
    }
    # Save additional fields
    my $fieldObj = LIXUZ::HelperModules::Fields->new($c,'users',$user->user_id);
    $fieldObj->saveData();
    if ($c->stash->{myAccountMode})
    {
        $self->messageToList($c,'USER_DATA_SAVED');
    }
    else
    {
        $self->messageToList($c,$i18n->get('User data saved'));
    }
}

# Purpose: Handle creating a new user
sub add: Local Form('/users/edit') {
    my ( $self, $c, $invalid ) = @_;
    my $i18n = $c->stash->{i18n};
    my $form = $self->formbuilder;
    $c->stash->{madd}++;
    if ($form->submitted && $form->validate && !$invalid)
    {
        my $user_uid = $c->model('LIXUZDB::LzUser')->find({user_id => $form->fields->{uid}});
        my $user_name= $c->model('LIXUZDB::LzUser')->find({user_name => $form->fields->{user_name}});
        if ($user_name)
        {
            if (not $user_uid or $user_uid->get_column('user_id') != $user_name->get_column('user_id'))
            {
                $self->messageToList($c,$i18n->get_advanced('Error: A user with the username %(USERNAME) already exists (UID %(UID)).',{ USERNAME => $form->fields->{user_name}, UID => $user_name->get_column('user_id') }));
            }
        }
        $self->savedata($c,$form);
    }
    $self->buildform($c,'add',scalar $form->field);
    $c->{stash}->{template} = 'adm/users/edit/index.html';
}

# Purpose: Handle editing an existing user
sub edit: Args Local Form('/users/edit') {
    my ( $self, $c, $uid, $singleMode ) = @_;
    my $form = $self->formbuilder;
    # Username is not required here, it's just included for completeness
    $form->field(
        name => 'user_name',
        required => 0,
    );
    # Password isn't either
    $form->field(
        name => 'password',
        required => 0,
    );
    # UID is, however
    $form->field(
        name => 'uid',
        required => 1,
    );
    if ($c->stash->{myAccountMode})
    {
        $form->field(
            name => 'user_status',
            required => 0
        );
        $form->field(
            name => 'role',
            required => 0
        );
    }
    # Handle the form if it was submitted and validates
    if ($form->submitted && $form->validate && ! defined($c->stash->{message}))
    {
        $self->savedata($c,$form);
    }
    else
    {
        my $i18n = $c->stash->{i18n};
        # If we don't have an UID then just give up
        if (not defined $uid or $uid =~ /\D/) {
            $self->messageToList($c,$i18n->get('Error: Failed to locate UID. The path specified is invalid.'));
        } else {
            # Check if the user exists
            my $user = $c->model('LIXUZDB::LzUser')->find({user_id => $uid});
            if(not $user) {
                # Didn't exist, give up
                $self->messageToList($c,$i18n->get_advanced('Error: Failed to locate a user with the UID %(UID).', { UID => $uid }));
            } else {
                # Existed, generate our form and display it
                $form->field(
                    name => 'uid',
                    type => 'hidden',
                    value => $uid,
                );
                $self->buildform($c,'edit',$user->get_everything(),$uid);
            }
        }
        $c->{stash}->{template} = 'adm//users/edit/index.html';
    }
}

# Purpose: Delete a user (and get a confirmation from the user about it)
sub delete: Args Local
{
    my ( $self, $c, $uid ) = @_;
    my $i18n = $c->stash->{i18n};
    my $user;
    # If we don't have an UID then just give up
    if (not defined $uid or $uid =~ /\D/)
    {
        $self->messageToList($c,$i18n->get('Error: Failed to locate UID. The path specified is invalid.'));
    }
    else
    {
        $user = $c->model('LIXUZDB::LzUser')->find({user_id => $uid});
        # TODO: Maybe we should be using delete_all() ?
        $user->delete();
        $self->messageToList($c,$i18n->get('User deleted'));
    }
}

# Purpose: Helper function that redirects to the appropriate action with an
# error message
sub redirWithError : Private
{
    my($self,$c,$uid,$errorAcc, $errorEdit, $errorAdd) = @_;
    if ($c->stash->{myAccountMode})
    {
        $c->stash->{message} = $errorAcc;
        $c->detach(qw(LIXUZ::Controller::Admin::Users myaccount));
    }
    elsif(not defined $uid)
    {
        $c->stash->{message} = $errorAdd // $errorEdit;
        $c->detach(qw(LIXUZ::Controller::Admin::Users add), [ 1 ]);
    }
    else
    {
        $c->stash->{message} = $errorEdit;
        $c->detach(qw(LIXUZ::Controller::Admin::Users edit), [ $uid ]);
    }
}

# Purpose: Wrapper that lets users access their own "user edit"-page (with
# certain limitations)
sub myaccount : Path('/admin/myaccount')
{
    my($self,$c) = @_;
    $c->stash->{myAccountMode} = 1;
    return $c->forward(qw(LIXUZ::Controller::Admin::Users edit) , [ $c->user->user_id, 1 ]);
}

1;
