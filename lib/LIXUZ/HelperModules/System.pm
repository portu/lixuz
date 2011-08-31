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

# Varous 'system'-related wrappers (ie. wrappers around core perl functions)
package LIXUZ::HelperModules::System;

use strict;
use warnings;
use Exporter qw(import);
our @EXPORT_OK = qw(silentSystem);

# Summary: A system that silences its command without using sh.
# It is a safe 100% system() syntax compatible replacement for
# doing system('ls -lh 2>&1 >/dev/null') (which uses the shell to silence the
# command and is in no way safe)
sub silentSystem
{
    no warnings 'once';
    open(SOUT,">&STDOUT");
    open(SERR,">&STDERR");
    open(STDOUT,'>','/dev/null');
    open(STDERR,'>','/dev/null');
    my $ret = system(@_);
    open(STDOUT,">&SOUT");
    open(STDERR,">&SERR");
    return $ret;
}   
