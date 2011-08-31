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

package LIXUZ::Schema::LzNewsletterSubscription;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';


=head1 NAME

LIXUZ::Schema::LzNewsletterSubscription

=cut

__PACKAGE__->table("lz_newsletter_subscription");

=head1 ACCESSORS

=head2 subscription_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 email

  data_type: 'varchar'
  is_nullable: 0
  size: 254

=head2 name

  data_type: 'varchar'
  is_nullable: 0
  size: 254

=head2 format

  data_type: 'enum'
  default_value: 'text'
  extra: {list => ["text","html"]}
  is_nullable: 0

=head2 send_every

  data_type: 'enum'
  default_value: 'week'
  extra: {list => ["month","week","day"]}
  is_nullable: 0

=head2 last_sent

  data_type: 'datetime'
  is_nullable: 1

=head2 validation_hash

  data_type: 'varchar'
  is_nullable: 1
  size: 100

=head2 validated

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "subscription_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "email",
  { data_type => "varchar", is_nullable => 0, size => 254 },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 254 },
  "format",
  {
    data_type => "enum",
    default_value => "text",
    extra => { list => ["text", "html"] },
    is_nullable => 0,
  },
  "send_every",
  {
    data_type => "enum",
    default_value => "week",
    extra => { list => ["month", "week", "day"] },
    is_nullable => 0,
  },
  "last_sent",
  { data_type => "datetime", is_nullable => 1 },
  "validation_hash",
  { data_type => "varchar", is_nullable => 1, size => 100 },
  "validated",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("subscription_id");


# Created by DBIx::Class::Schema::Loader v0.07002 @ 2011-01-17 10:17:20
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Q7F9kH5k8kZcXDHR5Par0w
use Digest::SHA qw(sha1_hex);
use LIXUZ::HelperModules::EMail qw(send_raw_email_to);
use LIXUZ::HelperModules::Calendar qw(datetime_from_SQL datetime_from_unix datetime_to_SQL);
use HTML::Entities qw(decode_entities);
use LIXUZ::HelperModules::Text qw(sanitizeStringLength);
use LIXUZ::HelperModules::HTMLFilter qw(filter_string);
use LIXUZ::HelperModules::Cache qw(get_ckey CT_24H);
use LIXUZ::HelperModules::Live::Articles qw(get_live_articles_from);
use POSIX qw(strftime);
use utf8;

__PACKAGE__->has_many('categories' => 'LIXUZ::Schema::LzNewsletterSubscriptionCategory', 'subscription_id');
__PACKAGE__->has_many('groups' => 'LIXUZ::Schema::LzNewsletterSubscriptionGroup', 'subscription_id');

sub generateValidationHash
{
    my $self = shift;

    my $rawString = $self->subscription_id.'-'.time().'-'.$self->email.'-'.$self->name.$self->format;
    my $hashed = sha1_hex($rawString);
    $self->set_column('validation_hash',$hashed);
    $self->update();
    return $hashed;
}

sub get_validation_hash
{
    my $self = shift;
    if (my $h = $self->validation_hash)
    {
        return $h;
    }
    else
    {
        return $self->generateValidationHash;
    }
}

sub send_email
{
    my ($self,$c,$type,$subject,$content,$sender) = @_;

    return send_raw_email_to($c,$subject,$content,$self->email,$sender,$type);
}

sub validate
{
    my $self = shift;
    my $hash = shift;
    if (defined $hash and $hash eq $self->get_validation_hash)
    {
        $self->set_column('validated',1);
        $self->update();
        return 1;
    }
    else
    {
        return;
    }
}

sub unsubscribe
{
    my $self = shift;
    my $hash = shift;
    if (defined $hash and $hash eq $self->get_validation_hash)
    {
        $self->delete();
        return 1;
    }
    else
    {
        return 0;
    }
}

sub subscribeToCategories
{
    my $self = shift;
    my $c = shift;

    my $cats = $self->categories;

    while((defined $cats) && (my $cat = $cats->next))
    {
        $cat->delete();
    }

    if(not @_)
    {
        $c->log->error('Attempt to subscribeToCategories() with no categories');
        return;
    }

    foreach my $catId (@_)
    {
        if ($c->model('LIXUZDB::LzCategory')->find({category_id => $catId}))
        {
            $c->model('LIXUZDB::LzNewsletterSubscriptionCategory')->create({
                    subscription_id => $self->subscription_id,
                    category_id => $catId,
                });
        }
        else
        {
            $c->log->warn('Attempted to subscribe newsletter to invalid catId: '.$catId);
        }
    }
    return 1;
}

sub categoryString
{
    my ($self) = @_;
    my @categories;
    my $cats = $self->categories;

    while((defined $cats) && (my $cat = $cats->next))
    {
        push(@categories,$cat->category_id);
    }
    my $str = join(',',sort(@categories));
    return $str ? $str : '';
}

# You can replace this text with custom content, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
