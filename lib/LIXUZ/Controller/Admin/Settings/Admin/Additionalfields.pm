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

package LIXUZ::Controller::Admin::Settings::Admin::Additionalfields;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
BEGIN { extends 'Catalyst::Controller::FormBuilder' };
with 'LIXUZ::Role::List::Database';

use LIXUZ::HelperModules::JSON qw(json_response json_error);
use LIXUZ::HelperModules::Includes qw(add_jsIncl);
use LIXUZ::HelperModules::RevisionHelpers qw(get_latest_article);
use List::MoreUtils qw(any);
use 5.010;
# Used in responses as well, don't make false undef.
use constant { true => 1, false => 0};

sub index : Path Args(0) Form('/core/search')
{
    my ( $self, $c, $query ) = @_;
    my $fields = $c->model('LIXUZDB::LzField');
    my $obj = $self->handleListRequest({
            c => $c,
            query => $query,
            object => $fields,
            objectName => 'field',
            template => 'adm/settings/admin/adfields/field_index.html',
            orderParams => [qw(field_id field_name field_type)],
            searchColumns => [qw/field_id field_name/],
            folderType => 'builtin',
            paginate => 1,
        });
}

# Summary: Edit a field
sub edit : Local Args
{
    my ( $self, $c, $uid ) = @_;
    my $i18n = $c->stash->{i18n};
    if(not defined $uid)
    {
        $self->messageToList($c,$i18n->get('Error: Failed to locate UID. The path specified is invalid.'));
    }
    my $populate = {};
    my $field = $c->model('LIXUZDB::LzField')->find({field_id => $uid});
    if(not $field)
    {
        $self->messageToList($c,$i18n->get_advanced('Error: Failed to locate a field with the UID %(UID).', { UID => $uid }));
    }
    elsif($field->inline)
    {
        $c->stash->{content} = 'Access denied';
        $c->stash->{template} = 'adm/core/dummy.html';
        return;
    }
    add_jsIncl($c,'admin.js');
    $populate->{uid} = $uid;
    $populate->{type} = $field->field_type;
    $populate->{name} = $field->field_name;
    $populate->{height} = $field->field_height;
    $populate->{range} = $field->field_range;
    $populate->{use_RTE} = $field->field_richtext;
    if ($field->options)
    {
        my @options;
        my $opt = $field->options;
        while(my $s = $opt->next)
        {
            push(@options,$s->option_name);
        }
        $populate->{pullvalues} = join(', ',@options);
    }
    $c->stash->{values} = $populate;
    $c->stash->{formType} = 'edit';
    $c->stash->{template} = 'adm/settings/admin/adfields/adfieldedit.html';
}

# Summary: Add/remove fields from a module or folder
sub fieldeditor : Local Args
{
    # $uid is optional, only used when in folder or article mode
    my ( $self, $c, $module, $uid,$rev ) = @_;

    my $object_id;
    my $folder_id;
    my $fields;

    if(not grep { $module eq $_ } qw(folders users roles templates articles files))
    {
        json_error($c,'INVALID MODULE');
    }
    if ($module eq 'articles' or $module eq 'folders' or $module eq 'files')
    {
        if(not defined $uid or $uid =~ /\D/)
        {
            json_error($c,'UIDMISSING');
        }
    }

    if ($module eq 'articles')
    {
        $rev //= 0;
        my $art = $c->model('LIXUZDB::LzArticle')->find({article_id => $uid, revision => $rev});
        if(not $art)
        {
            json_error($c,'INVALID UID');
        }
        if ($art->folder)
        {
            $folder_id = $art->folder->folder_id
        }
        if(not defined $folder_id or not length $folder_id or $folder_id =~ /\D/)
        {
            json_error($c,'NOFOLDERID');
        }
    }
    elsif($module eq 'files')
    {
        $object_id = $c->req->param('object_id');
        if(not defined $object_id or not length $object_id or $object_id =~ /\D/)
        {
            json_error($c,'NOFILECLASSID');
        }
    }

    my %ActiveFields;
    my @Fields;

    if ($module eq 'folders')
    {
        my $f = $c->model('LIXUZDB::LzFolder')->find({folder_id => $uid});
        if(not $f)
        {
            return json_error($c,'FOLDER_NOT_FOUND');
        }
        $c->stash->{cat_name} = $f->folder_name;
    }
    elsif($module eq 'files')
    {
        my $class = $c->model('LIXUZDB::LzFileClass')->find({ id => $object_id });
        if(not $class)
        {
            return json_error($c,'FILECLASS_NOT_FOUND');
        }
    }

    if ( defined($folder_id) )
    {
        $fields = LIXUZ::HelperModules::Fields->new($c,$module,$uid, { folder_id => $folder_id });
    }
    else
    {
        $fields = LIXUZ::HelperModules::Fields->new($c,$module,$uid, { object_id => $object_id });
    }
    my @relevantFields = $fields->get_fields();
    my @order;
    foreach my $field (@relevantFields)
    {
        $ActiveFields{$field->field_id} = 1;
        push(@order,$field->field_id);
    }
    my $allFields = $c->model('LIXUZDB::LzField')->search(undef, {order_by => 'field_name,field_id'});
    my $v = 0;
    my $entries = {};
    while(my $field = $allFields->next)
    {
        if (not defined $field->field_type or $field->field_type =~ /meta/)
        {
            next;
        }
        $v++;
        my $entry = [];
        push(@{$entry},$field->field_id);
        push(@{$entry},$field->field_name);
        $entries->{$field->field_id} = $entry;
        if(not $ActiveFields{$field->field_id})
        {
            push(@order,$field->field_id);
        }
    }
    return json_response($c, { entries => $entries, checked => \%ActiveFields, order => \@order, type => $module});
}

