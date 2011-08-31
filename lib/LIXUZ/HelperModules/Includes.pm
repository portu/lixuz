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

# LIXUZ::HelperModules::Includes
package LIXUZ::HelperModules::Includes;
use strict;
use warnings;
use Carp;
use Exporter qw(import);
use List::MoreUtils qw(any);
our @EXPORT_OK = qw(add_jsIncl add_cssIncl add_masonHeaderIncl add_globalJSVar add_bodyClass add_jsOnLoad add_jsHeadCode add_jsOnLoadHeadCode add_CDNload);

sub add_jsIncl
{
    my $c = shift;
    die('useless use of add_jsIncl without any parameters, maybe you forgot $c?') if not @_;
    foreach my $file (@_)
    {
        if (substr($file,0,1) eq '/')
        {
            _addIncl($c,$file,'jsIncl');
        }
        else
        {
            _addIncl($c, '/js/'.$file, 'jsIncl');
        }
    }
}

sub add_cssIncl
{
    my $c = shift;
    die('useless use of add_cssIncl without any parameters, maybe you forgot $c?') if not @_;
    foreach my $file (@_)
    {
        if (substr($file,0,1) eq '/')
        {
            _addIncl($c,$file,'cssIncl');
        }
        else
        {
            _addIncl($c, '/css/'.$file, 'cssIncl');
        }
    }
}

sub add_jsOnLoad
{
    my $c = shift;
    die('useless use of add_jsOnLoad without any parameters, maybe you forgot $c?') if not @_;
    foreach my $func (@_)
    {
        _addIncl($c,$func,'jsOnLoad',1);
    }
}

sub add_jsHeadCode
{
    my $c = shift;
    die('useless use of add_jsHeadCode without any parameters, maybe you forgot $c?') if not @_;
    foreach my $snippet (@_)
    {
        _addIncl($c,$snippet,'jsHeadCode',1);
    }
}

sub add_jsOnLoadHeadCode
{
    my $c = shift;
    die('useless use of add_jsOnLoadHeadCode without any parameters, maybe you forgot $c?') if not @_;
    foreach my $snippet (@_)
    {
        _addIncl($c,$snippet,'jsOnLoadHeadCode',1);
    }
}

sub add_CDNload
{
    my $c = shift;
    die('useless use of add_CDNload without any parameters, maybe you forgot $c?') if not @_;
    foreach my $CDNL (@_)
    {
        $c->stash->{CDNLoadParams} //= {};
        $c->stash->{CDNLoadParams}->{$CDNL} = 1;
    }
}

sub add_masonHeaderIncl
{
    my $c = shift;
    die('useless use of add_masonHeaderIncl without any parameters, maybe you forgot $c?') if not @_;
    foreach my $file (@_)
    {
        _addIncl($c,$file,'masonHeaderIncl');
    }
}

sub add_globalJSVar
{
    my ($c, $var, $value) = @_;
    die('useless use of add_globalJSVar without any parameters, maybe you forgot $c?') if not @_;
    if(not $c->stash->{jsvar})
    {
        $c->stash->{jsvar} = {};
    }
    if(not $c->stash->{jsvar}->{$var})
    {
        $c->stash->{jsvar}->{$var} = $value;
    }
    return;
}

sub add_bodyClass
{
    my ($c, $class) = @_;
    die('useless use of add_bodyClass without any parameters, maybe you forgot $c?') if not @_;
    _addIncl($c,$class,'bodyclass',1);
    return;
}

sub _addIncl
{
    my ($c, $file, $incl, $notFile) = @_;
    if(not ref($c))
    {
        die('Adding include '.$incl.' failed, $c was not given, or invalid');
    }
    if (! $notFile)
    {
        $file = $c->uri_for($file);
    }
    if(not defined $c->stash->{$incl})
    {
        $c->stash->{$incl} = [];
    }
    else
    {
        if(any { $_ eq $file } @{$c->stash->{$incl}})
        {
            return;
        }
    }
    push(@{$c->stash->{$incl}},$file);
}
1;
