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

package LIXUZ::Role::URLGenerator;

use Moose::Role;
use LIXUZ::HelperModules::Cache qw(get_ckey CT_DEFAULT);
use URI::Escape qw( uri_escape_utf8 );
requires 'get_category_tree';
use constant {
    TYPE_ARTICLE => 1,
    TYPE_CATEGORY => 2,
    };

# Summary: Get the URL for the consumer
# Usage: url = article->url($c,NOT_IN_CATEGORY);
#
# NOT_IN_CATEGORY is optional, an int, category_id. It will not use that
# category as its 'best' one, no matter what. This is only used for
# articles.
sub url
{
    my $self = shift;
    my $c    = shift;
    my $urlType;
    my $notInCategory;
    my $map;
    my $format;
    my $ckey;

    # Retrieve key mappings and cache keys
    if ($self->isa('LIXUZ::Schema::LzArticle'))
    {
        $urlType             = TYPE_ARTICLE;
        $notInCategory       = shift;
        $format              = $c->config->{LIXUZ}->{article_url};
        $map->{article_id}   = $self->article_id;
        $map->{article_name} = $self->title;
        $ckey                = get_ckey('article','url',$map->{article_id}.'-'.(defined $notInCategory ? $notInCategory : ''));
    }
    else
    {
        $urlType = TYPE_CATEGORY;
        $format  = $c->config->{LIXUZ}->{category_url};
        $ckey    = get_ckey('category','url',$self->category_id);
    }
    # Try the cache
    if(my $url = $c->cache->get($ckey))
    {
        return $url;
    }

    # Generate category list
    my @categories = $self->get_category_tree($c,$notInCategory);
    if (@categories)
    {
        @categories    = reverse @categories;
        foreach my $c (@categories)
        {
            $map->{category_list} .= '/' . _escape_component($c);
        }
    }
    # If we're formatting an article, allow it to not have any categories
    elsif ($urlType == TYPE_ARTICLE)
    {
        $map->{category_list} = '';
    }

    # Prepare article_name if any
    if(defined $map->{article_name})
    {
        $map->{article_name} = _escape_component($map->{article_name});
    }

    # Retrieve the URL
    my $url = $self->_format_url($map,$c,$format);
	# Reformat if needed for categories. They can't end with digits, as that
	# will be interpreted as an article URL. The URL parser understands .cat.
	if ($urlType == TYPE_CATEGORY && $url =~ /-\d+$/)
	{
		$url .= '.cat';
	}
    # Cache it
    $c->cache->set($ckey,$url,CT_DEFAULT);
    # Return to caller
    return $url;
}

sub url_empty_cache
{
    my $self = shift;
    my $c = shift;
    my @ckeys;

    if ($self->isa('LIXUZ::Schema::LzArticle'))
    {
        my $base = get_ckey('article','url',$self->article_id.'-');
        push(@ckeys,$base);
        my $cats = $c->model('LIXUZDB::LzCategory')->search({}, { columns => [ 'category_id' ]});
        while(my $cat = $cats->next)
        {
            push(@ckeys, $base.$cat->category_id);
        }
    }
    else
    {
        @ckeys = (get_ckey('category','url',$self->category_id));
    }

    foreach my $ckey (@ckeys)
    {
        $c->cache_remove($ckey);
    }
}

# Alias for ->url()
sub get_url
{
    my $self = shift;
    $self->url(@_);
}

sub _escape_component
{
    my $comp = shift;
    $comp    =~ s/\s+/-/g;
    $comp    =~ s{/+}{-}g;
    $comp    = uri_escape_utf8($comp);
    return $comp;
}

sub _format_url
{
    my $self   = shift;
    my $map    = shift;
    my $c      = shift;
    my $format = shift;
    $format    = '/'.$format;

    # Unescape format
    $format    =~ s/\\%/%/g;

    my %replacements = (
        '%a' => 'article_id',
        '%c' => 'category_list',
        '%A' => 'article_name',
    );
    foreach my $e (keys(%replacements))
    {
        my $k = $replacements{$e};
        my $v = $map->{$k};
        if(defined($v))
        {
            $format =~ s/$e/$v/g;
        }
        elsif($format =~ /$e/)
        {
            $c->log->warn('Unresolved placeholder in URL: '.$e);
        }
    }

    # Clean it
    $format =~ s{/+}{/}g;
    $format =~ s/\s+/-/g;
    $format =~ s/-+/-/g;
    $format =~ s/[\r\n]//g;
    return $format;
}

1;
