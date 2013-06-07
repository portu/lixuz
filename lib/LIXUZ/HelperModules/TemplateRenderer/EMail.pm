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

package LIXUZ::HelperModules::TemplateRenderer::EMail;
use Moose;
use Try::Tiny;
use HTML::Mason::Interp;
use LIXUZ::HelperModules::Live::Articles qw(get_live_articles_from);
use LIXUZ::HelperModules::Calendar qw(datetime_from_SQL datetime_from_unix datetime_to_SQL);

extends 'LIXUZ::HelperModules::TemplateRenderer';

has 'subscription' => (
    isa => 'Object',
    required => 1,
    is => 'ro'
);

has 'emailType' => (
    isa => 'Str',
    required => 0,
    is => 'rw',
    builder => '_getEmailType',
    lazy => 1,
);


sub autoSendNewsletter
{
    my ($self) = @_;

    if(not $self->autoGenerateArticleList())
    {
        return;
    }
    $self->autoSetTemplate();
    $self->resolve_var('emailType','newsletter');
    my $message = $self->getRenderedContent();

    if ($self->get_var('articles')->count == 0)
    {
        return;
    }

    $self->subscription->set_column('last_sent',datetime_to_SQL(datetime_from_unix(time)));
    $self->subscription->update();

    return $self->sendEmail($message);
}

sub autoSendMessage
{
    my($self,$message) = @_;

    $self->resolve_var('emailType','message');

    $self->autoSetTemplate();

    return $self->sendEmail($message);
}

sub sendEmail
{
    my($self,$message) = @_;

    # TODO: Implement ->subject and ->sender which retrieves the variables and
    #   either defaults them or errors out when they're missing

    $self->subscription->send_email(
                                        # It needs $c
                                        $self->c,
                                        # The type (HTML/TEXT)
                                        $self->emailType,
                                        # Subject of the e-mail
                                        $self->get_var('subject'),
                                        # The body
                                        $message,
                                        # The sender
                                        $self->sender,
                                    );
    return 1;
}

sub sender
{
    my ($self) = @_;
    my $sender = $self->get_var('sender');

    if(not defined $sender)
    {
        $sender = $self->c->req->base;
        $sender =~ s/^.+\/\///;
        $sender =~ s/(\/|:).*//g;
        $sender = 'Newsletter <noreply@'.$sender.'>';
        $self->c->log->warn('Template does not specify sender, defaulting to '.$sender);
    }
    return $sender;
}

sub getRenderedContent
{
    my($self) = @_;

    $self->resolve_var('unsubURL',$self->c->uri_for('/newsletter/unsubscribe').'?uid='.$self->subscription->subscription_id.'&key='.$self->subscription->get_validation_hash);
    $self->resolve();

    my $output;
    my $renderer = HTML::Mason::Interp->new(
        comp_root => $self->c->config->{'View::Mason'}->{comp_root},
        data_dir => $self->c->config->{LIXUZ}->{temp_path},
        allow_globals => [ qw($c) ],
        out_method => \$output,
        preamble => 'use utf8;',
    );

    $renderer->set_global('$c',$self->c);
    # TODO: Use try/catch around this
    $renderer->exec('/'.$self->template->file,%{$self->_resolved}, resolver => $self);

    return $output;
}

sub autoSetTemplate
{
    my ($self) = @_;

    my $search = { is_default => 1 };

    if ($self->emailType eq 'HTML')
    {
        $search->{type} = 'email_html';
    }
    else
    {
        $search->{type} = 'email_text';
    }
    
    my $template = $self->c->model('LIXUZDB::LzTemplate')->find($search);
    if(not $template)
    {
        die('Failed to locate newsletter template for type '.$search->{type});
    }

    $self->template($template);

    return;
}

sub autoGenerateArticleList
{
    my ($self) = @_;
    my $cats = $self->subscription->categories;
    my $helperCat;
    my @search;

    if(not defined $cats or $cats->count == 0)
    {
        $self->c->log->error('Newsletter subscription without any categories defined: '.$self->subscription->subscription_id.': not sending');
        return;
    }

    while((defined $cats) && (my $cat = $cats->next))
    {
        $cat = $cat->category;
        $helperCat = $cat;
        my $ssql = $cat->getCategoryFolderList($self->c);
        push(@search, $ssql);
    }

    if(not scalar @search)
    {
        $self->c->log->error('Newsletter subscription ending up with no searchSQL ('.$self->subscription->subscription_id.'). This is most likely a bug - not sending.');
        return;
    }

    my $searchRef = [];
    foreach my $s (@search)
    {
        next if not defined $s;
        push(@{$searchRef},@{$s});
    }
    my $articles = $self->c->model('LIXUZDB::LzArticle')->search({ 'folders.folder_id' => { IN => $searchRef } }, { join => 'folders' });
    if ($self->subscription->last_sent)
    {
        $articles = $articles->search({ publish_time => { '>',$self->subscription->last_sent}});
    }
    $articles = get_live_articles_from($articles, { rows => 30, order_by => \'publish_time DESC' });
    $self->resolve_var('articles',$articles);
    return $articles;
}

sub _getEmailType
{
    my $self = shift;
    if ($self->subscription->format eq 'html')
    {
        return 'HTML';
    }
    return 'TEXT';
}

__PACKAGE__->meta->make_immutable;
1;
