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

# LIXUZ::HelperModules::Fields
# 
# Object-oriented interface to Lixuz fields
#
# This module provides a simple and unified interface to actions
# on fields. It lets you initialize the fields on
# an edit page (obj->editorInit()) and save input from a page
# (obj->saveData()).
#
# The interface is fairly straightforward and performs most controller-related
# actions for you. Templates will need to include
# adm/core/renderFields.html at the location the fields should
# appear.
#
# The template should also have the following code snippet to allow
# field configuration from within the page when that is 
# allowed/possible:
#
# --
# %if($ARGS{ADF_CanEdit}) {
# <a href="#" onclick="LZ_DisplayFieldEditForm('NAME_OF_MODULE (ie. articles)',<% $YOUR_UID %>); return false;">Edit fields</a>
# <br /><br />
# %}
# --
#
# If you are submitting your form like a normal HTML form, then things
# will simply just work(tm) as long as you call saveData on the object in your
# handling controller. However if you are submitting a request via JSON
# you will need to call LZ_ADField_GetFields() which returns a JavaScript
# hash containing field => value pairs that you can then submit as usual.
#
# All fields crated with this use the adfield_ prefix for their HTML IDs and names.

package LIXUZ::HelperModules::Fields;

use Moose;
use Carp;
use Scalar::Util qw(weaken);
use LIXUZ::HelperModules::Includes qw(add_jsIncl add_cssIncl add_bodyClass add_globalJSVar);
use LIXUZ::HelperModules::Calendar qw(datetime_to_SQL datetime_from_SQL datetime_from_SQL_to_unix);
use LIXUZ::HelperModules::Editor qw(create_editor);
use LIXUZ::HelperModules::Cache qw(get_ckey CT_DEFAULT);
use Carp;
use Hash::Merge qw(merge);
use constant {
    true => 1,
    false => 0,
};

has 'c' => (
    isa => 'Object',
    is => 'rw',
    weak_ref => 1
);
has 'module' => (
    isa => 'Str',
    is => 'rw',
);
has 'uid' => (
    isa => 'Maybe[Int]',
    is => 'rw',
);
has 'revisionControl' => (
    isa => 'Maybe[Object]',
    is => 'rw',
);
has 'revision' => (
    isa => 'Int',
    is => 'rw',
    default => 1
);
has 'doneEditorInit' => (
    isa => 'Int',
    is => 'rw',
);
has 'options' => (
    isa => 'Ref',
    is => 'rw',
    default => sub { {} },
);

# Summary: Create a new AdditionalFields object.
# Usage: LIXUZ::HelperModules::Fields->new($c,$moduleName,$uid,$options);
# Parameters:
#   $c = catalyst object
#   $moduleName = the name of the module, for instance 'users'
#   $uid = the ID identifying this object instance. This can be undef
#   $options = the options hashref described below.
#
# The options that you can supply in the options hashref:
#   folder_id => the folder_id that the object belongs to, if any
#   inlineSaveHandler => a coderef to the function that will handle validation
#       and saving of inline fields. Prototype:
#       ($c, $uid, $field, $value)
#   inlineFetchHandler => a coderef to the function that will handle fetching
#       the values for inline fields. Prototype:
#       ($c, $uid, $field)
#       Should return ($field_value_scalar, $field_name), field_value_scalar
#       being the raw (safe) value of the field, and field_name being the
#       (possibly localized) name of the field. The latter can be undef,
#       in which case the name in the field definition is used.
#   additionalFields => an arrayref of additional field ids to include on this page.
#       You can use this to forcefully add fields.
sub BUILDARGS
{
    my $class = shift;
    my($c,$module,$uid,$options) = @_;

    my $revControl;
    my $revision = 1;
    if ($options->{revisionControl})
    {
        $revControl = $options->{revisionControl};
        delete($options->{revisionControl});
    }
    if (defined $options->{revision})
    {
        $revision = $options->{revision};
        delete($options->{revision});
    }
    if ($options->{folder_id})
    {
        $options->{object_id} = $options->{folder_id};
        $module = 'folders';
    }
    elsif($module eq 'files' && defined $uid && length($uid) && !defined($options->{object_id}))
    {
        $options->{object_id} = $uid;
    }

    if(defined $options->{object_id} && ! defined $uid)
    {
        $uid = $options->{object_id};
    }

    return $class->SUPER::BUILDARGS(
        c => $c,
        module => $module,
        uid => $uid,
        options => $options,
        revisionControl => $revControl,
        revision => $revision
    );
}

