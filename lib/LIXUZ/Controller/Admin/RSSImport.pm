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

package LIXUZ::Controller::Admin::RSSImport;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
BEGIN { extends 'Catalyst::Controller::FormBuilder' };
with 'LIXUZ::Role::List::Database';

use Try::Tiny;
use XML::FeedPP;
use Digest::SHA qw(sha256_hex);
use LIXUZ::HelperModules::Includes qw(add_jsIncl);
use LIXUZ::HelperModules::JSON qw(json_response json_error);
use LIXUZ::HelperModules::Lists qw(reply_json_list);
use LIXUZ::HelperModules::Calendar qw(datetime_from_unix datetime_to_SQL);
use LIXUZ::HelperModules::Editor qw(add_editor_incl);
use URI::Escape qw(uri_unescape);
use HTML::Entities qw(decode_entities);

# Summary: Main handler and 'catch-all' entry point for rssimport functions
#
# This handles handing control over to other parts where that's needed,
# otherwise it renders the list itself
sub index : Path Args(0) Form('/core/search')
{
    my ( $self, $c, $query ) = @_;

    if ($c->req->param('rss_submit'))
    {
        return $self->saveData($c);
    }
    elsif($c->req->param('getdata'))
    {
        return $self->JSONInfoResponse($c);
    }
    elsif($c->req->param('rssEdit_submit'))
    {
        return $self->RSSSubmitResponse($c);
    }
    elsif($c->req->param('delete'))
    {
        return $self->RSS_Delete($c);
    }
    
    $c->stash->{pageTitle} = 'RSS Import';

    $self->importAllFeeds($c);

    # Order them by default
    if(not $c->req->param('orderby'))
    {
        $c->req->params->{orderby} = 'pubdate';
        $c->req->params->{ordertype} = 'DESC';
    }

    my $s = $c->model('LIXUZDB::LzRssArticle');

    $self->init_searchFilters($c);

    my $obj = $self->handleListRequest({
            c => $c,
            query => $query,
            object => $s,
            objectName => 'rss_articles',
            template => 'adm/rssimport/index.html',
            orderParams => [qw(pubdate rss_id source status)],
            searchColumns => [ qw/title lead link/ ],
            advancedSearch =>[ qw(status) ],
            paginate => 1,
        });
    if ($c->stash->{rss_articles})
    {
        $c->stash->{rss_articles} = $c->stash->{rss_articles}->search({ deleted => \'!= 1'});
    }

    add_jsIncl($c,
        'rssimport.js',
    );
    add_editor_incl($c);
}

# Summary: Import RSS info from all feeds defined
sub importAllFeeds : Private
{
    my($self,$c) = @_;

    foreach my $src (@{$c->config->{LIXUZ}->{rss_sources}})
    {
        $self->importFromFeed($c,$src);
    }
}

# Summary: Handle a deletion request
sub RSS_Delete : Private
{
    my($self,$c) = @_;

    my $id = $c->req->param('delete');
    my $obj = $c->model('LIXUZDB::LzRssArticle')->find({rss_id => $id});

    if(not $obj or not defined $id)
    {
        return json_error($c,'INVALIDID');
    }

    # We don't need these when it's deleted, we're only keeping it around
    # so we remember the guid
    foreach (qw(lead link source title))
    {
        $obj->set_column($_,undef);
    }
    $obj->set_column('status','Inactive');
    $obj->set_column('deleted',1);
    $obj->update();
    return json_response($c);
}

# Summary: Handle submitted data by either updating or creating an rss entry
sub RSSSubmitResponse : Private
{
    my($self,$c) = @_;

    foreach(qw(lead link source title rss_id))
    {
        if(not defined $c->req->param($_))
        {
            return json_error($c,'MISSINGPARAM',$_);
        }
    }

    my $id = $c->req->param('rss_id');
    my $obj;
    if (not defined $id or ($id =~ /\D/ and not $id eq 'new'))
    {
        return json_error($c,'INVALIDID');
    }

    if ($id eq 'new')
    {
        my $guid = sha256_hex('lixuz_manual_'.time().'_'.$c->user->user_id);
        $obj = $c->model('LIXUZDB::LzRssArticle')->create({guid => $guid});
        $obj->set_column('pubdate',datetime_to_SQL(datetime_from_unix(time())));
    }
    else
    {
        $obj = $c->model('LIXUZDB::LzRssArticle')->find({rss_id => $id});
    }

    if(not $obj or not defined $id)
    {
        return json_error($c,'INVALIDID');
    }

    foreach(qw(lead link source title))
    {
        $obj->set_column($_,$c->req->param($_));
    }
    $obj->update();
    return json_response($c);
}

