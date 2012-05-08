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

# LIXUZ::HelperModules::Files
#         
# SYNOPSIS:
# use LIXUZ::HelperModules::Files qw(lixuz_serve_static_file get_new_aspect fileId fileFolder fileLastInFolder fileByColumn);
#
# This module contains functions that assists with forms, as well as functions for retrieving file object data
#         
# It exports nothing by default, you need to explicitly import the
# functions you want.
#             
# Borrows code from Catalyst::Plugin::Static::Simple, as well as monitorgrowth, and thus licensed:
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of either:
# 
#    a) the GNU Lesser General Public License as published by the Free
#    Software Foundation; either version 3, or (at your option) any
#    later version, or
#    b) the "Artistic License" which comes with this Kit.
#    c) the same terms as Perl itself
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See either
# the GNU Lesser General Public License or the Artistic License for more details.
#
# You should have received a copy of the Artistic License
# in the file named "COPYING.artistic".  If not, I'll be glad to provide one.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this program in a file named COPYING.lgpl. 
# If not, see <http://www.gnu.org/licenses/>.
#

package LIXUZ::HelperModules::Files;

use strict;
use warnings;
use Exporter qw(import);
use File::stat;
use IO::File ();
use LIXUZ::HelperModules::Cache qw(get_ckey CT_24H);
use Carp qw(croak);

our @EXPORT_OK = qw(lixuz_serve_static_file lixuz_serve_scalar_file get_new_aspect fsize);

# Purpose: Serve a static file, lixuz version of Catalyst::Plugin::Static::Simple->serve_static_file
# Usage: lixuz_serve_static_file($c,path,type);
# type is the mimetype, it is semi-optional, if not supplied LIXUZ will
# use application/octet-stream as the mimetype
sub lixuz_serve_static_file
{
    my $c = shift;

    my $full_path = shift;
    my $type      = shift;
    my $info;
    my $ckey = get_ckey('file','info',$full_path);
    if(not $info = $c->cache->get($ckey))
    {
        my $stat      = stat $full_path;
        $info->{size} = $stat->size;
        $info->{mtime} = $stat->mtime;
        if(not $type)
        {
            $type = 'application/octet-stream';
        }
        $info->{type} = $type;
        if ($ckey)
        {
            $c->cache->set($ckey,$info,CT_24H);
        }
    }

    $c->res->headers->content_type( $info->{type} );
    $c->res->headers->content_length( $info->{size} );
    $c->res->headers->last_modified( $info->{mtime} );

    # new method, pass an IO::File object to body
    my $fh = IO::File->new( $full_path, 'r' );
    if ( defined $fh ) {
        binmode $fh;
        $c->res->body( $fh );
    }
    else {
        Catalyst::Exception->throw( 
            message => "Unable to open $full_path for reading" );
    }
    return 1;
}

# Purpose: Serve a scalar as a file
# Usage: lixuz_serve_scalar_file($c,data,mimetype);
sub lixuz_serve_scalar_file
{
    my ($c,$data,$mimetype) = @_;
    $c->res->headers->expires(0);
	$c->res->headers->content_type($mimetype);
	use bytes;
	$c->res->headers->content_length(length($data));
	no bytes;
	open(my $out, '<',\$data);
    binmode($out);
	$c->res->body($out);
	$c->detach();
	return;
}

# Purpose: Recalculate the aspect ratio of a image
# Usage: new_XY = get_new_aspect(oldWidth, oldHeight, newWidth, newHeight);
# Only supply one of newHeight and newWidth (make the other undef)
# Returns the new width or height, keeping the aspect ratio
sub get_new_aspect
{
    my($oldWidth, $oldHeight, $newWidth, $newHeight) = @_;
    my $percentage_change;
    my $oldVal;
    my $newVal;
    my $changeVal;
    if ($newWidth)
    {
        $oldVal = $oldWidth;
        $newVal = $newWidth;
        $changeVal = $oldHeight;
    }
    else
    {
        $oldVal = $oldHeight;
        $newVal = $newHeight;
        $changeVal = $oldWidth;
    }
    if ((not defined $oldVal or $oldVal == 0) || (not defined $newVal or $newVal == 0))
    {
        croak("oldVal or newVal is zero");
    }
    $percentage_change = $oldVal/$newVal;
    if ($changeVal == 0 || $percentage_change == 0)
    {
        croak("changeVal or percentage_change is zero");
    }
    return sprintf('%d',$changeVal / $percentage_change );
}

# Purpose: Get the total file size and the type.
# Usage: my($s, $t) = fsize(size);
#  $t is MB, KB or B
#  $s is the size in $t rounded to the nearest integer
sub fsize
{   
    # The size
    my $size = shift;
    # The type it is
    my $type = 'B';
    # If it is above 1024 then convert to KB
    if ($size > 1_024)
    {   
        $size = $size / 1_024;
        # If it is above 1024 still, convert to MB
        if ($size > 1_024)
        {   
            $size = $size / 1_024;
            $type = 'MB';
        }
        else
        {   
            $type = 'KB';
        }
    }
    # Round it off to the closest integer
    $size = int($size + .5);
    # Return it
    return($size,$type);
}

# Summary: Helper method. Turs resultset into array
# Usage: [array of objects] = &to_Array( RESULTSET, #LIMIT );
# Returns: A reference to an array of objects 
sub _toArray {
    my ( $rs, $limit ) = @_;
    $limit = -1 if ! defined $limit;
    my @array = ();
    while ( $limit-- && ( my $LzFile=$rs->next() ) ) {
        push @array, $LzFile;
    } 
    return \@array;
}
1;
