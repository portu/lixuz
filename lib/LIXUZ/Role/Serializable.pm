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

package LIXUZ::Role::Serializable;
use Moose::Role;
use JSON::Any;
use Try::Tiny;
use 5.010;

=cut
The value for this array ref are names of methods on the object.
The methods can lead to related DBIC tables, or simply be a method returning
a value.

If you want the result to be saved as something other than the sub, you can
make the entry a hashref, in the form:
{ saveAs => 'name to save value as in serialized verison', source => 'sub to get data from' }
=cut
sub _serializeExtra
{
    return [];
}

sub serialize
{
    my $self = shift;
    my $j = JSON::Any->new;
    my $encoded;
    try
    {
        $encoded = $j->encode($self->to_hash);
    }
    catch
    {
        given($_)
        {
            # Got a scalar reference in our hash, but the JSON lib doesn't
            # know how to handle that. Remove the reference and try again.
            when(/cannot encode reference to scalar/)
            {
                my $href = $self->to_hash;
                foreach my $k (keys %{$href})
                {
                    if(ref($href->{$k}) eq 'SCALAR')
                    {
                        $href->{$k} = undef;
                    }
                }
                $encoded = $j->encode($href);
            }

            default
            {
                die($_);
            }
        }
    };
    return $encoded;
}

sub to_hash
{
    my $self = shift;
    my $ignoreRels = shift;
    my $rels = $self->_serializeExtra;

    my %hash = $self->get_columns();

    if(not $ignoreRels)
    {
        foreach my $rel (@{$rels})
        {
            my $saveAs = $rel;
            if(ref($rel))
            {
                $saveAs = $rel->{saveAs};
                $rel = $rel->{source};
            }
            my $obj = $self->$rel;
            if(ref($obj) && $obj->can('to_hash'))
            {
                $hash{$saveAs} = $obj->to_hash;
            }
            elsif (!ref($obj))
            {
                $hash{$saveAs} = $obj;
            }
        }
    }
    return \%hash;
}

1;