# Summary: Add a new field
sub add : Local
{
    my ( $self, $c ) = @_;
    add_jsIncl($c,'admin.js');
    $c->stash->{template} = 'adm/settings/admin/adfields/adfieldedit.html';
}

# Summary: Completely delete a field
sub delete : Local Args
{
    my ( $self, $c, $uid ) = @_;
    my $field = $c->model('LIXUZDB::LzField')->find({field_id => $uid},{prefetch => 'modules'});
    if(not $field)
    {
        $self->messageToList($c,$c->stash->{i18n}->get('Failed to locate the supplied field'));
        return;
    }
    my $values = $field->values;
    my $options = $field->options;
    my $modules = $field->modules;
    foreach my $component ($values,$options,$modules)
    {
        while((defined $component) && (my $part = $component->next))
        {
            $part->delete();
        }
    }
    $field->delete();
    $self->messageToList($c,$c->stash->{i18n}->get('Field and all related values have been deleted'));
}

# Summary: Submit field information
sub submit : Local
{
    my ( $self, $c) = @_;
    my $r = $c->req;
    my $created = 0;
    my $field;
    my @RequiredFields = qw(name);

    if (defined $r->param('uid') && length($r->param('uid')))
    {
        $field = $c->model('LIXUZDB::LzField')->find({field_id => $r->param("uid")});
    }
    else
    {
        $field = $c->model('LIXUZDB::LzField')->create({ });
        push(@RequiredFields,qw(type));
        $created = 1;
    }

    if(not defined $field)
    {
        $field->delete() if $created;
        return json_error($c,'DBFAILURE','Failed to look up or create entry in the database');
    }

    foreach my $f(@RequiredFields)
    {
        if(not defined $r->param($f) or not length $r->param($f))
        {
            $field->delete() if $created;
            return json_error($c,'MISSINGFIELD','The field "'.$f.'" is missing',1);
        }
    }

    if(defined $r->param('type') && $created)
    {
        my $type = $r->param('type');
        if(not grep( { $_ eq $type } qw(singleline multiline user-pulldown checkbox predefined-pulldown range range-pulldown datetime date multi-select datetimerange)))
        {
            $field->delete() if $created;
            return json_error($c,'UNKNOWNTYPE','The type "'.$r->param('type').'" is unknown');
        }
        # range-pulldown is simply a user-pulldown with a range value
        if ($type eq 'range-pulldown')
        {
            $field->set_column('field_type','user-pulldown');
        }
        else
        {
            $field->set_column('field_type',$type);
        }
    }

    my $type = $r->param('type');

    if(defined $r->param('module') && $created)
    {
        if(not grep( { $_ eq $r->param('module') } qw(workflow folders templates users roles files)))
        {
            $field->delete() if $created;
            return json_error($c,'UNKNOWNMODULE','The module "'.$r->param('module').'" is unknown to me');
        }
        #$field->set_column('module',$r->param('module'));
    }

    if (defined $r->param('height'))
    {
        if(not $field->get_column('field_type') eq 'multiline')
        {
            $field->delete() if $created;
            return json_error($c,'NOTMULTILINE','a height parameter was supplied for a field that was not multi-line');
        }
        if ($r->param('height') =~ /\D/)
        {
            $field->delete() if $created;
            return json_error($c,'INVALIDHEIGHT','The height supplied was invalid, needs to be an integer');
        }
        $field->set_column('field_height',$r->param('height'));
    }
    elsif (defined $r->param('range'))
    {
        if(not $type =~ /range/)
        {
            $field->delete() if $created;
            # FIXME: Perhaps this should be a warning?
            return json_error($c,'NOTRANGE','A range parameter was supplied for a field that was not range');
        }
        my $range = $r->param('range');
        if (not $range =~ s/^\s*(\d+)\s*-\s*(\d+)\s*/$1-$2/)
        {
            $field->delete() if $created;
            return json_error($c,'INVALIDRANGE','The range supplied was invalid, needs to be in the form FROM-TO');
        }
        $field->set_column('field_range',$range);
    }
    elsif($field->get_column('field_type') eq 'range')
    {
        $field->delete() if $created;
        return json_error($c,'NORANGE','You did not supply a range');
    }
    elsif($r->param('values'))
    {
        if(not $field->get_column('field_type') =~ /^(multi-select|user-pulldown)$/)
        {
            $field->delete() if $created;
            return json_error($c,'NOTUSERPULLDOWN','a values parameter was supplied for a field that was not user-pulldown');
        }
        my @values;
        foreach my $val (split(/,/,$r->param('values')))
        {
            $val =~ s/^\s//;
            my $o = $c->model('LIXUZDB::LzFieldOptions')->find_or_create({
                    field_id => $field->field_id,
                    option_name => $val,
                });
            push(@values,$o->option_id);
        }
        if(not $created)
        {
            $self->cleanPulldown($c,$field,\@values);
        }
    }

    if (defined $r->param('rte') && $r->param('rte') eq 'true')
    {
        $field->set_column('field_richtext',1);
    }
    else
    {
        $field->set_column('field_richtext',0);
    }

    $field->set_column('field_name',$r->param('name'));

    $field->update();

    return json_response($c,{ uid => $field->field_id}, created => $created);
}

