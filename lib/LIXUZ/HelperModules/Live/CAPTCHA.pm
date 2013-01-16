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

# LIXUZ::HelperModules::Live::CAPTCHA
# 
package LIXUZ::HelperModules::Live::CAPTCHA;

use strict;
use warnings;
use Carp;
use Graphics::Magick;
use Exporter qw(import);
our @EXPORT_OK = qw(get_captcha serve_captcha validate_captcha);
use constant {
    true => 1,
    false => 0,
    CAPTCHA_LENGTH => 6,
};

# Summary: Get a captcha
# Usage: my($captcha_id) = get_captcha($c);
sub get_captcha
{
    my($c) = @_;
    my $captcha = _generate_captcha();
    my $id = $c->model('LIXUZDB::LzLiveCaptcha')->create({captcha => $captcha});
    return $id->captcha_id;
}

# Summary: Serve a captcha
# Usage: my($captcha_data,$mimetype) = serve_captcha($c,captcha_id);
sub serve_captcha
{
    my($c,$captcha_id) = @_;
    my $val = $c->model('LIXUZDB::LzLiveCaptcha')->find({captcha_id => $captcha_id});
    if(not $val)
    {
        $val = 'ERROR (1)';
    }
    else
    {
        if(not $val = $val->captcha)
        {
            $val = 'ERROR (2)';
        }
    }
    my $magick = Graphics::Magick->new(magick => 'png');
    $magick->Read('null:white');
    $magick->Scale(
        height => 40,
        width => 110,
    );
    $magick->Set('magick' => 'png');
    $magick->Annotate(
        text => $val,
        geometry => '+4+0',
        font => $LIXUZ::PATH.'/data/StayPuft.ttf',
        fill => 'black',
        gravity => 'West',
        #pointsize => 20,
        pointsize => 26,
    );
    $magick->AddNoise(noise => 'Gaussian');
    $magick->AddNoise(noise => 'Impulse');
    my $image_data = $magick->ImageToBlob;
    if(not defined $image_data)
    {
        $c->log->error('ImageToBlob returned undef, captcha broken');
    }
    # Explicitly destroy Graphics::Magick
    undef $magick;
    return($image_data,'image/png');
}

# Summary: Validate a captcha
# Usage: boolean = validate_captcha($c,captcha_id,value);
sub validate_captcha
{
    my($c,$captcha_id,$value) = @_;
    if(not defined $value or not (length $value == CAPTCHA_LENGTH))
    {
        return false;
    }
    if(not defined $captcha_id or not length $captcha_id)
    {
        return false;
    }
    my $capt = $c->model('LIXUZDB::LzLiveCaptcha')->find({captcha_id => $captcha_id});
    if(not $capt)
    {
        return false;
    }
    my $val = $capt->captcha;
    $capt->delete; # Delete it, it can't be reused anyway
    if ($value eq $val)
    {
        return true;
    }
    return false;
}

# Summary: Generate a captcha value
# Usage: captcha = _generate_captcha();
sub _generate_captcha
{
    my @characters = ('0','2','3','4','5','6','7','8','9','b','c','d','f','g','h','j','k','m','n','p','q','r','s','t','v','w','x','y','z','B','C','D','F','G','H','J','K','M','N','P','Q','R','S','T','V','W','X','Y','Z');
    my $code;
    foreach(1..CAPTCHA_LENGTH)
    {
        my $r = int rand @characters;
        $code .= $characters[$r];
    }
    return $code;
}

1;