# Summary: A wrapper around update/delete/insert for DBIC objects that adds revision control
sub _update
{
    my $self = shift;
    my $obj = shift;
    my $action = shift;

    die('$obj missing in _update') if not defined $obj;

    if ($self->revisionControl)
    {
        if ($action && $action eq 'delete')
        {
            $self->revisionControl->delete_object($obj);
        }
        else
        {
            $self->revisionControl->add_object($obj);
        }
    }
    else
    {
        if ($action && $action eq 'insert')
        {
            return $obj->insert;
        }
        elsif($action && $action eq 'delete')
        {
            return $obj->delete;
        }
        return $obj->update();
    }
}

# Method that does the right thing(tm) for both RCS and non-RCSed values
# when updating them.
sub _removeAndInsert
{
    my $self = shift;
    my $model = shift;
    my $primary = shift;
    my $values = shift;

    if ($self->revisionControl)
    {
        my $existing = $model->find($primary);
        if ($existing)
        {
            $self->revisionControl->delete_object($existing);
        }
        my $new = $model->new_result(merge($primary,$values));
        $self->_update($new,'insert');
    }
    else
    {
        my $existing = $model->find($primary);
        foreach my $k (keys %{$values})
        {
            $existing->set_column($k,$values->{$k});
        }
        $existing->update();
    }
}

# Summary: Retrieve the value column for a field_id
# Usage: columnName = obj->_getValueColumn($c,field_id);
sub _getValueColumn
{
    my($self,$c,$field_id) = @_;
    my $ckey = get_ckey('adfield','valuecolumn',$field_id);
    if(my $val = $c->cache->get($ckey))
    {
        return $val;
    }
    my $obj = $c->model('LIXUZDB::LzField')->find({
            field_id => $field_id
        });
    if ($obj)
    {
        my $val = $obj->storage_type;
        $c->cache->set($ckey,$val,CT_DEFAULT);
        return $val;
    }
}

# Summary: Synchronize fields with the data supplied.
# Usage: obj->syncFieldsWithData(fieldArray);
#
# fieldArray is an array of field IDs. The order will be the order
# in which it is sorted in the array.
sub syncFieldsWithData
{
    my $self = shift;
    my $c = $self->c;
    my $includeFields = shift;
    my %seenFields;

    for my $i(0..scalar(@{$includeFields}))
    {
        next if not defined $includeFields->[$i];
        $self->addField($includeFields->[$i],$i);
        $seenFields{$includeFields->[$i]} = 1;
    }

    my @allFields = $self->get_fields();
    foreach my $f(@allFields)
    {
        $f = $f->field_id;
        next if $seenFields{$f};
        $self->removeField($f);
    }
}

# Summary: Add a field to the module related to this instance
# Usage: obj->addField(field_id,position?);
# position is optional.
# TODO: We can add magick here that handles not actually having duplicates
# if it can be avoided at all.
sub addField
{
    my $self = shift;
    my $field_id = shift;
    my $c = $self->c;
    my $position = shift;
    my $obj;
    if(not defined $field_id)
    {
        carp('addField(): field_id was undef, can\'t have that');
    }
    if (defined $self->options->{object_id})
    {   
        my $module = $self->module;
        $module = $module eq 'folder' ? 'folders' : $module;
        $obj = $c->model('LIXUZDB::LzFieldModule')->find_or_create({
                field_id => $field_id,
                module => $module,
                object_id => $self->options->{object_id}});
    }
    else
    {   
        $obj = $c->model('LIXUZDB::LzFieldModule')->find_or_create({field_id => $field_id, module => $self->module});
    }
    if ($obj)
    {   
        if(defined $position)
        {
            $obj->set_column('position',$position);
        }
        $obj->set_column('enabled',1);
        $obj->update();
    }
    else
    {   
        $c->log->warn('addField() failed: failed to look up or create an object');
    }
}

