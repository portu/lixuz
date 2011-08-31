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

#!/usr/bin/perl
# This is our revision control handler for articles. It handles
# performing updates for us.
#
# Some gotchas:
# Instead of $c->model('LIXUZDB::...')->create({}); use
# $c->model('LIXUZDB::...')->new_result({});
#
# Instead of $obj->update(); use
# $revisionControlObj->add_object($obj); # This will act as both update() and insert()
#
# Finally, when all changes have been done, run
# $revisionCtonrolObj->commit()
# - no changes will hit the DB until commit() is run
#
# You can also retrieve the current article object by running
# $revisionControlObj->article
package LIXUZ::HelperModules::RevisionControl::Article;
use Moose;
use Carp qw(croak);
use 5.010;
use Try::Tiny;
extends 'LIXUZ::HelperModules::RevisionControl';

has '_typeName' => (
    isa => 'Str',
    is => 'ro',
    default => 'article',
    );

has '_idColumn' => (
    isa => 'Str',
    is => 'ro',
    default => 'article_id',
    );

sub set_root 
{
    my $self = shift;
    my $article = shift;

    croak('set_root() got no object') if not $article;

    if(not $article->isa('LIXUZ::Model::LIXUZDB::LzArticle'))
    {
        die('set_root() got non-article object: '.ref($article));
    }

    if (not defined $article->article_id)
    {
        return $self->_registerRoot($article);
    }
    else
    {
        return $self->_registerRootWithRels($article, qw(status lockTable template comments revisionMeta));
    }
}

sub add_object
{
    my $self = shift;
    croak('add_object() got no objects') if not @_;
    return $self->_registerObjects(@_);
}

sub delete_object
{
    my $self = shift;
    croak('delete_object() got no objects') if not @_;
    return $self->_deleteObjects(@_);
}

sub commit
{
    my $self = shift;
    $self->_commit;
    return $self->_root;
}

sub article
{
    my $self = shift;
    return $self->_root;
}

# Ensure that relations has an article_id, called by our parent while comitting.
sub _addRootID
{
    my($self,$obj,$newRoot) = @_;

    $newRoot //= $self->_root;

    foreach my $e (qw(article_id module_id))
    {
        if ($obj->can($e))
        {
            try
            {
                if (not defined $obj->get_column($e))
                {
                    if(not defined($newRoot->get_column('article_id')))
                    {
                        if(not $obj eq $newRoot)
                        {
                            warn('Deps hitting DB before root. Unable to _addRootID');
                        }
                    }
                    else
                    {
                        $obj->set_column($e,$newRoot->article_id);
                    }
                }
            };
        }
    }
}

# Ensure that any existing live article gets replaced with this one
after '_commit' => sub
{
    my $self = shift;
    if ($self->_root->status_id == 2)
    {
        my $rs = $self->_root->result_source->resultset->search({
            article_id => $self->_root->article_id,
            status_id => 2
            });
        while(my $art = $rs->next)
        {
            next if $art->revision == $self->revision;
            $art->set_column('status_id',4);
            $art->update();
        }
    }
};

1;
