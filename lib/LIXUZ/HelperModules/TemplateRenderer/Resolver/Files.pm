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

package LIXUZ::HelperModules::TemplateRenderer::Resolver::Files;
use Moose;
with 'LIXUZ::Role::TemplateRenderer::Resolver';
use LIXUZ::HelperModules::Cache qw(get_ckey);

sub get
{
    my($self,$type,$params) = @_;

    if ($type eq 'fileSpots')
    {
        return $self->get_fileSpots($params);
    }

    die('Unknown data request: '.$type);
}

sub get_fileSpots
{
    my($self,$info) = @_;
    my $article = $info->{article};
    my $artid = $article->article_id;
    my $ckey = get_ckey('template','fileSpotsForArt',$artid.'-'.$article->revision);

    if(my $data = $self->c->cache->get($ckey))
    {
        foreach my $key (keys %{$data})
        {
            $data->{$key} = $self->c->model('LIXUZDB::LzArticleFile')->find({ article_id => $artid, file_id => $data->{$key}, revision => $article->revision});
        }
        return $data;
    }

    my $files;

    if(not $article)
    {
        $self->c->log->warn('get_fileSpots() called, but the artid ('.$artid.') was not valid. Ignoring the request.');
        return;
    }

    # Generate the list
    if (not $files = $article->files)
    {
        return;
    }
    if(not $info->{spots_parsed} or not @{$info->{spots_parsed}})
    {
        return;
    }

    my $result = {};
    my $cacheResult = {};
    my $filespot_index = {};

    # Create an index of the templates' filespots
    foreach my $spot (@{$info->{spots_parsed}})
    {
        $filespot_index->{$spot->{id}} = $spot->{as};
    }

    while(my $f = $files->next)
    {
        if (defined $f->spot_no)
        {
            if(not defined $filespot_index->{$f->spot_no})
            {
                $self->c->log->warn('Article '.$artid.' wants to use file spot '.$f->spot_no.' that is not present in template - ignoring request');
            }
            else
            {
                $cacheResult->{$filespot_index->{$f->spot_no}} = $f->file_id;
                $result->{$filespot_index->{$f->spot_no}} = $f;
            }
        }
    }

    $self->c->cache->set($ckey,$cacheResult);

    return $result;
}

__PACKAGE__->meta->make_immutable;
1;
