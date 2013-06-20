# LIXUZ content management system
# Copyright (C) Utrop A/S Portu media & Communications 2013
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

package LIXUZ::HelperModules::TemplateRenderer::Resolver::Category;
use Moose;
with 'LIXUZ::Role::TemplateRenderer::Resolver';
use Carp;
use constant { true => 1, false => 0 };

sub get
{
    my($self,$type,$params) = @_;

    if($type eq 'get')
    {
        return $self->get_category($params);
    }

    die('Unknown data request: '.$type);
}

sub get_category
{
    my($self,$searchContent) = @_;
    my $c = $self->c;

    my $saveAs = $searchContent->{as};
    if(not $saveAs)
    {
        $self->log('Resolver Category get: No as= parameter for data, ignoring request. Template might crash.');
        return;
    }
    if ($self->renderer->has_var($saveAs))
    {
        return;
    }
    if (!defined($searchContent->{from}))
    {
        $self->log('Resolver Category get: No from= parameter for data, ignoring request. Template might crash.');
        return;
    }
    elsif($searchContent->{from} ne 'url')
    {
        $self->log('Resolver Category get: Unknown from= value ("'.$searchContent->{from}.'") for data, ignoring request. Template might crash.');
        return;
    }
    my $category = $self->renderer->get_statevar('category');
    if (!$category)
    {
        $self->log('Resolver Category get: Unable to complete request: no category statevar, this could be a bug in Lixuz');
        return;
    }
    return { $saveAs => $c->model('LIXUZDB::LzCategory')->find({ category_id => $category->category_id }) };
}

__PACKAGE__->meta->make_immutable;
1;
