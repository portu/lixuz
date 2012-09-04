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

package LIXUZ::Controller::Admin::Templates::Upload;

use strict;
use warnings;
use base qw(Catalyst::Controller::FormBuilder);
use LIXUZ::HelperModules::Forms qw(finalize_form);
use LIXUZ::HelperModules::Includes qw(add_jsIncl add_cssIncl add_jsOnLoad);
use LIXUZ::HelperModules::Fields;
use LIXUZ::HelperModules::System qw(silentSystem);
use LIXUZ::HelperModules::Templates qw(parse_templatefile resolve_dependencies);
use LIXUZ::HelperModules::JSON qw(json_response json_error);
use File::Temp qw(tempfile);
use File::Copy qw(move);
use constant {
    true => 1,
    false => 0,
    };

# Summary: Display the upload form for templates
sub index : Private
{
    my ($self, $c) = @_;
    my $i18n = $c->stash->{i18n};
    $c->stash->{template} = 'adm/core/dummy.html';
    $c->stash->{content} = '<form enctype="multipart/form-data" method="POST" action="/admin/templates/upload/submitTemplate"><input type="file" name="file_upload" /><br /><input type="submit" /></form>';
    $c->stash->{pageTitle} = $c->stash->{i18n}->get('Upload template');
}

# TODO: Create some concept of 'template packages' so they can mass-upload templates
# TODO: make error() unlink $targetFile if it is still around

# Summary: Handle submitted template data (write to disk, create objects etc.)
sub submitTemplate : Local
{
    my ($self, $c) = @_;
    my $i18n = $c->stash->{i18n};

    my (undef, $targetFile) = tempfile('lz_templateUpload.XXXXXXXXX',
        DIR => $c->config->{LIXUZ}->{temp_path},
        SUFFIX => '.mas');
    
    my $upload = $c->req->upload('file_upload');
    if(not $upload)
    {
        $self->error($c,'Got no file to upload');
    }
    if(not ($upload->link_to($targetFile) || $upload->copy_to($targetFile)))
    {
        $self->error($c,'Error writing the file');
    }

    # validateTemplate does not return if it fails.
    # If it succeeds it returns the parsed infoblock from parse_templatefile()
    my $info = $self->validateTemplate($c,$targetFile);

    # When we have reached this point we can assume that all is o.k. with the
    # template and that its infoblock is well formed, and can thus simply be
    # shoved into the database without further validation.
    my $template;
    eval
    {
        $template = $c->model('LIXUZDB::LzTemplate')->create({
                type => $info->{TEMPLATE_TYPE},
                apiversion => 1, # XXX: Needs to be dynamic once apiversion is bumped (if we keep version 1 support around)
                uniqueid => $info->{TEMPLATE_UNIQUEID},
            });
        my $name;
        if ($info->{TEMPLATE_NAME})
        {
            $name = $info->{TEMPLATE_NAME};
        }
        else
        {
            $name = $info->{TEMPLATE_UNIQUEID};
        }
        $template->set_column('name',$name);
        $template->update();
        1;
    } or do {
        my $e = $@;
        # Delete if something at all got added
        eval { if ($template) { $template->delete(); } };

        $c->log->error('Failed to create template object during upload. Error: '.$e);
        $self->error($c,'FATAL ERROR: Failed to create template object. This is a bug!');
    };
    my $fnam = $template->template_id.'_'.$template->uniqueid.'_'.$template->apiversion.'.lz.mas';
    $template->set_column('file',$fnam);
    my $current = $c->model('LIXUZDB::LzTemplate')->search({ is_default => 1, type => $template->type });
    if (!$current || !$current->count >0)
    {
        $template->set_column('is_default',1);
    }
    $template->update();
    move($targetFile,$c->config->{LIXUZ}->{template_path}.'/'.$fnam);
    $c->stash->{template} = 'adm/core/dummy.html';
    $c->stash->{content} = '<br /><br /><center>'.$i18n->get('The template has been uploaded').'</center><br /><br />';
    $c->stash->{pageTitle} = $c->stash->{i18n}->get('Template uploaded');
}

# Summary: Validate that settings for a template match what we expect
sub validateTemplate : Private
{
    my ($self, $c, $file) = @_;

    my $data = parse_templatefile($c,$file);

    if(not defined $data or not (keys %{$data}))
    {
        $self->error($c,'invalid infoblock 1');
    }

    # TODO: Add some regexes to validate the content of the items as well,
    # UNIQUEID in particular, which should probably only be [A-Za-z0-9.-\+]
    foreach my $required (qw(VERSION NAME APIVERSION UNIQUEID TYPE))
    {
        if(not defined $data->{'TEMPLATE_'.$required} or not length($data->{'TEMPLATE_'.$required}))
        {
            $self->error($c,'TEMPLATE_'.$required.' missing from infoblock');
        }
    }

    if ($data->{'TEMPLATE_APIVERSION'} ne '1')
    {
        $self->error($c,'APIVERSION not supported. This version of Lixuz only supports APIVERSION 1, this template is for APIVERSION '.$data->{'TEMPLATE_APIVERSION'});
    }

    # FIXME: Supply a list of deps to resolve_dependencies rather than the file
    if(not defined resolve_dependencies($c,$file))
    {
        # TODO: If we are unable to resolve dependencies then we should still allow the upload, just flag it as unusable for now
        #$self->error($c,'Unable to resolve dependencies. This is unhandled for the moment.');
        $c->log->warn('Failed to resolve deps, moving on anyway');
    }

    # FIXME: We will probably have to incorporate masontest.pl as a function, this
    # isn't working for some reason. It always seems to return -1, with $! indicating a
    # problem with the wait() system call (no process).
#    if(my $r = silentSystem($LIXUZ::PATH.'/tools/masontest.pl',$file))
#    {
#        $self->error($c,'The file does not validate as well-formed mason/perl code. Please validate the template with some tool (such as ./tools/masontest.pl as included in Lixuz) and fix the errors it reports before re-uploading.');
#    }

    # TODO: Check that UNIQUEID is not in the DB. If it is then we need some system for prompting the user for replacement
    #       ... or we could just error out and tell the user to use the 'replace template' functionality instead
    return $data;
}

# Summary: Display a basic error page
sub error : Private
{
    my ($self, $c, $error) = @_;
    $c->stash->{template} = 'adm/core/dummy.html';
    $c->stash->{content} = '<br /><br /><b>ERROR:</b> '.$error;
    $c->detach;
}

1;
