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

# LIXUZ::HelperModules::Widget
#
# This is a helper object for any dashboard widget. Any commonly
# used functionality a widget needs on the server side should be present
# here (ie. configuration).

package LIXUZ::HelperModules::Widget;
use warnings;
use strict;
use Carp;
use Scalar::Util qw(weaken);

# Summary: Create a new LIXUZ::HelperModules::Widget object
# Usage: $var = LIXUZ::HelperModules::Widget->new($c,'widgetName');
sub new
{
    my $Package = shift;
    my $self = {};
    bless($self,$Package);
    $self->{c} = shift;
    weaken $self->{c};
    $self->{name} = shift;
    $self->{confCache} = {};
    return $self;
}

# Summary: Set a configuration variable for the current widget
# Usage: $var->set_config($var,$value,$global);
#   Where $var is the variable name, $value is its value, and $global
#   defines if it is a global setting, or local to the current user.
# OR
#   $var->set_config(\%hashRef);  (to set multiple values at once).
#   The hashRef is in the following form:
#   {
#       variable_name => value,
#   }
#       or
#   {
#       variable_name => {
#           value => the_value,
#           global => bool - same as $global,
#       }
#   }
#
# If a setting is set to undef, it will be deleted from the database.
# Note that if you set the local users setting to undef and there is a
# global setting, get_config will return the global setting.
sub set_config
{
    my $self = shift;
    my ($var,$value,$global) = @_;
    if(not ref($var))
    {
        return $self->_set_config(@_);
    }

    my $ret = 1;
    foreach my $k (keys(%{$var}))
    {
        if(ref($var->{$k}))
        {
            my $v = $var->{$k};
            if (not $self->_set_config($k,$v->{value},$v->{global}))
            {
                $ret = 0;
            }
        }
        else
        {
            if (not $self->_set_config($k,$var->{$k},0))
            {
                $ret = 0;
            }
        }
    }
    return $ret;
}

# Summary: Get a configuration variable for the current widget.
#   It will fetch the current users config if it is present, if not
#   it will fetch the global setting. If no setting is present it
#   will return undef.
# Usage: $value = $var->get_config('variable_name',ONLY_GLOBAL?);
#   If ONLY_GLOBAL is true then user-specific settings are ignored.
sub get_config
{
    my $self = shift;
    my $var = shift;
    my $only_global = shift(@_) ? 1 : 0;
    my $c = $self->{c};
    # First, try the user one
    my $value;
    if(not $only_global)
    {
        $value = $c->model('LIXUZDB::LzWidgetConfig')->find({
                widget_name => $self->{name},
                config_user => $c->user->user_id,
                config_name => $var,
                global => 0,
            }, { columns => ['config_value'] });
        if ($value)
        {
            return $value->config_value;
        }
    }
    $value = $c->model('LIXUZDB::LzWidgetConfig')->find({
            widget_name => $self->{name},
            config_name => $var,
            global => 1,
        }, { columns => ['config_value'] });
    if ($value)
    {
        return $value->config_value;
    }
    return;
}

# Summary: This is the same as the above, except that if no setting is
#   found (neither global nor local) then it will return $default instead
#   of undef. Use this if you've got to have a value.
# Usage: $value = $var->get_config_or('variable_name',$default);
sub get_config_or
{
    my $self = shift;
    my $var = shift;
    my $default = shift;
    my $c = $self->{c};

    my $value = $self->get_config($var);
    if(not defined $value)
    {
        return $default;
    }
    return $value;
}

# Summary: Get all configuration values for the current widget in a
#   hashref. The hashref will contain the local users setting, if any,
#   if not it will contain the global setting. Only settings that has
#   a value will be returned.
# Usage: $hashRef = $var->get_all_config();
sub get_all_config
{
    my $self = shift;
    my $c = $self->{c};
    my %config;
    my %hasLocal;

    my $values = $c->model('LIXUZDB::LzWidgetConfig')->find({
            widget_name => $self->{name},
            -or => [
            {global => 1 },
            {config_user => $c->user->user_id},
            ],
        }, { columns => ['config_value','config_name','global']});
    return \%config if not $values;
    while(my $val = $values->next)
    {
        if (not $val->global)
        {
            $config{$val->config_name} = $val->config_value;
            $hasLocal{$val->config_name} = 1;
        }
        elsif(not $hasLocal{$val->config_name})
        {
            $config{$val->config_name} = $val->config_value;
        }
    }
    return \%config;
}

# Summary: This is the internal worker method that sets a config variable.
#   It is called by set_config once for each setting that is to be set.
# Usage. The same as the first form of set_config();
sub _set_config
{
    my ($self,$var,$value,$global) = @_;
    my $c = $self->{c};

    my $find = {
            widget_name => $self->{name},
            config_name => $var,
    };
    if ($global)
    {
        $find->{global} = 1;
    }
    else
    {
        $find->{global} = 0;
        $find->{config_user} = $c->user->user_id;
    }

    my $conf = $c->model('LIXUZDB::LzWidgetConfig')->find_or_create($find);
    if(not defined $value)
    {
        return $conf->delete;
    }
    $conf->set_column('config_value',$value);
    return $conf->update();
}

1;
