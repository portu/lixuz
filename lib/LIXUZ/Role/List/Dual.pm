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

# This class provides a version of the list role that will search both the
# normal indexer as well as the database for a query, if the indexer returned
# fewer than 200 results. This allows more useful results for queries for
# partial words.

package LIXUZ::Role::List::Dual;

use Moose::Role;
use 5.010;
use LIXUZ::HelperModules::List::Dual;

with 'LIXUZ::Role::List';

has '_lResultObject' => (
    is => 'rw',
    );
sub listType
{
    return 'dual';
}

1;
