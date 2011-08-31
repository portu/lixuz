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

package LIXUZ::Role::AccessControl::ObjCache;
use Moose::Role;
with 'LIXUZ::Role::AccessControl::ObjCacheCkey';
use LIXUZ::HelperModules::Cache qw(CT_1H);

sub cache
{
    my $self = shift;
    my $object = shift;
    if (my $cached = $self->c->cache->get($self->ckey($object)))
    {
        return $cached;
    }
}

sub setCache
{
    my $self = shift;
    my $object = shift;
    my $value = shift;
    $self->c->cache->set($self->ckey($object), $value, CT_1H)
}

1;