# Summary: Remove a field from the module related to this instance
# Usage: obj->removeField(field_id);
sub removeField
{
    my $self = shift;
    my $field_id = shift;
    my $c = $self->c;
    my $obj;
    if ($self->options->{folder_id})
    {   
        $obj = $c->model('LIXUZDB::LzFieldModule')->find_or_create({module => 'folders', object_id => $self->options->{folder_id}, field_id => $field_id});
    }
    elsif(defined $self->options->{object_id})
    {
        $obj = $c->model('LIXUZDB::LzFieldModule')->find_or_create({ module => $self->module, field_id => $field_id, object_id => $self->options->{object_id} });
    }
    else
    {
        $obj = $c->model('LIXUZDB::LzFieldModule')->find_or_create({module => $self->module, field_id => $field_id});
    }
    if (not $obj)
    {
        $c->log->debug('removeField(): I have no object, something went very wrong');
        return false;
    }
    $obj->set_column('enabled',0);
    $obj->update();
    return true;
}

# Summary: Initialize the fields for an edit page, adding required includes
#   and populating values in the stash as required.
# Usage: object->editorInit();
sub editorInit
{
    my $self = shift;
    my $c = $self->c;
    if ($c->user->can_access('/settings/admin/additionalfields/fieldeditor'))
    {
        $c->stash->{ADF_CanEdit} = 1;
    }
    else
    {
        $c->stash->{ADF_CanEdit} = 0;
    }

    add_jsIncl($c,'core.js','utils.js');

    my @fieldList;
    my @fieldIds;

    if ($self->options->{additionalFields})
    {
        foreach my $field_id (@{$self->options->{additionalFields}})
        {
            my $f = $c->model('LIXUZDB::LzField')->find({field_id => $field_id});
            if(not $f)
            {
                $c->log->error('failed to locate lz_field with id => '.$field_id);
                next;
            }
            my $info = $self->_prep_field($f);
            if ($info)
            {
                push(@fieldIds, $f->field_id);
                push(@fieldList,$info);
            }
        }
    }

    my @fields = $self->get_fields();
    if (@fields)
    {
        foreach my $f (@fields)
        {
            next if not $f->enabled;
            $f = $f->field;
            my $info = $self->_prep_field($f);
            if ($info)
            {
                push(@fieldIds, $f->field_id);
                push(@fieldList,$info);
            }
        }
    }

    if (@fieldIds)
    {
        add_globalJSVar($c,'additionalFields','new Array(\''.join('\',\'',@fieldIds).'\')');
    }
    else
    {
        add_globalJSVar($c,'additionalFields','new Array()');
    }
    $c->stash->{additionalFields} = \@fieldList;
    return true;
}

# Summary: Save input for the current request
# Usage: object->saveData();
sub saveData
{
    my $self = shift;
    my $c = $self->c;
    if(not defined $self->uid and not $self->revisionControl)
    {
        $c->log->warn('Fields.pm: saveData: has no UID');
    }
    my %fields = %{$c->req->parameters};
    if ($c->req->data)
    {
        %fields = %{$c->req->data};
    }
    while(my ($field_id, $field_value) = each(%fields))
    {
        next if not $field_id =~ s/^adfield_//;
        my $field = $c->model('LIXUZDB::LzField')->find({field_id => $field_id});
        if(not $field)
        {
            $c->log->error('Error while saving field data, failed to locate field with field_id '.$field_id);
            next;
        }
        my $field_rvalue = $self->_get_value($field_value,$field);
        if(not defined $field_rvalue)
        {
            $c->log->warn('Got invalid value "'.$field_value.'" for field "'.$field_id.'": ignoring.');
            next;
        }

        $field_value = $field_rvalue;

        if ($field->is_inline)
        {
            if(not $self->options->{inlineSaveHandler})
            {
                if(not $self->options->{_inlineError})
                {
                    $self->options->{_inlineError} = 1;
                    $c->log->error('inline fields on page but no inlineSaveHandler - DATA LOSS! (processing input on '.$c->req->uri.')');
                }
                next;
            }
            $self->options->{inlineSaveHandler}->($c,$self->uid,$field,$field_value);
            next;
        }
        my $search = {
            field_id => $field_id,
            module_name => $self->module,
            module_id => $self->uid,
            revision => $self->revision,
        };
        if(my $current = $c->model('LIXUZDB::LzFieldValue')->find($search))
        {
            my $val = { $self->_getValueColumn($c,$field_id) => $field_value };
            $self->_removeAndInsert($c->model('LIXUZDB::LzFieldValue'), $search, $val);
        }
        else
        {
            if(not length $field_value)
            {
                next;
            }
            my $m = $c->model('LIXUZDB::LzFieldValue')->new_result({field_id => $field_id, module_name => $self->module, module_id => $self->uid, $self->_getValueColumn($c,$field_id) => $field_value});
            $self->_update($m,'insert');
        }
    }
}

