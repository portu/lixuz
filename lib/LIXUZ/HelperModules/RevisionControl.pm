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
# This file contains the guts of our revisions handling. It performs
# object copying, committing new revisions, and all related internal
# functions.
#
# The RevisionControl class is almost exclusively the 'guts', and has
# few public methods
#
# See submodules for the public interface
package LIXUZ::HelperModules::RevisionControl;
use Moose;
use Try::Tiny;
use Carp qw(croak carp);
use constant { true => 1, false => 0 };
use 5.010;

has 'revision' => (
    isa => 'Maybe[Int]',
    is => 'rw',
    lazy => true,
    builder => '_getRevision',
    );

has 'newRevision' => (
    isa => 'Int',
    is => 'rw',
    lazy => true,
    builder => '_getNewRevision',
    );

has 'committer' => (
    isa => 'Int',
    is => 'rw',
    required => 1,
);

has '_objects' => (
    isa => 'HashRef',
    is => 'rw',
    default => sub { {} },
    );

has '_root' => (
    isa => 'Object',
    is => 'rw',
    );

has '_commitRetryCount' => (
    isa => 'Int',
    is => 'rw',
    default => 0,
    );

sub find_or_create
{
    my $self = shift;
    my $name = shift;
    my $hash = shift;

    $hash->{revision} = $self->revision;

    return $self->_getSchema($name)->find_or_new($hash);
}

sub find_or_new
{
    my $self = shift;
    return $self->find_or_create(@_);
}

sub find
{
    my $self = shift;
    my $name = shift;
    my $hash = shift;

    $hash->{revision} = $self->revision;

    return $self->_getSchema($name)->find($hash);
}

sub _getSchema
{
    my $self = shift;
    my $name = shift;
    $name =~ s/^LIXUZDB:://;

    return $self->_root->result_source->schema->source($name)->resultset;
}

# ---
# Internal, for use in subclasses
# ---
sub _getRevision
{
    my $self = shift;
    my $root = $self->_root;
    return $root->revision;
}

sub _getNewRevision
{
    my $self = shift;
    my $curr = $self->revision;
    if(not defined $curr)
    {
        return 0;
    }
    return $curr +1;
}