# Summary: Return information about an entry
sub JSONInfoResponse : Private
{
    my($self,$c) = @_;

    my $id = $c->req->param('getdata');

    my $obj = $c->model('LIXUZDB::LzRssArticle')->find({rss_id => $id});
    if(not $obj)
    {
        return json_error($c,'INVALIDID');
    }

    my %info;
    foreach my $c (qw(rss_id title lead link source))
    {
        $info{$c} = $obj->get_column($c);
    }
    return json_response($c,\%info);
}

# Summary: Save active/inactive status for entries
sub saveData : Private
{
    my($self,$c) = @_;

    my $items = $c->req->param('rssItems');

    if(not $items)
    {
        return json_error($c,'NO_ITEMS');
    }

    my @rssItems =  split(/,/,$items);

    foreach my $rssid (@rssItems)
    {
        my $item = $c->model('LIXUZDB::LzRssArticle')->find({rss_id => $rssid});
        if(not $item)
        {
            return json_error($c,'UNKNOWN_RSS_ID: '.$rssid);
        }
        if ($c->req->param($rssid) == 1)
        {
            $item->set_column('status','Active');
        }
        else
        {
            $item->set_column('status','Inactive');
        }
        $item->update();
    }
    return json_response($c);
}

# Summary: Handling importing data from feeds
sub importFromFeed : Private
{
    my($self,$c,$source) = @_;

    my $feed;

    # This attempts to create the XML::FeedPP object. Should it fail
    # it sleeps one second then tries again, if the second fails as well
    # then it will ignore this feed and move on.
    try
    {
        $feed = XML::FeedPP->new($source);
    }
    catch
    {
        try
        {
            sleep(1);
            $feed = XML::FeedPP->new($source);
        }
        catch
        {
            $feed = undef;
        };
    };
    return if not defined $feed;

    my $m = $c->model('LIXUZDB::LzRssArticle');

    foreach my $entry ($feed->get_item())
    {
        my $guid = $entry->guid() ? $entry->guid() : $entry->link();
        if(not $guid)
        {
            $c->log->warn('Error: no guid for an entry in feed from source '.$source.' - skipping entry');
            next;
        }
        $guid = $source.'-'.$guid;
        $guid = sha256_hex($guid);

        my $import = $m->find({ guid => $guid });
        if ($import)
        {
            return;
        }
        $import = $m->create({ guid => $guid });

        $import->set_column('source',$source);

        my $description = $entry->description;
        # Sesam filtering, we don't want this included
        $description =~ s/\s*-\s*\d+\s*(timer?|minutt(er)?)\s*siden//g;
        #$description = decode_entities($description);
        if ($description =~ /<script>/i)
        {
            $c->log->warn('Attempt at XSS found and killed, refusing to import description of guid '.$guid.': contained <script> tag!');
            $description = '';
        }
        $import->set_column('lead',$description);

        my $link = $entry->link;
        if ($link =~ m{http\%3A\%2F\%2F})
        {
            $link = uri_unescape($link);
        }
        # multiple levels of http:// ? forwarding URL, strip it down to the real URL
        if ($link =~ m{https?://.*http://})
        {
            $link =~ s{https?://.*http://}{http://}g;
        }
        elsif ($link =~ m{https?://.*https://})
        {
            $link =~ s{https?://.*https://}{https://}g;
        }
        # Clean it if needed
        $link =~ s/\&x=[^\&\=]+$//;

        $import->set_column('link',$link);

        # title shouldn't contain html/xml
        my $title = $entry->title;
        $title =~ s/<[^>]+>//g;
        $import->set_column('title',$title);

        my $pubdate = $entry->get_pubDate_epoch();
        $import->set_column('pubdate',datetime_to_SQL(datetime_from_unix($pubdate)));

        if ($c->config->{LIXUZ}->{rssImportActiveDefault})
        {
            $import->set_column('status','Active');
        }
        else
        {
            $import->set_column('status','Inactive');
        }

        $import->update();
    }
    
}

# Summary: Initialize search filter settings
sub init_searchFilters : Private
{
    my ( $self, $c ) = @_;

    my $i18n = $c->stash->{i18n};
    my $statusOptions = [
        {
            value => 'Active',
            label => $i18n->get('Active'),
        },
        {
            value => 'Inactive',
            label => $i18n->get('Inactive'),
        }
    ];
    $c->stash->{searchFilters} = [
        {
            name => $i18n->get('Status'),
            realname => 'status',
            options => $statusOptions,
            selected => defined $c->req->param('filter_status') ? $c->req->param('filter_status') : undef,
        },
    ];
}

1;
