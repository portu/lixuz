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

# Controller for tags handling
package LIXUZ::Controller::Admin::Tags;
use Moose;
use namespace::autoclean;
BEGIN { extends 'Catalyst::Controller' };
use LIXUZ::HelperModules::JSON qw(json_response_raw json_response json_error);
use LIXUZ::HelperModules::Includes qw(add_jsIncl add_cssIncl add_globalJSVar add_jsOnLoad);

# Summary: Returns data for autocompletion of tags that match a term
sub complete : Local
{
    my($self,$c) = @_;
    my $term = $c->req->param('term');
    my @response;
    if (defined($term) && length($term))
    {
        my $results = $c->model('LIXUZDB::LzTag')->search({ name => { 'LIKE' => $term.'%' } });
        if(not $results->count)
        {
            $results = $c->model('LIXUZDB::LzTag')->search({ name => { 'LIKE' => '%'.$term.'%' } });
        }
        while(my $r = $results->next)
        {
            push(@response, {
                    id => $r->tag_id,
                    label => $r->name,
                });
        }
    }
    return json_response_raw($c,\@response);
}

# Summary: Checks if a supplied tag exists. If it doesn't it checks if the
#   current user can create it
sub exists : Local
{
    my($self,$c) = @_;
    my $term = $c->req->param('term');
    my $results = $c->model('LIXUZDB::LzTag')->search({ name => { 'LIKE' => $term } });
    if ($results->count)
    {
        my $r = $results->next;
        return json_response($c,{ exists => 1, name => $r->name, id => $r->tag_id });
    }
    my $can_add = $c->user->can_access('/tags/create');
    return json_response($c, { exists => 0, can_add => $can_add });
}

# Summary: Creates a new tag
sub create : Local
{
    my($self,$c) = @_;
    my $term = $c->req->param('term');
    $self->validate_tag($c,$term);
    my $newTag = $c->model('LIXUZDB::LzTag')->create({ name => $term });
    return json_response($c, { name => $newTag->name, id => $newTag->tag_id });
}

# Summary: Deletes a tag
sub delete : Local
{
    my($self,$c) = @_;
    my $tagid = $c->req->param('tag_id');
    my $tag = $c->model('LIXUZDB::LzTag')->find({tag_id => $tagid});
    if(not $tag)
    {
        return json_error($c,'INVALID_TAG_ID');
    }
    my $artRels = $c->model('LIXUZDB::LzArticleTag')->search({ tag_id => $tagid });
    while(my $rel = $artRels->next)
    {
        $rel->delete();
    }
    my $fileRels = $c->model('LIXUZDB::LzFileTag')->search({ tag_id => $tagid });
    while(my $rel = $fileRels->next)
    {
        $rel->delete();
    }
    $tag->delete();
    return json_response($c);
}

# Summary: Returns a page listing all tags
sub list : Local
{
    my($self,$c) = @_;
    my $tags = $c->model('LIXUZDB::LzTag')->search(undef, { order_by => 'tag_id' });
    $c->stash->{tags} = $tags;
    $c->stash->{template} = 'adm/tags/list.html';
	add_jsIncl($c,qw(tags.js));
}

# Summary: Handles renaming a tag
sub edit : Local
{
    my($self,$c) = @_;
    my $tagid = $c->req->param('tag_id');
    my $name = $c->req->param('name');
    my $tag = $c->model('LIXUZDB::LzTag')->find({tag_id => $tagid});
    if(not $tag)
    {
        return json_error($c,'INVALID_TAG_ID');
    }
    $self->validate_tag($c,$name);
    $tag->set_column('name', $name);
    $tag->update();
    return json_response($c);
}

# Summary: Validates a tag, returning a (JSON) error to the client if it does not
#   fit the rules for tag names.
sub validate_tag : Private
{
    my ($self,$c,$tag) = @_;
    if (
        (not defined $tag) or
        (not length $tag) or
        (not $tag =~ /\S/) or
        ($tag =~ /,/)
    )
    {
        json_error($c,'INVALID_TAG_NAME');
        $c->detach;
    }
}

__PACKAGE__->meta->make_immutable;
1;
