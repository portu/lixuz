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

package LIXUZ::Controller::Admin::Files::Edit;

use strict;
use warnings;
use base qw(Catalyst::Controller::FormBuilder);
use LIXUZ::HelperModules::Forms qw(finalize_form);
use LIXUZ::HelperModules::Fields;

use constant {
    TYPE_FILE => 1,
    TYPE_IMAGE => 2,
    };

sub default : Path('/admin/files/edit') Local Args
{
    my ( $self, $c, $uid ) = @_;
    my $i18n = $c->stash->{i18n};
    $c->stash->{pageTitle} = $c->stash->{i18n}->get('Files');
    # If we don't have an UID then just give up
    if (not defined $uid or $uid =~ /\D/)
    {
        return $c->forward('LIXUZ::Controller::Admin::Files','messageToList',[$i18n->get('Error: Failed to locate UID. The path specified is invalid.')]);
    }
    my $file = $c->model('LIXUZDB::LzFile')->find({file_id => $uid});
    if(not $file)
    {
        return $c->forward('LIXUZ::Controller::Admin::Files','messageToList',[$i18n->get('Error: That file does not exist.')]);
    }
    elsif(not $file->can_edit($c))
    {
        return $c->user->access_denied();
    }
    my $fields = LIXUZ::HelperModules::Fields->new($c,'files',$file->class_id);
    $fields->editorInit();
    if ($c->req->param('asyncUpload'))
    {
        $c->stash->{onlySkeletonHTML} = 1;
    }
    $c->stash->{fileObj} = $file;
    $c->stash->{tags} = $file->tags;
    $c->stash->{folder_list} = $c->forward(qw(LIXUZ::Controller::Admin::Services buildtree), [ $file->folder_id, undef, 'write' ]);
    if ($file->is_image())
    {
        return $c->forward('image_edit',[$file]);
    }
    else
    {
        return $c->forward('file_edit',[$file]);
    }
}

sub image_edit : Local Form('/files/edit')
{
    my($self,$c,$file) = @_;
    my $form = $self->formbuilder;
    if ($form->submitted && $form->validate)
    {
        return $self->savedata($c,$form,$file,TYPE_IMAGE);
    }
    my($populate,$fields) = $self->get_forminfo($c,$file);
    finalize_form($form,$c,{
            fields => $fields,
            fieldvalues => $populate,
        });
    $c->stash->{template} = 'adm/files/edit.html';
}

sub file_edit : Local Form('/files/edit')
{
    my($self,$c,$file) = @_;
    my $form = $self->formbuilder;
    if ($form->submitted && $form->validate)
    {
        return $self->savedata($c,$form,$file,TYPE_FILE);
    }
    my $i18n = $c->stash->{i18n};
    my($populate,$fields) = $self->get_forminfo($c,$file);
    finalize_form($form,$c,{
            fields => $fields,
            fieldvalues => $populate,
        });
    $c->stash->{template} = 'adm/files/edit.html';
}

sub get_forminfo : Private
{
    my ($self, $c, $file, $addFields) = @_;
    my $i18n = $c->stash->{i18n};
    my $Populate;

    my %Fields = (
        file_name => $i18n->get('Name'),
        title => $i18n->get('Title'),
        caption => $i18n->get('Caption'),
        status => {
            label => 'Status',
            options => [ $i18n->get('Active'),$i18n->get('Inactive') ],
        },
    );
    $c->stash->{classes} = $c->model('LIXUZDB::LzFileClass');

    if ($file)
    {
        my $defaultFolder = $file->folder_id;

        $c->stash->{folder_list} = $c->forward(qw(LIXUZ::Controller::Admin::Services buildtree), [ $defaultFolder, undef, 'write' ]);
        if(not $defaultFolder)
        {
            $c->stash->{folder_list} = '<option value="">'.$i18n->get('-select-').'</option>'.$c->stash->{folder_list};
        }
    }

    if (defined $file && $file->is_flash)
    {
        $Fields{height} = $i18n->get('Height (pixels)');
        $Fields{width}  = $i18n->get('Width (pixels)');
    }

    if ($addFields)
    {
        foreach my $k(keys %{$addFields})
        {
            $Fields{$k} = $addFields->{$k};
        }
    }

    my $populate;
    if(defined $file)
    {
        $populate = $file->get_everything;
    }
    else
    {
        $populate = {};
    }
    # We need a status
    if ($populate->{status})
    {
        $populate->{status} = $populate->{status};
    }
    else
    {
        $populate->{status} = 'Active';
    }
    if(wantarray())
    {
        return ($populate, \%Fields);
    }
    else
    {
        return ([$populate, \%Fields]);
    }
}

sub get_input_settings : Private
{
    my($self,$c,$form,$type,$file) = @_;
    my $i18n = $c->stash->{i18n};

    my $standardFields = [qw(file_name title caption)];
    my %data;
    my @fields;
    my $formFields = $form->fields;
    @fields = @$standardFields;
#    if ($type == TYPE_IMAGE)
#    {
#        my $imageFields = [];
#        @fields = (@$standardFields, @$imageFields);
#    }
#    else
#    {
#        @fields = @$standardFields;
#    }
    if ($file && $file->is_flash())
    {
        push(@fields, qw(height width));
    }
    foreach my $field (@fields)
    {
        if ($formFields->{$field})
        {
            $data{$field} = $formFields->{$field};
        }
    }
    my $fileFolder = $c->req->param('file_folder');
    if(defined $fileFolder && $fileFolder =~ /^\d+$/)
    {
        $data{folder_id} = $fileFolder;
    }
    # Handle status
    my $status;
    if ($formFields->{status} eq $i18n->get('Active') || $formFields->{status} eq 'Active')
    {
        $status = 'Active';
    }
    else
    {
        $status = 'Inactive';
    }
    $data{status} = $status;
    return \%data;
}

sub savedata : Private
{
    my($self,$c,$form,$file,$type) = @_;
    my $i18n = $c->stash->{i18n};
    my $info = $self->get_input_settings($c,$form,$type,$file);
    foreach my $i (keys %{$info})
    {
        $file->set_column($i,$info->{$i});
    }
    if(my $classID = $c->req->param('class_id'))
    {
        my $class = $c->model('LIXUZDB::LzFileClass')->find({ id => $classID });
        if(not $class)
        {
            die; # FIXME
        }
        $file->set_column('class_id',$classID);
    }
    $file->update();
    # Save additional fields
    my $fields = LIXUZ::HelperModules::Fields->new($c,'files',$file->file_id);
    $fields->saveData();

    # Sync tags with submitted data
    my $tags = $file->tags;
    while(my $tag = $tags->next)
    {
        $tag->delete();
    }
    $file->set_tags_from_param($c->req->param('formTags'));

    if ($c->req->param('asyncUpload'))
    {
        $c->response->redirect('/admin/files/edit/'.$file->file_id.'?asyncUpload=true&hasBeenSaved=1');
    }
    else
    {
        return $c->forward('LIXUZ::Controller::Admin::Files','messageToList',[$i18n->get('File saved.')]);
    }
}

1;
