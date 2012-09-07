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

# Newsletter controller.
#
# You can use the following HTML to generate a form:
=cut
<form id="newsletterSubscription" action="/newsletter/subscribe"><table>
<tr><td>E-postaddresse</td>
<td><input type="text" name="email" /></td></tr><tr>
<td>Ditt navn</td><td><input type="text" name="name" /></td>
</tr><tr><td>Kategorier</td><td><input type="checkbox" name="categories" value="1"> Nyheter
</td></tr><tr><td>Format</td><td>
<input selected="selected" type="radio" name="format" value="text"> Ren tekst
<input type="radio" name="format" value="html"> HTML
</td></tr><tr><td>Intervall</td>
<td><input type="radio" name="interval" value="day"> Daglig
<input selected="selected" type="radio" name="interval" value="week"> Ukentlig
<input type="radio" name="interval" value="month"> M&aring;nedlig</td></tr><tr>
<td colspan="2"><input type="submit" /></td></tr></table></form>
=cut
package LIXUZ::Controller::Live::Newsletter;

use strict;
use warnings;
use base 'Catalyst::Controller';
use LIXUZ::HelperModules::Calendar qw(datetime_from_SQL_to_unix);
use HTML::Entities qw(decode_entities);
use Carp;
use Mail::RFC822::Address qw(valid);
use LIXUZ::HelperModules::Live::CAPTCHA qw(validate_captcha);

__PACKAGE__->config->{namespace} = 'newsletter';

# Summary: Handle new subscriptions to the newsletter
sub subscribe : Local
{
    my ($self,$c) = @_;
    my $email = $c->req->param('email');
    my @categories = $c->req->param('categories');
    my $name = $c->req->param('name');
    my $format = $c->req->param('format');
    my $interval = $c->req->param('interval');
    my $language = $c->req->param('language');

    my $captcha = $c->req->param('captcha');
    my $captcha_id = $c->req->param('captcha_id');
    if(not validate_captcha($c,$captcha_id,$captcha))
    {  
        $self->message($c,'Invalid captcha. Press the back button in your web browser and try again.');
    }

    $format = (defined $format && $format =~ /^(text|html)$/) ? $format : 'text';

    foreach my $i ($email,\@categories,$name,$format,$interval)
    {
        if(not defined $i or not length $i)
        {
            $self->message($c,'Missing parameters');
        }
    }

    foreach my $cat (@categories)
    {
        if(not $cat =~ /^(\d|,)+$/)
        {
            $self->message($c,'Parameter validation error');
        }
    }

    @categories = sort(@categories);

    if(not @categories)
    {
        $self->message($c,'You must select some categories');
    }

    if(not valid($email))
    {
        $self->message($c,'Invalid e-mail address');
    }

    # Attempt to detect dupes
    my $existing = $c->model('LIXUZDB::LzNewsletterSubscription')->search({ email => $email });

    while(defined($existing) && (my $e = $existing->next))
    {
        if ($e->categoryString eq join(',',@categories) && $e->send_every eq $interval && $e->format eq $format)
        {
            $self->message($c,'You already have an active subscription.');
        }
    }

    # Okie, no dupes, add it
    my $new = $c->model('LIXUZDB::LzNewsletterSubscription')->create({
            email => $email,
            name => $name,
            format => $format,
            send_every => $interval, #FIXME validate it
        });

    if(defined $language)
    {
        my @lang;
        if(ref($language))
        {
            push(@lang,@{$language});
        }
        else
        {
            push(@lang,$language);
        }
        foreach(@lang)
        {
            if (/^\d+$/ && $c->model('LIXUZDB::LzNewsletterGroup')->find({ group_id => $_ }))
            {
                $c->model('LIXUZDB::LzNewsletterSubscriptionGroup')->create({ 
                        group_id => $_,
                        subscription_id => $new->subscription_id
                    });
            }
        }
    }

    $new->subscribeToCategories($c,@categories);

    $new->set_column('validated',1);
    $new->update();

    # FIXME: Add a message type so that this might be translated
    my $msg = 'Your request has been received.';
    $self->message($c,$msg);
}

# Summary: Handle unsubscribe-requests
sub unsubscribe : Local
{
    my ($self,$c) = @_;
    my $uid = $c->req->param('uid');
    my $key = $c->req->param('key');
    my $entry = $c->model('LIXUZDB::LzNewsletterSubscription')->find({
            subscription_id => $uid,
        });

    my $msg;

    if ($entry && $entry->unsubscribe($key))
    {
        $msg = 'Your subscription has been removed.';
    }
    else
    {
        $msg = 'Unable to remove subscription, invalid key';
    }
    $self->message($c,$msg);
}

# Summary: Validate a request to subscribe
sub validate : Local
{
    my ($self,$c) = @_;
    my $uid = $c->req->param('uid');
    my $key = $c->req->param('key');

    my $entry = $c->model('LIXUZDB::LzNewsletterSubscription')->find({
            subscription_id => $uid,
        });

    my $msg;

    if ($entry && $entry->validate($key))
    {
        $msg = 'Your subscription has been activated.';
        $c->stash->{message} = $msg;
    }
    else
    {
        $msg = 'Unable to activate the subscription, the key is invalid';
    }
    $self->message($c,$msg);
}

# Summary: Display an error message 
sub message : Private
{
    my ($self,$c,$message,$error) = @_;
    if(not $message)
    {
        $message = 'Generic error';
        $c->log->warn('Generic error while performing newsletter processing');
    }
    if ($error)
    {
        $c->log->warn('Error in newsletter controller: '.$error);
    }
    my $renderer = LIXUZ::HelperModules::TemplateRenderer->new(c => $c);
    $renderer->message($message,'NEWSLETTERMESSAGE');
}

1;
