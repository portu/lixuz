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

package LIXUZ::HelperModules::TemplateRenderer::Resolver::Comment;
use Moose;
with 'LIXUZ::Role::TemplateRenderer::Resolver';

use LIXUZ::HelperModules::Live::Comments qw(comment_handler);
use LIXUZ::HelperModules::Calendar qw(datetime_from_SQL_to_unix);
use HTML::Entities qw(decode_entities);
use Carp;
use constant { true => 1, false => 0 };

sub get
{
    my($self,$type,$params) = @_;

    # TODO: Replace with given/when when we've migrated to 5.10
    if($type eq 'list')
    {
        return $self->get_list($params);
    }

    die('Unknown data request: '.$type);
}

sub get_list
{
    my($self,$searchContent) = @_;

    my $saveAs = $searchContent->{as};
    if(not $saveAs)
    {
        $self->log('Resolver Comment list: No as= parameter for data, ignoring request. Template might crash.');
        return;
    }
    if ($self->renderer->has_var($saveAs))
    {
        return;
    }
    my $limit = $searchContent->{limit} ? $searchContent->{limit} : 10;
    my $res = $self->c->model('LIXUZDB::LzLiveComment')->search(undef,{ rows => $limit, order_by => 'comment_id DESC'});
    return { $saveAs => $res };
}

__PACKAGE__->meta->make_immutable;
1;
