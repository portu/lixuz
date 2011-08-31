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

# LIXUZ::HelperModules::Live::Comments
# 
package LIXUZ::HelperModules::Live::Comments;

use strict;
use warnings;
use Carp;
use Exporter qw(import);
use HTML::Entities qw(encode_entities);
use LIXUZ::HelperModules::Live::CAPTCHA qw(validate_captcha get_captcha);
use LIXUZ::HelperModules::SimpleFormValidator qw(simple_validate_form);
our @EXPORT_OK = qw(comment_handler comment_prepare);
use constant {
    true => 1,
    false => 0,
};

sub comment_handler
{
    my($c,$art_id) = @_;

    if ($c->req->param('_lz_artCommentSubmitted'))
    {
        comment_handle_input($c,$art_id);
    }
    comment_prepare($c,$art_id);
}

sub comment_handle_input
{
    my ($c,$art_id) = @_;

    my $captcha = $c->req->param('captcha');
    my $captcha_id = $c->req->param('captcha_id');
    my $subject = $c->req->param('subject');
    my $author_name = $c->req->param('author_name');
    my $body = $c->req->param('body');
    my($form_valid,$message) = simple_validate_form($c,{
            author_name => {
                min_length => 3,
                max_length => 128,
                required => 1,
                error_msg => 'Du m&aring; skrive inn navnet ditt',
                validate_regex => '\S',
            },
            subject => {
                min_length => 3,
                max_length => 255,
                required => 1,
                error_msg => 'Du m&aring; skrive inn et emne',
                validate_regex => '\S',
            },
            body => {
                min_length => 5,
                required => 1,
                error_msg => 'Du m&aring; skrive inn en kommentartekst',
                validate_regex => '\S',
            },
        });
    if(not $form_valid)
    {
        $c->stash->{comment_message} = $message;
        $c->stash->{comment_message_error} = true;
        populate_stash_from_param($c);
        return;
    }

    if(not validate_captcha($c,$captcha_id,$captcha))
    {
        $c->stash->{comment_message} = 'Feil visuell bekreftelseskode';
        $c->stash->{comment_message_error} = true;
        populate_stash_from_param($c);
        return;
    }

    $body = encode_entities($body);
    $body =~ s/\r?\n/<br \/>/g;
    # Captcha is valid and so is the form, add the comment
    my $ip = $c->req->address;
    my $comment = $c->model('LIXUZDB::LzLiveComment')->create({
            ip => $ip,
            author_name => $author_name,
            body => $body,
            subject => $subject,
            article_id => $art_id,
        });
    $c->stash->{comment_message} = 'Din kommentar har blitt sendt inn';
    return $comment->comment_id;
}

sub comment_prepare
{
    my($c,$art_id,$stashName) = @_;

    if ($stashName)
    {
        $stashName .= '_';
    }
    else
    {
        $stashName = '';
    }

    $c->stash->{$stashName.'comment_list'} = $c->model('LIXUZDB::LzLiveComment')->search({article_id => $art_id}, { order_by => 'created_date' });
    $c->stash->{$stashName.'captcha_id'} = get_captcha($c);
    return true;
}

sub populate_stash_from_param
{
    my ($c) = @_;
    foreach my $param (qw(subject author_name body))
    {
        if ($c->req->param($param))
        {
            $c->stash->{'comment_'.$param} = $c->req->param($param);
        }
    }
    return true;
}


1;
