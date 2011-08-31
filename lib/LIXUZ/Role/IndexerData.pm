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

package LIXUZ::Role::IndexerData;
use Moose::Role;

has 'mode' => (
    isa => 'Str',
    is => 'rw',
    default => 'internal',
);
has 'c' => (
    isa => 'Maybe[Object]',
    is => 'rw',
    weak_ref => 1,
);

sub _getIndexID
{
    my $self = shift;
    my $object = shift;
    my $id;
    if ($object->isa('LIXUZ::Model::LIXUZDB::LzArticle'))
    {
        $id = 'article_'.$object->article_id;
        if ($self->mode eq 'internal')
        {
            $id .= '_'.$object->revision;
        }
    }
    elsif($object->isa('LIXUZ::Model::LIXUZDB::LzFile'))
    {
        $id = 'file_'.$object->file_id;
    }
    else
    {
        croak('Invalid object type ('.ref($object).')');
    }
    return $id;
}

sub _parseIndexID
{
    my $self = shift;
    my $id = shift;
    return if not $id;
    my @IDs = split(/_/,$id);
    return @IDs;
}
1;
