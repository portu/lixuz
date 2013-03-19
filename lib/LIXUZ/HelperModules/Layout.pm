# LIXUZ content management system
# Copyright (C) Utrop A/S Portu media & Communications 2012-2013
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
#

# This module contains functions that assists with display layout
package LIXUZ::HelperModules::Layout;
use strict;
use warnings;
use Exporter qw(import);
use constant { true => 1, false => 0 };
use LIXUZ::HelperModules::RevisionHelpers qw(get_live_or_latest_article);
our @EXPORT_OK = qw(getArticleInSpot);

sub getArticleInSpot
{
    my $c = shift;
    my $spot_id = shift;
    my $cat_id = shift;
    my $obj = $c->model('LIXUZDB::LzCategoryLayout')->find({'category_id' => $cat_id, spot => $spot_id});
    if (not $obj)
    {
        return;

    }
    else
    {
        my $article_id = $obj->get_column('article_id');
        my $article = get_live_or_latest_article($c, $article_id);
        return $article;

    }
}

1;
