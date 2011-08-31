#!/usr/bin/perl
# masontest - a quick implementation of a perl -c -like command for Mason.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version. See <http://www.gnu.org/licenses/>.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the

use strict;
use warnings;
use HTML::Mason;
use HTML::Mason::Interp;
use Fatal qw(open);
use File::Basename qw(dirname);
use Cwd qw(abs_path);
use constant { true => 1, false => undef };

my ($root, $file);

if (scalar @ARGV == 1)
{
	$file = shift(@ARGV);
	$root = abs_path(dirname($file));
}
elsif (scalar @ARGV == 0)
{
	die("Usage: $0 [COMPONENT_ROOT] [FILE]\n or \n       $0 [FILE]\n");
}
else
{
	$root = shift(@ARGV);
	$file = shift(@ARGV);
}

if(not -e $file)
{
	die("$file: does not exist\n");
}
elsif(not -d $root)
{
	die("$root: does not exist or is not a directory\n");
}

my $interp = HTML::Mason::Interp->new(
	comp_root => $root,
	autohandler_name => $root.'/autohandler',
);
my $scomp;
{
	local $/ = undef;
	open(my $fh, '<',$file);
	$scomp = <$fh>;
	close($fh);
}
my $declarevars ='my $r; my $c;';
# Ensure that variables we need are declared
if ($scomp =~ /<%once>/)
{
	$scomp =~ s/<%once>/<%once>\n$declarevars/;
}
else
{
	$scomp .= '<%once>'.$declarevars.'</%once>';
}
# Make an anonymous component
my $anon_comp = eval { 
	$interp->make_component (  	comp_source => $scomp )
};
my $err = $@;
if ($err)
{
	$err =~ s/<anonymous component>/$file/g;
	$err =~ s/\(eval \d+\)( has too many errors)/$file$1/gi;
	die($err);
}
print $file.' syntax OK'."\n";