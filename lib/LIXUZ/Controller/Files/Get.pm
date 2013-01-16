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

package LIXUZ::Controller::Files::Get;

use strict;
use warnings;
use base qw(Catalyst::Controller::FormBuilder);
use LIXUZ::HelperModules::Files qw(lixuz_serve_static_file lixuz_serve_scalar_file);
use LIXUZ::HelperModules::Live::CAPTCHA qw(serve_captcha);

# Summary: Retrieve a captcha
sub captcha : Path(/files/captcha)
{
    my ( $self, $c, $uid ) = @_;
    my ($data, $mimetype) = serve_captcha($c,$uid);
    lixuz_serve_scalar_file($c,$data,$mimetype);
}

# Summary: Retrieve a file if possible
sub default : Path(/files/get)
{
    my ( $self, $c, $uid ) = @_;
    my $i18n = $c->stash->{i18n};
    my $filePath;
    my $file;
    # If we don't have an UID then just give up
    if(not defined $uid)
    {
        $c->log->error('Invalid (empty) identifier supplied to /files/get');
        $self->error($c);
    }
    if ($uid =~ /\D/)
    {
        $file = $c->model('LIXUZDB::LzFile')->find({ identifier => $uid });
    }
    else
    {
        # TODO: This is compat code (files_compat). It should be purged when we have a script to upgrade article bodies.
        if (not $c->config->{LIXUZ}->{files_compat})
        {
            $c->log->error('Numeric identifier supplied to /files/get ("'.$uid.'") but files_compat is false');
            $self->error($c);
        }
        else
        {
            $file = $c->model('LIXUZDB::LzFile')->find({ file_id=> $uid });
        }
    }
    if ( (not defined $file) || ($file->status ne 'Active') )
    {
        my $invalid = 0;
        # FIXME: We should forward to a method that creates the ACL object if we have a user
        if(not $c->user || not defined $c->stash->{ACL} || not (defined $c->stash->{ACL} and $c->stash->{ACL}->can_access('/files')))
        {
            $invalid = 1;
        }
        elsif(not defined $file)
        {
            $invalid = 1;
        }
        if ($invalid)
        {
            my $addInfo = '';
            eval
            {
                if ($c->req->referer)
                {
                    $addInfo = ' Referer was '.$c->req->referer.'.';
                }
            };
            if (not $file)
            {
                $c->log->info('Invalid file requested (file id => '.$uid.' not found in database).'.$addInfo);
            }
            else
            {
                $c->log->info('Inactive file requested (file id => '.$uid.')'.$addInfo);
            }
            $self->error($c);
        }
    }
    if ($c->req->param('width') || $c->req->param('height') || $c->req->param('viewable'))
    {
        $filePath = $self->get_image($c,$file);
    }
    elsif($file->is_video())
    {
        $filePath = $self->get_video($c,$file);
    }
    else
    {
        $filePath = $file->get_path($c);
    }
    if(not $filePath or not -r $filePath)
    {
        $c->log->error('Requested file with UID '.$uid.': Object existed and was active in the database but on-disk file was not found!');
        $self->error($c);
    }
    lixuz_serve_static_file($c,$filePath, $file->get_mimetype($c,$c->req->param('viewable')));
}

# Summary: Handle the different requests for videos (flv, preview, ..)
sub get_video: Private
{
    my ( $self, $c, $file) = @_;
    if(not $c->req->param('flv') and not $c->req->param('flvpreview'))
    {
        if(not $c->user or not $c->user->can_access('/admin/files/'))
        {
            $self->error($c);
        }
        return $file->get_path($c);
    }
    elsif($c->req->param('flv'))
    {
        return $file->get_flv_path($c);
    }
    elsif($c->req->param('flvpreview'))
    {
        return $file->get_flv_preview_path($c);
    }
    die;
}

# Summary: Handle the different requests for images (resize, original)
sub get_image: Private
{
    my ( $self, $c, $file) = @_;
    my $width = $c->req->param('width');
    my $height = $c->req->param('height');
    my $forceViewable = $c->req->param('viewable');
    if ($file->is_image)
    {
        return $file->get_resized($c, $height, $width,$forceViewable);
    }
    else
    {
        my $message = 'Non-image (file '.$file->file_id.') requested with ';
        if (defined $width)
        {
            $message .= 'width['.$width.'] ';
        }
        if(defined $height)
        {
            $message .= 'height['.$height.'] ';
        }
        if ($c->req->referer)
        {
            $message .= 'referer was '.$c->req->referer;
        }
        $c->log->error($message);
        $self->error($c);
    }
}

# Summary: Display an error
sub error : Private
{
    my ( $self, $c ) = @_;
    my $renderer = LIXUZ::HelperModules::TemplateRenderer->new(c => $c);
    $renderer->error(404);
}

1;
