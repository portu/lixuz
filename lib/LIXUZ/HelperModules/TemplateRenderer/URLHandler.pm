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

package LIXUZ::HelperModules::TemplateRenderer::URLHandler;
use Moose;
use Try::Tiny;
extends 'LIXUZ::HelperModules::TemplateRenderer';

has 'forceOverrideTemplate' => (
    isa => 'Bool',
    default => 0,
    is => 'rw',
    required => 0
    );

has '_urlType' => (
    is => 'rw',
    default => '(unknown)',
);

sub handleRequest
{
    my($self) = @_;

    try
    {
        $self->_iHandleRequest();
    }
    catch
    {
        if ($_ eq "catalyst_detach\n")
        {
            $self->c->detach;
        }
        else
        {
            $self->c->log->error('iHandleRequest crashed for URL "'.$self->c->req->uri.'": '.$_);
            $self->error(500,'Failed to properly handle the request. Please try again later.','Complete crash in handleRequest: '.$_);
        }
    };
}

sub _iHandleRequest
{
    my($self) = @_;

    my $url = $self->cleanUrl($self->c->req->uri);
    my @path = split(m{/},$url);

    if(not @path)
    {
        @path = ('/');
    }

    $self->set_statevar('urlPath',\@path);

    if (defined($path[1]) && $path[1] =~ /^search(\?.*)?$/)
    {
        $self->_urlType('search');

        my $template = $self->c->model('LIXUZDB::LzTemplate')->find({ is_default => 1, type => 'search' });
        $self->template($template);
    }
    elsif ($path[-1] =~ /^\d+(\?.+)?$/ || $path[-1] =~ /-\d+(\?.+)?$/)
    {
        $self->_urlType('article');

        my ($article,$template) = $self->getArticleFromURL(\@path);
        if(not $article)
        {
            $self->error(404);
        }
        if ($article->template)
        {
            $template = $article->template;
        }
        else
        {
            $template = $self->c->model('LIXUZDB::LzTemplate')->find({ is_default => 1, type => 'article'});
        }
        if (! $self->forceOverrideTemplate || ! $self->template)
        {
            $self->template($template);
        }
        $self->set_statevar('primaryArticle',$article);
    }
    elsif ($path[-1] eq '/' || $path[-1] =~ /\D/)
    {
        $self->_urlType('list');

        if ($path[-1] ne '/')
        {
            my $cat = $self->getCategoryFromURL(\@path);
            $self->set_statevar('category',$cat);
            if ($cat)
            {
                $self->template( $cat->template );
            }
            else
            {
                $self->template( $self->c->model('LIXUZDB::LzTemplate')->find({ type => 'list', is_default => 1}) );
            }
        }
        else
        {
            my $template = $self->c->model('LIXUZDB::LzTemplate')->find({ type => 'list', is_default => 1 });
            $self->template($template);

            $self->set_statevar('categoryFront',1);
        }
    }
    else
    {
        die; #FIXME
        $self->error();
    }
    $self->autorender();
}

sub getArticleFromURL
{
    my ($self,$path) = @_;
    my $artid = $path->[-1];
    $artid =~ s/^.*-(\d+)$/$1/;
    my $article = $self->c->model('LIXUZDB::LzArticle')->find({ article_id => $artid, status_id => 2 });
    if ($article)
    {
        return($article, undef);
    }
    # Right, so the article doesn't have any live version. Now we've got a problem:
    # If the article isn't live, it still might be considered live by the template.
    # But as different revisions can have different templates, and the *template*
    # defines the status ID which is to be considered live.
    $article = $self->c->model('LIXUZDB::LzArticle')->find({ article_id => $artid, 'revisionMeta.is_latest' => 1 }, { join => 'revisionMeta' });
    return ($article,undef);
}

sub getCategoryFromURL
{
    my ($self,$path) = @_;
    my $origCat = $path->[-1];
    my $cat     = $origCat;
    my $m       = $self->c->model('LIXUZDB::LzCategory');
    # TODO: Caching

    my $catObj;

    $catObj = $self->_tryFetchCategory($cat);
    return $catObj if defined $catObj;

    if ($cat =~ s/\.cat$//g)
    {
        $catObj = $self->_tryFetchCategory($cat);
        return $catObj if defined $catObj;
    }

    if ($cat =~ s/-/ /g)
    {
        $catObj = $self->_tryFetchCategory($cat);
        return $catObj if defined $catObj;
    }

    $cat = lc($cat);
    $catObj = $self->_tryFetchCategory($cat);
    return $catObj if defined $catObj;

    $cat = ucfirst($cat);
    $catObj = $self->_tryFetchCategory($cat);
    return $catObj if defined $catObj;

    return;
}

sub _tryFetchCategory
{
    my ($self,$name) = @_;

    my $list = $self->c->model('LIXUZDB::LzCategory')->search({ 'me.category_name' => $name }, {prefetch => 'children'});

    if (not $list->count)
    {
        return;
    }
    elsif($list->count > 1)
    {
        # Multiple matches, ignore.
        return;
    }
    else
    {
        return $list->next;
    }
}

# Summary: Cleans up a URL, making sure it is exactly as others would use it
#   to ensure that things like caching works as expected.
sub cleanUrl
{
    my ($self,$url) = @_;

    $url =~ s{\?.+$}{};
    $url =~ s{^http://[^/]+}{};
    $url =~ s{/+}{/}g;
    $url =~ s{/+$}{};

    if(not $url)
    {
        return '/';
    }
    return $url;
}

__PACKAGE__->meta->make_immutable;
1;
