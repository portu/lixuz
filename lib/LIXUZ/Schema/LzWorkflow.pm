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

package LIXUZ::Schema::LzWorkflow;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';


=head1 NAME

LIXUZ::Schema::LzWorkflow

=cut

__PACKAGE__->table("lz_workflow");

=head1 ACCESSORS

=head2 article_id

  data_type: 'integer'
  is_nullable: 0

=head2 priority

  data_type: 'tinyint'
  is_nullable: 1

=head2 deadline

  data_type: 'datetime'
  is_nullable: 1

=head2 hours_estimated

  data_type: 'integer'
  is_nullable: 1

=head2 hours_used

  data_type: 'integer'
  is_nullable: 1

=head2 start_date

  data_type: 'datetime'
  is_nullable: 1

=head2 assigned_by

  data_type: 'integer'
  is_nullable: 1

=head2 assigned_to_user

  data_type: 'integer'
  is_nullable: 1

=head2 assigned_to_role

  data_type: 'integer'
  is_nullable: 1

=head2 revision

  data_type: 'integer'
  default_value: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "article_id",
  { data_type => "integer", is_nullable => 0 },
  "priority",
  { data_type => "tinyint", is_nullable => 1 },
  "deadline",
  { data_type => "datetime", is_nullable => 1 },
  "hours_estimated",
  { data_type => "integer", is_nullable => 1 },
  "hours_used",
  { data_type => "integer", is_nullable => 1 },
  "start_date",
  { data_type => "datetime", is_nullable => 1 },
  "assigned_by",
  { data_type => "integer", is_nullable => 1 },
  "assigned_to_user",
  { data_type => "integer", is_nullable => 1 },
  "assigned_to_role",
  { data_type => "integer", is_nullable => 1 },
  "revision",
  { data_type => "integer", default_value => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("article_id", "revision");


# Created by DBIx::Class::Schema::Loader v0.07002 @ 2011-01-17 10:17:20
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:hGvH07r4bxiQm7qEuIdELQ

__PACKAGE__->belongs_to('article' => 'LIXUZ::Schema::LzArticle',{ 'foreign.article_id' => 'self.article_id', 'foreign.revision' => 'self.revision' });
__PACKAGE__->belongs_to('role' => 'LIXUZ::Schema::LzRole',{'foreign.role_id' => 'self.assigned_to_role'});
__PACKAGE__->belongs_to('user' => 'LIXUZ::Schema::LzUser',{'foreign.user_id' => 'self.assigned_to_user'});
__PACKAGE__->belongs_to('assigned_by_user' => 'LIXUZ::Schema::LzUser', { 'foreign.user_id' => 'self.assigned_by' });

use Moose;
with 'LIXUZ::Role::Serializable';

# Summary: Get all fields in a hash
# Usage: object->get_everything();
# Returns: Hash with field => value pairs.
sub get_everything
{
    my $self = shift;
    my %Return;
	# TODO: Split this method into two, one which returns objects, one that returns things suitable for JSON magic
    foreach my $col( qw(article_id assigned_to priority deadline hours_estimated hours_used start_date assigned_by) )
    {
        $Return{$col} = $self->get_column($col);
    }
    return(\%Return);
}

# Summary: Get a string representing the user or role that our article
# is assigned to.
sub assigned_to_string
{
    my $self = shift;
    my $c = shift or die('assigned_to_string: needs $c');
    my $userNameOnly = shift;
    my $nameOnly = shift;
    if ($self->assigned_to_user)
    {
        if(not $self->user)
        {
            return $c->stash->{i18n}->get('(user not found)');
        }
        if ($userNameOnly)
        {
            return $self->user->user_name;
        }
        elsif($nameOnly)
        {
            return $self->user->name;
        }
        else
        {
            return $self->user->name.' ('.$self->user->user_name.')';
        }
    }
    elsif($self->assigned_to_role)
    {
        return $c->stash->{i18n}->get_advanced('%(ROLE_NAME) (role)', { ROLE_NAME => $self->role->role_name});
    }
    else
    {
        return $c->stash->{i18n}->get('(nobody)');
    }
}

# Summary: Get a string representing the user that assigned our article
sub assigned_by_string
{
    my $self = shift;
    my $c = shift or die('assigned_by_string: needs $c');
    if ($self->assigned_by && $self->assigned_by_user)
    {
        return $self->assigned_by_user->user_name;
    }
    return $c->stash->{i18n}->get('(nobody)');
}

# Summary: Check if the current user can write to this article
sub can_write
{
    my ($self, $c) = @_;
    # A super user can do anything she likes
    return 1 if ($c->user->super_user);

    if(not $self->article->can_read($c))
    {
        return;
    }

    # Check if the current user exists in any of the fields
    if(defined $self->get_column('assigned_to_user') and $self->get_column('assigned_to_user') == $c->user->user_id)
    {
        return 1;
    }
    elsif(defined $self->get_column('assigned_to_role') and $self->get_column('assigned_to_role') == $c->user->role->role_id)
    {
        return 1;
    }
    elsif(not defined $self->assigned_by)
    {
        return 1;
    }
    elsif($c->user->can_access('EDIT_OTHER_ARTICLES'))
    {
        return 1;
    }
    return;
}

# You can replace this text with custom content, and it will be preserved on regeneration
1;


# You can replace this text with custom content, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
