# LIXUZ content management system
# Copyright (C) Utrop A/S Portu media & Communications 2013
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

package LIXUZ::Role::Configurable;
use Moose::Role;
use Config::Any;
requires '_configFile';

sub config
{
    my $self = shift;
    my $file = $self->_configFile;
    my $c    = $self->c or die('Failed to get self->c');
    my $ckey = '_l_role_conf_'.$file;
    if(my $data = $c->cache->get($ckey))
    {
        return $data;
    }
    my $data = Config::Any->load_files({ files => [ $file ], use_ext => 1});
    $data = $data->[0]->{$file};
    $c->cache->set($ckey,$data);
    return $data;
}

1;
