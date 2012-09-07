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

package LIXUZ::Controller::Admin::Templates;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
BEGIN { extends 'Catalyst::Controller::FormBuilder' };
with 'LIXUZ::Role::List::Database';

use LIXUZ::HelperModules::JSON qw(json_response json_error);
use LIXUZ::HelperModules::Includes qw(add_jsIncl);

# Summary: Displays the template list
sub index : Path Args(0) Form('/core/search')
{
    my ( $self, $c, $query ) = @_;

    my $template = $c->model('LIXUZDB::LzTemplate');
    my $list = $self->handleListRequest($c,{
            c => $c,
            query => $query,
            object => $template,
            objectName => 'templates',
            template => 'adm/templates/index.html',
            orderParams => [qw(template_id name type)],
            paginate => 1,
        });
    $c->stash->{template} = 'adm/templates/index.html';
    my $i18n = $c->stash->{i18n};
    $c->stash->{pageTitle} = $i18n->get('Templates');
	add_jsIncl($c,'templates.js');
}

# Summary: Sets the default template for a type
sub setDefault : Local Param
{
    my ($self, $c, $templateId) = @_;
    my $template = $c->model('LIXUZDB::LzTemplate')->find({ template_id => $templateId });
    my $current = $c->model('LIXUZDB::LzTemplate')->search({ is_default => 1, type => $template->type });
    while((defined $current) && (my $e = $current->next))
    {
        $e->set_column('is_default',0);
        $e->update();
    }
    $template->set_column('is_default',1);
    $template->update();
    return json_response($c);
}
1;
