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

package LIXUZ::Role::Taggable;
use Moose::Role;
use 5.010;

sub set_tags_from_param
{
    my $self = shift;
    my $param = shift;
    $param //= '';
    return $self->set_tags_from_list(split(/,/,$param));
}

sub set_tags_from_list
{
    my $self = shift;
    my @list = @_;
    # Sync tags with submitted data
    my $tags = $self->tags;
    while(my $tag = $tags->next)
    {
        $tag->delete();
    }
    foreach my $tag (@list)
    {
        $self->add_tag($tag);
    }
}

sub add_tag
{
    my $self = shift;
    my $tag = shift;

    if(not ref($tag))
    {
        $tag = $self->result_source->schema->resultset('LzTag')->find({
                tag_id => $tag,
            });
    }

    if ($tag)
    {
        my $selfType = ref($self);
        if ($selfType =~ /Article/)
        {
            $self->result_source->schema->resultset('LzArticleTag')->create({
                    tag_id => $tag->tag_id,
                    article_id => $self->article_id,
                    revision => $self->revision
                });
        }
        elsif($selfType =~ /File/)
        {
            $self->result_source->schema->resultset('LzFileTag')->create({
                    tag_id => $tag->tag_id,
                    file_id => $self->file_id
                });
        }
        else
        {
            die;
        }
    }

}

1;
