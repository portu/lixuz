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

package LIXUZ::HelperModules::RevisionHelpers;

use strict;
use warnings;
use Exporter qw(import);
use Carp qw(croak);
use constant { true => 1, false => 0 };
our @EXPORT_OK = qw(get_latest_article article_latest_revisions get_live_or_latest_article set_other_articles_inactive get_latest_articles_from_rs);

sub set_other_articles_inactive
{
    my $c = shift;
    my $artid = shift;
    my $liveRev = shift;
    $c->model('LIXUZDB::LzArticle')->search({
            article_id => $artid,
            revision => { '!=' => $liveRev },
            status_id => 2,
        })->update({ status_id => 4 });
}

sub get_latest_article
{
    my $c = shift;
    my $artid = shift;
    croak('$c missing') if not defined $c or not ref($c);
    my $art = $c->model('LIXUZDB::LzArticle')->find({ article_id => $artid, 'revisionMeta.is_latest' => 1 }, { join => 'revisionMeta' });
    return $art;
}

sub get_latest_articles_from_rs
{
    my $c = shift;
    my $rs = shift;
    croak('$c missing') if not defined $c or not ref($c) or not defined $rs or not ref($rs);
    my %seen;
    my @articles;
    while(my $art = $rs->next)
    {
        my $artid = $art->article_id;
        next if $seen{$artid};
        $seen{$artid} = 1;
        my $latest = get_latest_article($c,$artid) // $art;
        push(@articles, $latest);
    }
    return \@articles;
}

sub get_live_or_latest_article
{
    my $c = shift;
    my $artid = shift;
    my $art = $c->model('LIXUZDB::LzArticle')->find({ article_id => $artid, status_id => 2});
    if ($art)
    {
        return $art;
    }
    else
    {
        return get_latest_article($c,$artid);
    }
}

# This needs a prototype of $ to enforce scalar context
sub article_latest_revisions($)
{
    my $rs = shift;
    if (defined $rs)
    {
        croak('article_latest_revisions got $rs ('.ref($rs).') that can\'t ->search') if not $rs->can('search');
        return $rs->search({
                'revisionMeta.is_latest' => 1,
            }, {
                'join' => 'revisionMeta',
                group_by => 'me.article_id',
            });
    }
    return $rs;
}
1;
