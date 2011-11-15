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

package LIXUZ::HelperModules::RSS;
use Moose;
use LIXUZ::HelperModules::Cache qw(get_ckey CT_24H CT_1H);
use LIXUZ::HelperModules::Calendar qw(datetime_from_SQL_to_unix);
use LIXUZ::HelperModules::Live::Articles qw(get_live_articles_from);
use HTML::Entities qw(decode_entities);
use LIXUZ::HelperModules::HTMLFilter qw(filter_string);
use XML::FeedPP;
use POSIX qw(strftime setlocale locale_h);

use constant { true => 1, false => 0 };
use constant { CACHE_TIME => 600 }; # 10 minutes

has 'c' => (
    isa => 'Object',
    required => true,
    is => 'ro',
    weak_ref => 1,
);

has 'category' => (
    isa => 'Str',
    required => false,
    lazy => true,
    builder => '_getCategoryFromURL',
    is => 'ro',
);

has 'defaultCatId' => (
    isa => 'Int',
    required => false,
    is => 'ro'
);

has 'useCache' => (
    isa => 'Bool',
    default => true,
    is => 'rw',
);

has title => (
    isa => 'Str',
    default => 'Lixuz RSS feed',
    is => 'rw',
);

has description => (
    isa => 'Str',
    default => 'Lixuz RSS feed',
    is => 'rw',
);

has copyright => (
    isa => 'Maybe[Str]',
    default => undef,
    is => 'rw',
);

has urlGenerator => (
    isa => 'CodeRef',
    builder => '_buildDefaultUrlGenerator',
    lazy => true,
    is => 'rw',
);

has 'extraLiveStatus' => (
    isa => 'Maybe[Str]',
    default => undef,
    is => 'rw',
);

has 'overrideLiveStatus' => (
    isa => 'Maybe[Int]',
    default => undef,
    is => 'rw',
);

has 'rows' => (
    isa => 'Int',
    default => 10,
    is => 'rw',
);

has '_catObj' => (
    builder => '_lookupCategoryObject',
    is => 'rw',
    lazy => true,
);

sub getRSS
{
    my($self) = @_;
    my $ckey;

    if ($self->useCache)
    {
        $ckey = get_ckey('rss',$self->c->req->path);
        if(my $content = $self->c->cache->get($ckey))
        {
            return $content;
        }
    }
    my $title = $self->title;
    my $description = $self->description;
    my $rss = XML::FeedPP::RSS->new(
        title                => \$title,
        link                 => $self->c->uri_for('/'),
        description          => \$description,
        generator            => 'Lixuz',
        'sy:updatePeriod'    => "hourly",
        'sy:updateFrequency' => "1",
        'sy:updateBase'      => "1901-01-01T00:00+00:00",
        'dc:rights'          => $self->copyright,
    );
    $rss->xmlns('xmlns:sy' => 'http://purl.org/rss/1.0/modules/syndication/');
    $rss->xmlns('xmlns:dc' => 'http://purl.org/dc/elements/1.1/');
    $rss->xmlns('xmlns:content' => 'http://purl.org/rss/1.0/modules/content/');

    my $articles = $self->_getArticles;
	while(my $art = $articles->next)
	{
		my $lead = filter_string($art->lead);
		$lead =~ s/^<br\s*\/?>\s*//g;
        my $url = $self->urlGenerator->($self->c,$art);
        my $title = $art->title;
		$rss->add_item(
            pubDate => $self->_dateToPubdate($art->publish_time),
			title => \$title,
			link => ''.$url,
			description => \$lead,
			guid => "".$url,
            category => $art->category_name($self->c),
            'content:encoded' => \$lead,
            'dc:creator' => $art->author,
            'dc:category' => $art->category_name($self->c),
		);
	}
    my $content = $rss->to_string;
    if ($self->useCache)
    {
        $self->c->cache->set($ckey,$content,CT_1H);
    }
    return $content;
}

sub outputRss
{
    my($self) = @_;
	$self->c->res->content_type('application/rss+xml');
    $self->c->res->body($self->getRSS);
    $self->c->detach;
}