# Summary: Fetch fields relevant for this instance of the object
# Usage: my @field_array = $fields->get_fields();
sub get_fields
{
    my $self = shift;
    my $c = $self->c;
    my @fields;
    if (defined $self->options->{folder_id})
    {
        @fields = $self->_get_fields_recursive();
    }
    else
    {
        my $fields;
        if(defined $self->options->{object_id})
        {
            $fields = $c->model('LIXUZDB::LzFieldModule')->search({module => $self->module, object_id => $self->options->{object_id}}, {order_by => 'position'});
        }
        else
        {
            $fields = $c->model('LIXUZDB::LzFieldModule')->search({module => $self->module}, {order_by => 'position'});
        }
        while(my $f = $fields->next)
        {
            next if not $f->enabled;
            push(@fields,$f);
        }
    }
    if (!wantarray())
    {
        return \@fields;
    }
    else
    {
        return @fields;
    }
}


# --
# Private methods
# --

# Summary: Validates and retrieves certain values
sub _get_value
{
    my ($self,$value,$field) = @_;
    my $c = $self->c;
    if(not $field)
    {
        return undef;
    }
    if ($field->field_type eq 'checkbox')
    {
        if (defined $value && $value eq 'checked')
        {
            return 'true';
        }
        else
        {
            return 'false';
        }
    }
    elsif($field->field_type eq 'range' and length $value)
    {
        my $min = $field->field_range;
        my $max = $field->field_range;
        $min =~ s/^\s*(\d+)\s*-.*/$1/;
        $max =~ s/^\s*\d+\s*-\s*(\d+)\s*$/$1/;
        if ($value =~ /[^\s,\d-]/)
        {
            $c->log->warn('Fields.pm _get_value(): Invalid range value: '.$value);
            return undef;
        }
        foreach my $part (split(/(\s|,|-)+/,$value))
        {
            next if not defined $part or not length $part or $part =~ /\D/;
            if ($part > $max || $part < $min)
            {
                $c->log->warn('Fields.pm _get_value(): '.$part.' doesn\'t match the range ('.$field->field_range.') (in full value: '.$value.')');
                return undef;
            }
        }
    }
    elsif($field->field_type eq 'datetime' and length $value)
    {
        $value = datetime_to_SQL($value);
        if ($value eq '0000-00-00 00:00:00')
        {
            $value = '';
        }
    }
    elsif($field->field_type eq 'datetimerange' and length $value)
    {
        my $frmdate;
        my $todate;
        my @parts = split('-',$value);
        $frmdate = $parts[0];
        $todate = $parts[1];
        if (defined($frmdate) and defined($todate))
        {
            $value = $frmdate.'-'.$todate;
            $frmdate = datetime_to_SQL($frmdate);
            $todate  = datetime_to_SQL($todate);
            if ($frmdate eq '0000-00-00 00:00:00' || $todate eq '0000-00-00 00:00:00')
            {
                $value='';
            }
            else
            {
                $frmdate = datetime_from_SQL_to_unix($frmdate);
                $todate = datetime_from_SQL_to_unix($todate);
            
                if (not $frmdate=~/\D/ || not $todate =~/\D/)
                {
                    if ($frmdate >= $todate)
                    {
                        $c->log->warn('Fields.pm _get_value(): Invalid range value: '.$value);
                        return undef;
                    }
                }
            }
        }
        else
        {
            $value ='';
        }
    }  

    return $value;
}

