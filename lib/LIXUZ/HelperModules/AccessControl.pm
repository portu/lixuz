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

# LIXUZ::HelperModules::AccessControl
# 
# This module assists in access control of logged in users, making
# sure that they are allowed to access the path or perform the action that
# they are attempting to perform.
#
# Usually, you don't want to use this object directly, but rather use the
# various methods on LzUser.
package LIXUZ::HelperModules::AccessControl;

use Moose;
use Carp;
use LIXUZ::HelperModules::Cache qw(get_ckey);
use constant {
    true => 1,
    false => 0,
};

with 'LIXUZ::Role::AccessControl';

has 'lastDenied' => (
    is => 'rw',
    isa => 'Str',
    required => 0,
);

has 'deniedOnce' => (
    is => 'rw',
    isa => 'Bool',
    default => 0,
);

# Summary: Check if the user is allowed to access or alter something.
# Usage: boolean = obj->can_access_path(resource?);
# If resource is undef then it will check the catalyst object to find out
# the currently requested path.
sub can_access_path
{
    my $self = shift;
    my $action = shift;
    $action = $action ? $action : $self->_getRequestedAction();
    my $can_access_path = $self->_recursiveCheck($action);
    if(not $can_access_path)
    {
        if ($self->_recursiveCheck('SUPER_USER'))
        {
            return true;
        }
    }
    return $can_access_path;
}

sub can_access_object
{
    my $self = shift;
    my $objectType = shift;
    my $objectId = shift;
}

# Summary: Check if the user is allowed to access or alter something, and
#   forward to the ACL controller's access_denied method if not.
# Usage: Same as can_access_path() but never returns if access is denied.
sub check_access
{
    my $self = shift;
    if (not $self->can_access_path(@_))
    {
        $self->access_denied();
    }
    return true;
}

# Summary: Deny access to whatever was requested
# Usage: object->access_denied();
# Use this if you want to deny access to something but did the test
# manually.
sub access_denied
{
    my $self = shift;
    my $c = $self->c;
    if ($self->deniedOnce)
    {
        die('access_denied() loop detected');
    }
    $self->deniedOnce(1);
    $c->detach('LIXUZ::Controller::Admin::ACL','access_denied');
    die('access_denied() got to end of function');
}

# Summary: Return the URL that was last denied access to, or undef
sub last_denied
{
    my $self = shift;
    if ($self->lastDenied)
    {
        return $self->lastDenied;
    }
    else
    {
        return undef;
    }
}

# --- INTERNAL METHODS ---

# Purpose: Add a last_denied entry to ourselves to report later if needed, and ignore SUPER_USER
# Usage: $self->_add_last_denied(PATH);
sub _add_last_denied
{
    my $self = shift;
    my $path = shift;
    if(not $path eq 'SUPER_USER')
    {
        $self->lastDenied($path);
    }
}

# Summary: Get the requested action from the catalyst object, used when
#   the parameter to can_access_path is undef.
# Returns: Path to action requested
# Usage: path = $self->_getRequestedAction();
sub _getRequestedAction
{
    my $self = shift;
    return $self->c->action->reverse;
}

# Summary: Do a recursive check of all elements of the path to see if the user
#   is allowed to access them.
# Usage: boolean = $self->_recursiveCheck($path);
sub _recursiveCheck
{
    my $self = shift;
    my $action = shift;

    if (_testIgnore($action))
    {
        return true;
    }
    if(not $action =~ s#/+#/#g)
    {
        return $self->_singleCheck($action);
    }
    my $path = '';
    my $firstLoop = 1;
    foreach my $part (split(m#/+#,$action))
    {
        $part =~ tr/[A-Z]/[a-z]/;
        if (_testIgnore($part))
        {
            next;
        }
        if ($firstLoop)
        {
            next if $part eq 'admin';
        }
        $firstLoop = 0;
        $path .= '/'.$part;
        if(not $self->_singleCheck($path))
        {
            return false;
        }
    }
    return true;
}

# Purpose: Check if we should ignore a value
# Usage: _testIgnore(value)
# Returns true if it should be ignored, false otherwise
sub _testIgnore
{
    my $test = shift;
    if ( ($test eq '') or ($test eq 'index') or ($test eq 'default') or ($test eq 'login') or ($test eq 'forget')   or ($test eq 'admin/users/myaccount') )
    {
        return true;
    }
    return false;
}

# Summary: Check if the user is allowed to access the path supplied
# Usage: boolean = $self->_singleCheck($path);
sub _singleCheck
{
    my $self = shift;
    my $check = shift;
    my $c = $self->c;
    my $return = false;
    my $ckey = get_ckey('rolePerms',$check,$self->roleId);

    if (defined (my $cached = $c->cache->get($ckey)))
    {
        $return = $cached;
    }
    # XXX: Temporary hack
    elsif($check =~ /memcached/ || $check =~ m#/settings/admin/info#)
    {
        $return = false;
    }
    else
    {
        # Fetch the role_id
        my $roleid = $self->roleId;
        # Fetch the action id
        my $actionId = $c->model('LIXUZDB::LzAction')->find({action_path => $check });
        if(not $actionId)
        {
            $c->log->error('Failed to look up LzAction object for '.$check.'. Denying access.');
            $return = false;
        }
        elsif(my $actionInfo = $c->model('LIXUZDB::LzRoleAction')->find({role_id => $roleid, action_id => $actionId->action_id}))
        {
            if ($actionInfo->allowed)
            {
                $return = true;
            }
        }
        $c->cache->set($ckey, $return, $self->_ACL_CACHE_EXPIRY);
    }
    if (not $return)
    {
        $self->_add_last_denied($check);
    }
    return $return;
}

__PACKAGE__->meta->make_immutable;
1;
