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

# This role can be applied to controllers that need to return lists to users.
# It can generate the lists in DBIC, Indexer result, JSON or basic HTML, and
# even handle the request completely by returning the data itself.
#
# In practically all cases you will want to apply one of the two submodules
# to your controller, rather than applying this list. ::Database and ::Indexer
package LIXUZ::Role::List;

use Moose::Role;
use 5.010;
use Carp qw(croak);

sub handleListRequest
{
    my $self    = shift;
    my $c       = shift;
    my $options = shift;
    return $self->getListHelper($c,$options)->handleListRequest();
}

sub getListHelper
{
    my $self    = shift;
    my $c       = shift;
    my $options = shift;

    if(ref($c) ne 'LIXUZ')
    {
        croak('$c missing');
    }

    $options //= {};
    $options->{c} = $c;

    if ($self->can('formbuilder'))
    {
        $options->{formbuilder} = $self->formbuilder;
    }

    given($self->listType)
    {
        when('database')
        {
            return LIXUZ::HelperModules::List::Database->new(%{$options});
        }

        when('indexer')
        {
            return LIXUZ::HelperModules::List::Indexer->new(%{$options});
        }

        when('dual')
        {
            return LIXUZ::HelperModules::List::Dual->new(%{$options});
        }

        default
        {
            croak('LIXUZ::Role::List should not be consumed directly');
        }
    }
}

sub messageToList
{
    my ($self, $c, $message) = @_;
    $c->flash->{ListMessage} = $message;
    if(not $message)
    {   
        $c->log->warn('No valid message supplied to messageToList in '.ref($self));
    }
    $c->response->redirect($c->uri_for($self->action_for('index')));
    $c->detach();
}

1;