# XXX: TODO: Use DBIx::Class::Storage::TxnScopeGuard
sub _commit
{
    my $self = shift;
    my %newObjs;
    my $newRoot;
    foreach my $t(qw(_typeName _idColumn))
    {
        croak("$t missing in parent\n") if not $self->can($t);
    }
    $self->_root->result_source->schema->txn_begin;
    my $retVal;
    my $return;
    try
    {
        my @triggers;
        $self->_root->result_source->schema->txn_do(sub
        {
            # Store object list in a hash
            my %objects = %{$self->_objects};
            # The array that will contain the final object list for looping
            my @objects;
            # Loop over the object list hash, ensuring that the root object ends
            # up at the start of the array.
            while(my ($entry, $obj) = each(%objects))
            {
                if ($obj eq $self->_root)
                {
                    unshift(@objects, $obj);
                }
                else
                {
                    push(@objects, $obj);
                }
            }
            # Loop through all objects, copying and saving them with the new revision
            foreach my $obj (@objects)
            {
                # _addRootID is a special subroutine used when comitting revision 0.
                # Some of our objects might not have the relationship ID set (ie. the one that
                # ensures their relation to the root object). _addRootID in our child class will
                # add this to the object as needed, ensuring that comitting a brand new object works.
                if ($self->can('_addRootID'))
                {
                    $self->_addRootID($obj,$newRoot);
                }
                my $new = $self->_copyObject($obj);
                if ($new->can('__disableItrig'))
                {
                    $new->__disableItrig(1);
                    push(@triggers,$new);
                }
                $new->insert;
                my $entry = $self->_dbicPortableID($new);
                if ($self->_dbicCompare($obj,$self->_root))
                {
                    $newRoot = $new;
                }
                $newObjs{$entry} = $new;
            }

            if(not $newRoot)
            {
                my $rootId = $self->_dbicPortableID($self->_root);
                if(not defined $self->_objects->{$rootId})
                {
                    croak("LZ_FATAL Transaction did not touch any root object (there was no root object in _objects)!\n");
                }
                else
                {
                    croak("LZ_FATAL Transaction did not touch any root object!\n");
                }
            }

            my $rev = $self->_getSchema('LzRevision')->create({
                    type => $self->_typeName,
                    type_revision => $self->newRevision,
                    is_latest => 1,
                    is_latest_in_status => 1,
                    type_id => $newRoot->get_column($self->_idColumn),
                    committer => $self->committer,
                });

            $self->_getSchema('LzRevision')->search({
                    type_id => $rev->type_id,
                    is_latest => 1,
                    type_revision => { '!=' => $self->newRevision },
                })->update({ is_latest => 0 });

            if ($self->_typeName eq 'article')
            {
                $self->_getSchema('LzArticle')->search({
                        article_id => $rev->type_id,
                        status_id => $newRoot->status_id,
                        revision => { '!=' => $self->newRevision },
                        'revisionMeta.is_latest_in_status' => 1
                    }, { join => 'revisionMeta' })->search_related('revisionMeta')->update({ is_latest_in_status => 0 });
            }
        }); # End of txn_do block
        # Transaction succeeded, trigger indexer
        # (would normally be auto-triggered, but we override it)
        foreach my $t (@triggers)
        {
            $t->__triggerIndex;
        }
    }
    catch
    {
        my $err = $_;
        my $fatal;
        if ($err =~ /Rollback\sfailed/)
        {
            $fatal = "[FAILED] Rollback of transaction failed! Bailing out. Error: $err";
        }
        elsif($err =~ s/LZ_FATAL\s*//)
        {
            $fatal = "[FAILED] Failed to commit transaction. Block threw fatal exception: ".$err;
        }
        elsif ($self->_commitRetryCount == 4)
        {
            $fatal = "[FAILED] Failed to commit transaction after four retries. Bailing out. Error: $err\n";
        }
        if ($fatal)
        {
            # Clean up what we can, this is in no way complete.
            try
            {
                if ($self->_typeName eq 'article')
                {
                    $self->_getSchema('LzArticle')->find({
                            article_id => $self->_root->get_column($self->_idColumn),
                            revision => $self->newRevision
                        })->delete();
                }
                $self->_getSchema('LzRevision')->find({
                        type_id => $self->_root->get_column($self->_idColumn),
                        type_revision => $self->newRevision,
                        type => $self->_typeName
                    })->delete();
            };
            croak($fatal);
        }
        $err =~ s/\n$//;
        warn('[Retry] Transaction failed: '.$err.' - will retry it'."\n");
        $self->_commitRetryCount( $self->_commitRetryCount +1 );
        $retVal = $self->_commit(@_);
        $return = 1;
    };
    if ($return)
    {
        return $retVal;
    }
    warn('Revision '.$self->newRevision.' committed');
    $self->_root($newRoot);
    $self->_objects(\%newObjs);
    $self->revision($self->newRevision);
    $self->newRevision($self->revision +1);
    $self->_commitRetryCount(0);
    return $self->revision;
}

sub _validateRevisionTree
{
}

sub _registerRootWithRels
{
    my $self = shift;
    my $root = shift;
    $self->_registerRoot($root);
    $self->_registerObjectWithRels($root,@_);
}

sub _registerRoot
{
    my $self = shift;
    my $object = shift;
    $self->_root($object);
    return $self->_registerObject($object);
}

sub _copyObject
{
    my $self = shift;
    my $obj = shift;

    my $entries = $obj->to_hash(true);
    $entries->{revision} = $self->newRevision;
    my $new = $obj->result_source->resultset->new_result($entries);
    return $new;
}

sub _registerObjectWithRels
{
    my $self = shift;
    my $object = shift;
    my @ignore = @_;
    if (! $self->_dbicCompare($object,$self->_root))
    {
        $self->_registerObject($object);
    }
    my @rels = $object->result_source->relationships;
    foreach my $rel (@rels)
    {
        if(grep { $rel eq $_ } @ignore)
        {
            next;
        }
        if ($object->can($rel))
        {
            no strict 'refs';
            my $ret = $object->$rel;
            use strict 'refs';
            $self->_registerObjects($ret);

        }
    }
}

sub _registerObjects
{
    my $self = shift;
    @_ = $self->_resultsetArray(@_);
    foreach my $o (@_)
    {
        $self->_registerObject($o);
    }
}

sub _registerObject
{
    my $self = shift;
    my $obj = shift;

    my $id = $self->_dbicPortableID($obj);
    $self->_objects->{$id} = $obj;
}

sub _deleteObject
{
    my $self = shift;
    my $obj = shift;

    my $id = $self->_dbicPortableID($obj);
    delete($self->_objects->{$id});
}

sub _deleteObjects
{
    my $self = shift;
    @_ = $self->_resultsetArray(@_);
    foreach my $o (@_)
    {
        $self->_deleteObject($o);
    }
}

sub _dbicPortableID
{
    my $self = shift;
    my $obj = shift;
    my @id = ($obj->result_source->from);

    if ($obj->id)
    {
        push(@id, $obj->id);
    }
    else
    {
        push(@id, ref($obj));
    }

    return join('-',sort(@id));
}

sub _dbicCompare
{
    my $self = shift;
    my $obj1 = shift;
    my $obj2 = shift;

    if($self->_dbicPortableID($obj1) eq $self->_dbicPortableID($obj2))
    {
        return true;
    }
    return false;
}

sub _resultsetArray
{
    my $self = shift;
    my @array;

    foreach my $rs (@_)
    {
        next if not defined $rs;
        if ($rs->isa('DBIx::Class::ResultSet'))
        {
            while(my $e = $rs->next)
            {
                push(@array,$e);
            }
        }
        else
        {
            push(@array,$rs);
        }
    }
    if(wantarray())
    {
        return @array;
    }
    else
    {
        return \@array;
    }
}

__PACKAGE__->meta->make_immutable;
1;
