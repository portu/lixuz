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

package LIXUZ::Controller::Admin::Files::Classes;
use 5.010;
use Moose;
use MooseX::NonMoose;
BEGIN { extends 'Catalyst::Controller::FormBuilder' };
with 'LIXUZ::Role::List::Database';

use LIXUZ::HelperModules::Forms qw(finalize_form);
use LIXUZ::HelperModules::DragDrop;
use LIXUZ::HelperModules::Lists qw(reply_json_list);
use LIXUZ::HelperModules::Includes qw(add_jsIncl add_cssIncl add_jsOnLoad add_globalJSVar add_jsOnLoadHeadCode);
use LIXUZ::HelperModules::Calendar qw(create_calendar datetime_to_SQL datetime_from_SQL datetime_from_unix);
use LIXUZ::HelperModules::Editor qw(create_editor);
use LIXUZ::HelperModules::JSON qw(json_response json_error);
use LIXUZ::HelperModules::Fields;
use LIXUZ::HelperModules::HTMLFilter qw(filter_string);
use constant { true => 1, false => 0};

sub index : Path Args(0) Form('/core/search')
{
    my ( $self, $c, $query ) = @_;
    my $classes = $c->model('LIXUZDB::LzFileClass');
    my $obj = $self->handleListRequest($c,{
            c => $c,
            query => $query,
            object => $classes,
            objectName => 'classes',
            template => 'adm/files/classes/index.html',
            orderParams => [qw(id name)],
            searchColumns => [qw(id name)],
            folderType => 'builtin',
            paginate => 1,
        });
}

sub savedata
{
    my ($self, $c) = @_;
    my %data = ( 
        name => $c->req->param('name'),
        id => $c->req->param('class_id')
    );

    my $fileClass;

    my $redir = '/admin/files/classes';
    if(defined $data{id} && length($data{id}))
    {
        $fileClass = $c->model('LIXUZDB::LzFileClass')->find({ id => $data{id} });
        $fileClass->set_column('name',$data{name});
        $fileClass->update();
    }
    else
    {
        $fileClass = $c->model('LIXUZDB::LzFileClass')->create({ name => $data{name} });
        $fileClass->update();
        $redir .= '/edit/'.$fileClass->id.'?editFields=1';
    }
    $c->res->redirect($redir);
    $c->detach();
}

sub checkSavedata
{
    my($self,$c) = @_;
    if ($c->req->param('class_submit'))
    {
        $self->savedata($c);
    }
}

sub add : Local
{
    my ($self, $c) = @_;
    $self->checkSavedata($c);
    $c->stash->{template} = 'adm/files/classes/edit.html';
    add_jsIncl($c, qw(utils.js));
}

sub edit : Args(1) Local
{
    my ($self, $c,$fileID) = @_;
    $self->checkSavedata($c);
    my $fileClass = $c->model('LIXUZDB::LzFileClass')->find({ id => $fileID });
    if ($fileClass)
    {
        $c->stash->{values} = {
            id => $fileClass->id,
            name => $fileClass->name
        };
    }
    else
    {
        $c->res->redirect('/admin/files/classes');
        $c->detach();
    }
    if ( $c->req->param('editFields'))
    {
        $c->stash->{editFields} = 1;
    }
    $c->stash->{formType} = 'edit';
    $self->add($c);
}

sub delete : Args(1) Local
{
    my ($self, $c,$fileID) = @_;
    my $fileClass = $c->model('LIXUZDB::LzFileClass')->find({ id => $fileID });
    if ($fileClass && $fileID != 0)
    {
        $fileClass->delete();
    }
    $c->res->redirect('/admin/files/classes');
}

1;