# Summary: Handle request from JS code to delete or add fields to a module.
sub fieldModuleUpdate : Local
{
    my ($self, $c) = @_;

    # Fetch params
    my $fields = $c->req->param('fields');
    my $module_name = $c->req->param('module_name');
    my $module_id = $c->req->param('module_id');
    my $revision = $c->req->param('revision');

    # Validate params
    if(not $fields)
    {
        return json_response($c);
    }
    my @processFields = split(',',$fields);
    if(not defined $module_name)
    {
        return json_error($c,'MISSING_PARAMS','module_name');
    }

    if ($module_name =~ /(\s|\d)/)
    {
        return json_error($c,'INVALID_PARAMS', 'module_name');
    }
    if ($module_name eq 'folder' or $module_name eq 'article')
    {
        if (not defined $module_id)
        {
            return json_error($c,'MISSING_PARAMS','module_id');
        }
        if ($module_id =~ /\D/)
        {
            return json_error($c,'INVALID_PARAMS','module_id');
        }
    }
    my $folder_id;
    # Convert article to folders
    if ($module_name eq 'article' || $module_name eq 'articles')
    {
        $revision //= 0;
        my $art = $c->model('LIXUZDB::LzArticle')->find({revision => $revision, article_id => $module_id},{prefetch => 'folders'});
        if(not $art)
        {
            return json_error($c,'INVALID_PARAMS','module_id+module_name pair, article not found');
        }
        if(not $art->folder)
        {
            return json_error($c,'INVALID_PARAMS','module_id+module_name pair, article has no folder');
        }
        $folder_id = $art->folder->folder_id;
        if(not defined $folder_id)
        {
            return json_error($c,'FATAL_ART_INVALID_FOLDER_ID');
        }
    }
    elsif($module_name eq 'folder')
    {
        $c->log->debug('got module_name=folder, setting module_name=folders');
        $module_name = 'folders';
    }

    my $fieldObj = LIXUZ::HelperModules::Fields->new($c,$module_name,$module_id, { folder_id => $folder_id });
    $fieldObj->syncFieldsWithData(\@processFields);

    return json_response($c,{});
}

# Summary: Clean options from a pulldown field
sub cleanPulldown: Private
{
    my ( $self, $c, $field, $except ) = @_;

    my $obj = $field->options;
    while(my $o = $obj->next)
    {
        if (any {$o->option_id eq $_} @{$except})
        {
            next;
        }
        $o->delete;
    }
    return true;
}

1;
