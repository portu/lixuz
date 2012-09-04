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

package LIXUZ::Controller::Admin::Files::Upload;

use strict;
use warnings;
use 5.010;
use base qw(Catalyst::Controller::FormBuilder);
use LIXUZ::HelperModules::Forms qw(finalize_form);
use LIXUZ::HelperModules::Includes qw(add_jsIncl add_cssIncl add_jsOnLoad);
use LIXUZ::HelperModules::Fields;
use LIXUZ::HelperModules::FileUploader qw(ERR_DIRNOTFOUND ERR_WRITEFAILURE);
use constant {
    TYPE_FILE        => 5,
    TYPE_TEMPLATE    => 6,
};

sub index : Path Args(0)
{
    my ( $self, $c ) = @_;
    my $classes = $c->model('LIXUZDB::LzFileClass');
    if ($classes->count == 1)
    {
        my $redirTo = '/admin/files/upload/'.$classes->first->id;
        my @params;
        if ($c->req->param('asyncUpload'))
        {
            push(@params,'asyncUpload=1');
        }
        if(defined $c->req->param('artid'))
        {
            push(@params,'artid='.$c->req->param('artid'));
        }
        if (@params)
        {
            $redirTo .= '/?'.join('&',@params);
        }
        $c->res->redirect($redirTo);
        $c->detach;
    }
    $c->stash->{classes} = $classes;
    $c->stash->{template} = 'adm/files/selectClass.html';
    if ($c->req->param('asyncUpload'))
    {
        $c->stash->{onlySkeletonHTML} = 1;
    }
    if(defined $c->req->param('artid') && $c->req->param('artid') !~ /\D/)
    {
        $c->stash->{artid} = $c->req->param;
    }
}

sub upload : Path Args(1) Form('/files/edit')
{
    my($self,$c,$fileClassID) = @_;
    $c->stash->{fileClassID} = $fileClassID;
    if(not $c->model('LIXUZDB::LzFileClass')->find({ id => $fileClassID }))
    {
        die; #FIXME
    }
    my $i18n = $c->stash->{i18n};
    my $fields = LIXUZ::HelperModules::Fields->new($c,'files',$fileClassID);
    $fields->editorInit();
    if ($c->req->param('asyncUpload'))
    {
        $c->stash->{onlySkeletonHTML} = 1;
    }
    if (not $c->req->param('multiFileUpload_submitted'))
    {
        my $data = $c->forward(qw(LIXUZ::Controller::Admin::Files::Edit get_forminfo), []);
        my($populate,$fields) = @{$data};
        finalize_form($self->formbuilder,$c,{
                fields => $fields,
                fieldvalues => $populate,
            });
        add_jsIncl($c,'files.js');
        add_jsOnLoad($c,'addFile');
        $c->stash->{template} = 'adm/files/multiUpload.html';
        my $defaultFolder;
        if (defined $c->req->param('folder'))
        {
            $defaultFolder = $c->req->param('folder');
        }
        if(defined $c->req->param('artid'))
        {
            $c->stash->{artid} = $c->req->param('artid');
            if(not $defaultFolder)
            {
                my $art = $c->model('LIXUZDB::LzArticle')->find({ article_id => $c->stash->{artid} });
                if ($art)
                {
                    $defaultFolder = $art->folder->folder_id;
                }
            }
        }
        my $folders = $c->forward(qw(LIXUZ::Controller::Admin::Services buildtree), [ $defaultFolder, undef, 'write' ]);
        $folders = '<option value=""></option>'.$folders;
        $c->stash->{folder_list} = [ $folders ];
        return;
    }
    my $files = $c->req->param('totalFileEntries');
    if (not defined $files or $files =~ /\D/ or $files == 0)
    {
        die("zero files submitted to multiUpload");
    }
    my $form = $self->formbuilder;
    my $info = $c->forward(qw(LIXUZ::Controller::Admin::Files::Edit get_input_settings) ,[$form,'files']);
    for my $fno (1..$files)
    {
        foreach my $file ($c->req->upload('upload_file_no_'.$fno))
        {
            my $fnam = $file->filename;
            my $obj = $self->handleData($c,$fnam,$file);
            foreach my $i (keys %{$info})
            {
                $obj->set_column($i,$info->{$i});
            }
            my $fields = LIXUZ::HelperModules::Fields->new($c,'files',$obj->file_id);
            $fields->saveData();
            $obj->update();
        }
    }
    if ($c->req->param('asyncUpload'))
    {
        $c->stash->{template} = 'adm/files/multiUploadFinalFrame.html';
    }
    else
    {
        $c->detach(qw(LIXUZ::Controller::Admin::Files messageToList),[ $i18n->get('File(s) successfully uploaded') ]);
    }
}

sub handleData : Private
{
    my($self,$c,$fileName,$upload) = @_;
    my $settings = {
        asyncUpload => $c->req->param('asyncUpload'),
        artid => $c->req->param('artid'),
    };
    my $fUploader = LIXUZ::HelperModules::FileUploader->new(c => $c);
    my ($obj,$error) = $fUploader->upload($fileName,$upload,$settings);
    if ($error)
    {
        $self->error($c,$obj,$error->{error},$error->{system});
    }
    return $obj;
}

sub receiveFile : Private
{
    my ($self, $c, $form) = @_;
    my $fileObj = $c->model('LIXUZDB::LzFile');
    my $fileName = $form->fields->{'file_upload'};
    my $upload = $c->req->upload('file_upload');
    $fileObj = $self->handleData($c,$fileName,$upload);
    if ($c->req->param('asyncUpload'))
    {
        $c->response->redirect('/admin/files/edit/'.$fileObj->file_id.'?asyncUpload=true');
    }
    else
    {
        $c->response->redirect('/admin/files/edit/'.$fileObj->file_id);
    }
    $c->detach();
}

sub error : Private
{
    my ($self, $c, $fileObj, $error, $info) = @_;
    my $i18n = $c->stash->{i18n};
    my $message;
    $c->stash->{template} = 'adm/core/dummy.html';
    if ($error == ERR_DIRNOTFOUND)
    {
        $message = $i18n->get('The target directory for files was not found or was not writable. Contact the system administrator.');
        $c->log->error('ERR_DIRNOTFOUND: Failed to find or verify perms of target file dir: '.$info);
    }
    elsif($error == ERR_WRITEFAILURE)
    {
        $message = $i18n->get_advanced('An error occurred while writing data to disk: %(PERLIO_ERROR)', { PERLIO_ERROR => $info });
        $c->log->error('ERR_WRITEFAILURE: Failure while writing file: '.$info);
    }
    elsif( $error == TYPE_TEMPLATE ) 
    {
        $message = $i18n->get('Templates must be of htm, html or xml type');
        $c->log->error('TYPE_TEMPLATE: Bad template type: '.$info);
    }
    else
    {
        $message = $i18n->get_advanced('An internal unknown fatal error (ID %(ERRID)) occurred',{ERRID => $error});
        $c->log->error('UNKNOWN_ERROR: Unknown error ID: '.$error);
    }
    $c->stash->{content} = '<br /><br /><center>'.$i18n->get_advanced('<b>Fatal error:</b><br />%(ERROR_MESSAGE)',{ERROR_MESSAGE => $message}).'</center><br /><br />';
    if ($fileObj)
    {
        $fileObj->delete;
    }
}

1;