# Summary: Prepares a field for use on a page
sub _prep_field
{
    my $self = shift;
    my $c = $self->c;
    my $f = shift;

    if (not $f->can_render_for($self->module))
    {
        $c->log->warn('Wanted to _prep_field '.$f->field_id.' but couldn\'t: exclusivity didn\'t match');
        return;
    }

    my $info = {};
    $info->{label} = $f->field_name;
    $info->{type} = $f->field_type;
    $info->{uid} = $f->field_id;
    $info->{height} = defined $f->field_height ? $f->field_height : 8;
    $info->{range} = defined $f->field_range ? $f->field_range : '';
    $info->{fieldname} = 'adfield_'.$f->field_id;
    $info->{options} = $f->options;
    $info->{obligatory} = $f->obligatory;
    $info->{value} = '';
    if (defined $self->options->{folder_id})
    {
        $c->stash->{moduleFieldId} = $self->options->{folder_id};
    }
    else
    {
        $c->stash->{moduleFieldId} = 0;
    }

    my $value;
    if ($f->is_inline)
    {
        $info->{inline} = $f->inline;
        if(not $self->options->{inlineFetchHandler})
        {
            if(not $self->options->{_inlineError})
            {
                $self->options->{_inlineError} = 1;
                if(not $self->options->{inlineSaveHandler})
                {
                    $c->log->error('inline fields on page but no inlineFetchHandler - data retrieval failed (there is no inlineSaveHandler either, so the user will lose any saved data in this field)! (processing fields for '.$c->req->uri.')');
                }
                else
                {
                    $c->log->error('inline fields on page but no inlineFetchHandler - data retrieval failed, data loss may occur if the user saves! (processing fields for '.$c->req->uri.')');
                }
            }
        }
        else
        {
            my $title;
            ($value,$title) = $self->options->{inlineFetchHandler}->($c,$self->uid,$f);
            if ($title)
            {
                $info->{label} = $title;
            }
        }
    }
    elsif(my $fieldValue = $c->model('LIXUZDB::LzFieldValue')->find({module_name => $self->module, module_id => $self->uid, field_id => $f->field_id, revision => $self->revision}))
    {
        $value = $fieldValue->value;
    }

    if(defined $value)
    {
        if ($f->field_type eq 'checkbox')
        {
            if ($value eq 'true')
            {
                $info->{checked} = 1;
            }
            else
            {
                $info->{checked} = 0;
            }
        }
        elsif($f->field_type eq 'datetime' and length $value)
        {
            $info->{value} = datetime_from_SQL($value);
        }
        elsif($f->field_type eq 'datetimerange' and length $value)
        {
            $info->{value} = $value;
        }
        else
        {
            $info->{value} = $value;
        }
    }

    if ($f->field_type eq 'multiline' and $f->field_richtext)
    {
        $info->{rte} = create_editor($c,$info->{fieldname},{ value => $info->{value}, rows => $info->{height}, inline => $info->{inline} });
    }
    return $info;
}

# Summary: Fetch fields for a folder recursively
# Usage: FIELDS = obj->_get_fields_recursive(LEVEL?);
#   LEVEL indicates which level you want to fetch for, and defaults to 0.
#   Levels:
#   0   = all fields, including the fields for the immediate folder
#   1   = all inherited fields
sub _get_fields_recursive
{
    my $self = shift;
    my $c = $self->c;
    my $folder = $c->model('LIXUZDB::LzFolder')->find({folder_id => $self->options->{folder_id}});
    my $level = shift;
    $level = $level ? $level : 0;
    my %hasFields;
    my @finalFields;
    my @fields;
    my $cacheKey = 'fields_recursive_folder_'.$self->options->{folder_id}.'_lvl'.$level;
    my %blacklist;
    if ($self->options->{$cacheKey})
    {
        return @{$self->options->{$cacheKey}};
    }

    for(my $i = 0; $i < $level; $i++)
    {
        last if not $folder;
        $folder = $folder->parent;
    }

    while($folder)
    {
        my $fields = $c->model('LIXUZDB::LzFieldModule')->search({module => 'folders', object_id => $folder->folder_id});
        while((defined $fields) and (my $f = $fields->next))
        {
            if(not $f->enabled)
            {
                $blacklist{ $f->field_id } = 1;
            }
            next if $blacklist{ $f->field_id };
            if(not $hasFields{$f->field_id})
            {
                my $pos = defined $f->position ? $f->position : 100;
                if(not defined $fields[$pos])
                {
                    $fields[$pos] = [];
                }
                $hasFields{$f->field_id} = 1;
                push(@{$fields[$pos]},$f);
            }
        }
        $folder = $folder->parent;
    }

    for(my $i = 0; $i < @fields; $i++)
    {
        next if not defined $fields[$i];
        foreach my $s (@{$fields[$i]})
        {
            push(@finalFields,$s);
        }
    }

    $self->options->{$cacheKey} = \@finalFields;

    return @finalFields;
}

__PACKAGE__->meta->make_immutable;
1;