sub _getCategoryFromURL
{
    my($self) = @_;
    my $url = $self->c->req->path;
    $url =~ s{/\d+$}{}g;
    $url =~ s{/rss-?[\d\.]+\.xml$}{}g;
    my @paths = split(m{/},$url);
    my $category = $paths[-1];
    return $category;
}

sub _lookupCategoryObjectFromName
{
    my($self,$name) = @_;
    my $origName = $name;
    my $cat;
    if ($cat = $self->c->cache->get(get_ckey('rss_category','path',$name)))
    {
        $cat = $self->c->model('LIXUZDB::LzCategory')->find({category_id => $cat});
    }

    if(not $cat)
    {
        # First, do initial parsing and try to locate the most logical feed category
        $name =~ s{-}{ }g;
        $name = decode_entities($name);
        $cat = $self->c->model('LIXUZDB::LzCategory')->find({category_name => $name},{prefetch => 'children',columns => [ 'category_id','parent','root_parent']});

        if(not $cat)
        {
            # Failing that, attempt to clear out some strange characters from
            # feed readers that doesn't follow the links quite right
            if ($name =~ s/;+//g)
            {
                if ($cat = $self->c->model('LIXUZDB::LzCategory')->find({category_name => $name},{prefetch => 'children',columns => [ 'category_id','parent','root_parent']}))
                {
                    $name =~ s/\s/-/g;
                    $self->c->response->redirect($self->c->uri_for('/rss/'.$name));
                    $self->c->detach;
                }
                else
                {
                    # And if that fails as well, try the literal one as found in the URL.
                    $name = $origName;
                    $cat = $self->c->model('LIXUZDB::LzCategory')->find({category_name => $name},{prefetch => 'children',columns => [ 'category_id','parent','root_parent']});
                }
            }
        }
        if ($cat)
        {
            $self->c->cache->set(get_ckey('rss_category','path',$origName),$cat->category_id,CT_1H);
        }
    }
    return $cat;
}

sub _fetchDefaultCategoryObject
{
    my ($self) = @_;
    if ($self->defaultCatId)
    {
        return $self->c->model('LIXUZDB::LzCategory')->find({ category_id => $self->defaultCatId });
    }
    return;
}

sub _lookupCategoryObject
{
    my($self) = @_;
    my $category = $self->category;
    my $obj;
    if(!defined $category || $category eq 'feed.xml' || $category eq 'rss')
    {
        $obj = $self->_fetchDefaultCategoryObject;
    }
    else
    {
        $obj = $self->_lookupCategoryObjectFromName($category);
        if(not $obj)
        {
            $self->c->log->warn('Found no category for URL '.$self->c->req->path.' - using default.');
            $obj = $self->_fetchDefaultCategoryObject;
        }
    }
    return $obj;
}

sub _getArticles
{
    my ($self) = @_;
    my $category = $self->_catObj;
    my $articles;
    if ($category)
    {
        $articles = $category->get_live_articles($self->c,{ rows => $self->rows, extraLiveStatus => $self->extraLiveStatus, overrideLiveStatus => $self->overrideLiveStatus });
    }
    else
    {
        $articles = get_live_articles_from($self->c->model('LIXUZDB::LzArticle'), { overrideLiveStatus => $self->overrideLiveStatus, extraLiveStatus => $self->extraLiveStatus});
        $articles = $articles->search(undef, { rows => $self->rows, order_by => 'publish_time DESC' });
    }
    return $articles;
}

sub _dateToPubdate
{
    my $self = shift;
    my $realdate = shift;

    my $old = setlocale(LC_ALL,'');
    my $s = strftime("%a, %d %b %Y %H:%M:%S %z",localtime(datetime_from_SQL_to_unix($realdate)));
    setlocale(LC_ALL,$old);
    return $s;
}

sub _buildDefaultUrlGenerator
{
    return sub {
        my ($c,$article) = @_;
        return $article->get_absoluteURL($c);
    };
}


__PACKAGE__->meta->make_immutable;
