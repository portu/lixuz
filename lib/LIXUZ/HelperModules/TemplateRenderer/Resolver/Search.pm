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

package LIXUZ::HelperModules::TemplateRenderer::Resolver::Search;
use Moose;
with 'LIXUZ::Role::TemplateRenderer::Resolver';

use LIXUZ::HelperModules::Live::Comments qw(comment_handler);
use LIXUZ::HelperModules::Calendar qw(datetime_from_SQL_to_unix);
use LIXUZ::HelperModules::Search qw(perform_search);
use LIXUZ::HelperModules::Indexer;
use LIXUZ::HelperModules::Live::Articles qw(get_live_articles_from);
use HTML::Entities qw(decode_entities);
use Carp;
use constant { true => 1, false => 0 };
use 5.010;

sub get
{
    my($self,$type,$params) = @_;

    given($type)
    {
        when('results')
        {
            return $self->get_results($params);
        }

        default
        {
            die('Unknown data request: '.$type);
        }
    }
}

sub get_results
{
    my($self,$searchContent) = @_;

    my $return = {};

    my $saveAs = $searchContent->{as};
    my $indexerBias = $searchContent->{defaultBias} // 'score';
    if(not $saveAs)
    {
        $self->log('Resolver search results: No as= parameter for data, ignoring request. Template might crash.');
        return;
    }
    elsif ($self->renderer->has_var($saveAs))
    {
        return;
    }

    #              Short hand version           Long version
    my $query    = $self->c->req->param('q') // $self->c->req->param('query');
    my $page     = $self->c->req->param('p') // $self->c->req->param('page');
    my $category = $self->c->req->param('c') // $self->c->req->param('category');
    my $bias     = $self->c->req->param('b') // $self->c->req->param('bias');

    if (not $page or $page =~ /\D/ or $page < 1)
    {
        $page = 1;
    }

    if ($bias eq 'dt')
    {
        $indexerBias = 'timestamp';
    }
    elsif($bias eq 'sc')
    {
        $indexerBias = 'score';
    }
    else
    {
        $bias = $indexerBias eq 'timestamp' ? 'dt' : 'sc';
    }

    my $result;
    my $pager;
    if (defined $query and length $query)
    {
        my $indexer = LIXUZ::HelperModules::Indexer->new(c => $self->c, mode => 'external', resultBias => $indexerBias);
        $result = $indexer->search({ query => $query });
        $result = $result->page($page);
        $pager = $indexer->searchPager;
    }
    else
    {
        $result = get_live_articles_from($self->c->model('LIXUZDB::LzArticle'));
        $result = $result->search(undef,{ order_by => \'publish_time DESC'});
        $result = $result->page($page);
        $pager = $result->pager;
    }
    # FIXME: Doesn't handle category with queries
    if(defined $category and not defined($query))
    {
        my $cat = $self->c->model('LIXUZDB::LzCategory')->find({ category_id => $category });
        if(not $cat)
        {
            my $err = 'Requested category='.$category.' - not found, falling back to all categories. URL: '.$self->c->req->uri;
            if ($self->c->req->referer)
            {
                $err .= ' || referer: '.$self->c->req->referer;
            }
            $self->c->log->warn($err);
        }
        else
        {
            my $searchSQL = $cat->getCategorySearchSQL($self->c);
            $result = $result->search({ -or => $searchSQL },{join => [qw(folders)], prefetch => 'folders' });
            if(defined $category and not defined $query)
            {
                $return->{$saveAs.'_name'} = $cat->category_name;
            }
        }
    }
    $return->{$saveAs.'_pager'}            = $result->pager;
    $return->{$saveAs.'_query'}            = $query;
    $return->{$saveAs.'_bias'}             = $bias;
    $self->c->req->params->{b}             = $bias;
    delete($self->c->req->params->{bias});
    $return->{$saveAs}                     = $result;

    return $return;
}

__PACKAGE__->meta->make_immutable;
1;
