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

package LIXUZ::Controller::Admin::Files::ImgEdit;

use strict;
use warnings;
use 5.010;

use Moose;
BEGIN { extends 'Catalyst::Controller' };

use LIXUZ::HelperModules::Includes qw(add_jsIncl add_cssIncl add_jsOnLoad add_bodyClass add_CDNload);
use Graphics::Magick;
use LIXUZ::HelperModules::Files qw(lixuz_serve_scalar_file);
use LIXUZ::HelperModules::JSON qw(json_response json_error);

sub default : Path('/admin/files/imgedit') Local Args
{
    my ( $self, $c, $uid ) = @_;

    my $file = $self->_getFileFromUID($c,$uid);
    my $i18n = $c->stash->{i18n};
    add_jsIncl($c,'files.js');
    add_jsOnLoad($c,'initCrop');
    add_CDNload($c,'YUI');
    # We need toe YUI sam skin
    add_cssIncl($c,'yui/sam-skin.css');
    # Body class
    add_bodyClass($c,'yui-skin-sam');

    $c->stash->{image} = $file;
    $c->stash->{template} = 'adm/files/cropping.html';
}

sub resizer : Local Args
{
    my ( $self, $c, $uid ) = @_;
    my $file = $self->_getFileFromUID($c,$uid);
    my $gm = $self->_getResized($c,$file);
    my $blob = $gm->ImageToBlob();
    $c->res->header('Expires' => 'Fri, 30 Oct 1998 14:19:41 GMT');
    lixuz_serve_scalar_file($c, $blob,$file->get_mimetype($c));
}

sub saveCrop : Local
{
    my ( $self, $c, $uid ) = @_;
    my $file = $self->_getFileFromUID($c,$uid);
    my $gm = $self->_getResized($c,$file);
    my $blob = $gm->ImageToBlob();

    my $fUploader = LIXUZ::HelperModules::FileUploader->new(c => $c);
    my ($newFile,$error) = $fUploader->upload($file->file_name,$blob,{ file_folder => $file->folder_id, class_id => $file->class_id } );
    if ($error)
    {
        die($error->{system});
    }
    # Default is to be a clone of our parent, however that can be
    # changed to our parents' clone value later if parent has one.
    $newFile->set_column('clone',$file->file_id);
    # Copy some values from $file to $newFile
    foreach my $vnam (qw(title caption status clone))
    {
        if(defined $file->get_column($vnam))
        {
            my $v = $file->get_column($vnam);
            $newFile->set_column($vnam,$v);
        }
    }
    $newFile->update();
    # Copy additional field values from $file to $newFile, if any are present
    my $values = $file->getAllFields($c);
    foreach my $field (keys %{$values})
    {
        $c->model('LIXUZDB::LzFieldValue')->create({
                module_id => $newFile->file_id,
                module_name => 'files',
                field_id => $field,
                value => $values->{$field},
            });
    }
    return json_response($c,{ newFile => $newFile->file_id });
}

sub _getFileFromUID : Private
{
    my ( $self, $c, $uid ) = @_;

    if(not defined $uid or not length $uid)
    {
        # Error
        die;
    }

    my $file = $c->model('LIXUZDB::LzFile')->find({ file_id => $uid});

    if (not $file)
    {
        # Error
        die;
    }
    elsif(not $file->is_image)
    {
        # Error
        die;
    }

    return $file;
}

sub _getResized : Private
{
    my ( $self, $c, $file ) = @_;
    my $gm = Graphics::Magick->new;
    $gm->Read($file->get_path($c));
    my $left = $c->req->param('left');
    my $top = $c->req->param('top');
    my $width = $c->req->param('width');
    my $height = $c->req->param('height');
    $gm->Crop(x => $left, y => $top, width => $width, height => $height);
    $gm->Set('page' => $height.'x'.$width);
    return $gm;
}

1;
