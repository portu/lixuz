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

package LIXUZ::Role::AccessControl;

use Moose::Role;
use LIXUZ::HelperModules::Cache qw(get_ckey);

has '_ACL_CACHE_EXPIRY' => (
    is => 'ro',
    isa => 'Int',
    default => 600,
);

has 'c' => (
    is => 'rw',
    weak_ref => 1,
    isa => 'Ref',
    required => 1,
    writer => '_set_c',
);

has 'roleId' => (
    is => 'rw',
    isa => 'Int',
    required => 0,
    lazy => 1,
    default => sub {
        my $self = shift;
        return $self->c->user->role_id;
    },
);

has 'userId' => (
    is => 'rw',
    isa => 'Int',
    required => 0,
    lazy => 1,
    default => sub {
        my $self = shift;
        return $self->c->user->user_id;
    },
);

1;
