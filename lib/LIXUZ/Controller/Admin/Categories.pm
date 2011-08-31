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

package LIXUZ::Controller::Admin::Categories;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
BEGIN { extends 'Catalyst::Controller::FormBuilder' };
with 'LIXUZ::Role::List::Database';

use LIXUZ::HelperModules::Search qw(cross);
use LIXUZ::HelperModules::Forms qw(finalize_form);
use LIXUZ::HelperModules::Includes qw(add_jsIncl add_cssIncl add_globalJSVar add_jsOnLoad);
use LIXUZ::HelperModules::DragDrop;

# Summary: Show the primary list
sub index : Path Args(0) Form('/core/search') {
    my ( $self, $c, $query ) = @_;
    my $category = $c->model('LIXUZDB::LzCategory');
    $c->stash->{pageTitle} = $c->stash->{i18n}->get('Categories');
    $self->handleListRequest({
            c => $c,
            query => $query,
            object => $category,
            objectName => 'category',
            template => 'adm/categories/index.html',
            orderParams => [qw(category_id category_name template_id parent external_link display_type_id category_status)],
            searchColumns => [qw(category_id category_name  external_link)],
            paginate => 1,
        });
}

# Summary: Forward the category to the list view, and display a status message at the top of it
# Usage: $self->messageToList($c, MESSAGE);
sub messageToList
{
    my ($self, $c, $message) = @_;
    $c->flash->{ListMessage} = $message;
    if(not $message)
    {
        $c->log->warn('No valid message supplied to messageToList in Categories.pm');
    }
    $c->response->redirect('/admin/categories');
    $c->detach();
}

# Summary: Handle creating a new category
sub add: Local Form('/categories/edit') {
    my ( $self, $c ) = @_;
    my $i18n = $c->stash->{i18n};
    my $form = $self->formbuilder;
    if ($form->submitted && $form->validate)
    {
        my $category_uid = $c->model('LIXUZDB::LzCategory')->find({category_id => $form->fields->{uid}});
        my $category_name= $c->model('LIXUZDB::LzCategory')->find({category_name => $form->fields->{category_name}});
        if ($category_name)
        {
            if (not $category_uid or $category_uid->get_column('category_id') != $category_name->get_column('category_id'))
            {
                $self->messageToList($c,$i18n->get_advanced('Error: A category with the categoryname %(USERNAME) already exists (UID %(UID)).',{ USERNAME => $form->fields->{category_name}, UID => $category_name->get_column('category_id') }));
            }
        }
        $self->savedata($c,$form);
    }
    $self->buildform($c,'add');
}

# Summary: Handle editing an existing category
sub edit: Local Args Form('/categories/edit') {
    my ( $self, $c, $uid ) = @_;
    my $form = $self->formbuilder;
    # Categoryname is not required here, it's just included for completeness
    $form->field(
        name => 'category_name',
        required => 0,
    );
    # UID is, however
    $form->field(
        name => 'uid',
        required => 1,
    );
    # Handle the form if it was submitted and validates
    if ($form->submitted && $form->validate)
    {
        $self->savedata($c,$form);
    }
    else
    {
        my $i18n = $c->stash->{i18n};
        # If we don't have an UID then just give up
        if (not defined $uid or $uid =~ /\D/)
        {
            $self->messageToList($c,$i18n->get('Error: Failed to locate UID. The path specified is invalid.'));
        }
        else
        {
            # Check if the category exists
            my $category = $c->model('LIXUZDB::LzCategory')->find({category_id => $uid});
            if(not $category)
            {
                # Didn't exist, give up
                $self->messageToList($c,$i18n->get_advanced('Error: Failed to locate a category with the UID %(UID).', { UID => $uid }));
            }
            else
            {
                # Existed, generate our form and display it
                $form->field(
                    name => 'uid',
                    type => 'hidden',
                    value => $uid,
                );
                $self->buildform($c,'edit',$category->get_everything(),$category);
            }
        }
    }
}

# Summary: Delete a category (and get a confirmation from the category about it)
sub delete: Local Args
{
    my ( $self, $c, $uid ) = @_;
    my $i18n = $c->stash->{i18n};
    my $category;
    $c->stash->{template} = 'adm/core/dummy.html';
    # If we don't have an UID then just give up
    if (not defined $uid or $uid =~ /\D/)
    {
        $self->messageToList($c,$i18n->get('Error: Failed to locate UID. The path specified is invalid.'));
    }
    else
    {
        $category = $c->model('LIXUZDB::LzCategory')->find({category_id => $uid});
        my $immediateChildren = $c->model('LIXUZDB::LzCategory')->search({ parent => $uid});
        while(my $child = $immediateChildren->next)
        {
            $child->set_column('parent',undef);
            if ($child->get_column('root_parent') == $uid)
            {
                $child->set_column('root_parent',undef);
                $self->recalculateRoot($c, $child->category_id, $child->children);
            }
            $child->update();
        }
        $category->delete();
        $self->messageToList($c,$i18n->get('Category deleted'));
    }
}

# Summary: Build a form with localized field labels and optionally pre-populated
# Usage: $self->buildform($c,'TYPE',\%Populate);
# 'TYPE' is one of:
# 	add => we're adding a category
# 	edit => we're editing an existing category
# \%Populate is a hashref in the form:
# 	fieldname => default value
# This will pre-populate fieldname with the value specified
sub buildform: Private
{
    my ( $self, $c, $type, $populate, $category ) = @_;
    my $form = $self->formbuilder;
    my $i18n = $c->stash->{i18n};
    $c->stash->{template} = 'adm/categories/editform.html';
    # Name mapping of field name => title
    my %NameMap = (
        category_name => $i18n->get('Category name'),
        category_status => {
            label => $i18n->get('Status'),
            options => [
            $i18n->get('Active'),
            $i18n->get('Inactive'),
            ],
        },
        external_link => $i18n->get('URL'),
        folders => $i18n->get('Folders'),
        template => $i18n->get('Template'),
    );
    # Set some context dependant settings
    if ($type eq 'add')
    {
        # We're creating a category
        $form->submit([$i18n->get('Create category')]);

        $c->stash->{pageTitle} = $i18n->get('Create category');
    }
    elsif ($type eq 'edit')
    {
        # Editing a category
        $form->submit([$i18n->get('Save changes')]);
        # It's not possible to edit the categoryname
        $form->field(
            name => 'category_name',
            disabled => 1,
        );
        $c->stash->{pageTitle} = $i18n->get_advanced('Editing category %(CATEGORY_ID)',{ CATEGORY_ID => $category->category_id});
    }
    else
    {
        die("Got invalid type in Categories.pm: $type");
    }
    # Add a hidden field with the type
    $form->field(
        name => 'type',
        value => $type,
    );
    # Create a default population if it doesn't already exist
    if(not defined $populate)
    {
        $populate = {
            category_status => $i18n->get('Active'),
        };
    }
    # Set default role for a category if it exists
    else
    {
        if ($populate->{category_status})
        {
            $populate->{category_status} = $i18n->get($populate->{category_status});
        }
    }
    # Finally, add names as defined in the NameMap, and populate the
    # fields if possible
    finalize_form($form,$c,{
            fields => \%NameMap,
            fieldvalues => $populate,
        });
    my $tree = $self->buildtree($c,$category);
    $tree = '<option value="NONE">'.$i18n->get('No parent').'</option>'.$tree;
    $c->stash->{parents_dropdown} = $tree;
    # We're just using the articles handler.
    my $dnd = LIXUZ::HelperModules::DragDrop->new($c,'LIXUZDB::LzFolder','/admin/articles/folderAjax/',
        {
            name => 'folder_name',
            uid => 'folder_id',
        },
        {
            immutable => 1, # FIXME: Drop
            onclick => 'toggleHilight',
        },
    );
    $c->stash->{dragdrop} = $dnd->get_html();
    if ($category)
    {
        my $folders = $category->folders;
        my @fList;
        while((defined $folders) && (my $f = $folders->next))
        {
            push(@fList,$f->folder_id);
        }
        add_globalJSVar($c,'hilightedFoldersSeed','['.join(',',@fList).']');
    }
    else
    {
        add_globalJSVar($c,'hilightedFoldersSeed','new Array()');
    }
    add_jsOnLoad($c,'loadHilightedFolderSeedInit');
	add_jsIncl($c,$dnd->get_jsfiles());
	add_cssIncl($c,$dnd->get_cssfiles());
}

# Summary: Save form data
# Usage: $self->savedata($c,$form);
# Assumes that you have already checked $form->validate
sub savedata: Private
{
    my ( $self, $c, $form ) = @_;
    my $i18n = $c->stash->{i18n};
    my $fields = $form->fields;
    my $uid = $fields->{'uid'};
    my $type = $fields->{'type'};
    my $category;
    if ($type eq 'edit')
    {
        $category = $c->model('LIXUZDB::LzCategory')->find({category_id => $uid});
    }
    elsif($type eq 'add')
    {
        $category = $c->model('LIXUZDB::LzCategory')->create({});
    }
    else
    {
        die("Invalid type in Categories.pm: $type");
    }
    if(not $category)
    {
        die("Failed to look up or create category");
    }
    if(defined $fields->{parent})
    {
        my $newValue;
        if ($fields->{parent} eq 'NONE')
        {
            $newValue = undef;
        }
        elsif ($fields->{parent} =~ /^\d+$/)
        {
            $newValue = $fields->{parent};
        }
        else
        {
            $c->log->warn('Invalid value for parent, assuming no parent');
        }
        $category->set_column('parent',$newValue);
        my $origNewValue = $newValue;
        if ($newValue)
        {
            $newValue = $c->model('LIXUZDB::LzCategory')->find({category_id => $newValue });
            if ($newValue)
            {
                $newValue = $newValue->root_parent;
                if ($newValue)
                {
                    $category->set_column('root_parent',$newValue);
                }
            }
        }
        if (not $newValue && defined $origNewValue)
        {
            $newValue = $origNewValue;
            $category->set_column('root_parent',$origNewValue);
        }
        else
        {
            $newValue = $category->category_id;
            $category->set_column('root_parent',undef);
        }
        if(my $children = $category->children)
        {
            $self->recalculateRoot($c, $newValue, $children);
        }
    }
    foreach my $field (qw(category_name external_link))
    {
        if ($fields->{$field})
        {
            $category->set_column($field,$fields->{$field});
        }
    }
    if ($fields->{category_status})
    {
        if ($fields->{category_status} eq $i18n->get('Inactive'))
        {
            $category->set_column('category_status','Inactive');
        }
        else
        {
            $category->set_column('category_status','Active');
        }
    }
    # Update the DB
    $category->update();
    # Set folders
    my %folders;
    if (length $fields->{hilightedFolders})
    {
        foreach my $id(split(/,/,$fields->{hilightedFolders}))
        {
            next if not (defined $id && length $id);
            $folders{$id} = 1;
        }
    }

    my $folderList = $category->folders;
    while((defined $folderList) && (my $f = $folderList->next))
    {
        if(not $folders{$f->folder_id})
        {
            $f->delete();
        }
        else
        {
            delete($folders{$f->folder_id});
        }
    }

    foreach my $folder_id (keys %folders)
    {
        if(my $f = $c->model('LIXUZDB::LzCategoryFolder')->create({category_id => $category->category_id, folder_id => $folder_id}))
        {
            $f->update();
        }
        else
        {
            $c->log->warn('Failed to create LzCategoryFolder relationship for: category_id('.$category->category_id.') => folder_id('.$folder_id.')');
        }
    }
    $self->messageToList($c,$i18n->get('Category data saved'));
}

# Summary: Recalculate root_parent for every child of the supplied object
# Usage: $self->recalculateRoot($c, $newRootUID, $obj);
sub recalculateRoot
{
    my ($self, $c, $newUID, $obj) = @_;

    while(my $s = $obj->next)
    {
        $s->set_column('root_parent',$newUID);
        $s->update();
        if ( my $children = $s->children )
        {
            $self->recalculateRoot($c,$newUID,$children);
        }
    }
}

# Summary: Builds a tree of categories into a string of <option></option> pairs
# Usage: $tree = $self->buildtree($c, $ignore?, ($obj), ($currParent));
# $ignore is the category_id to ignore when building the tree
#
# $obj is only used internally for recursively calling itself
# $currParent is only used internally for tracking parents
sub buildtree : Private
{
    my ($self, $c, $ignore, $obj, $currParent) = @_;

    if(not $obj)
    {
        return '' if $currParent;
        $obj = $c->model('LIXUZDB::LzCategory')->search({ parent => \'IS NULL'});
    }

    $currParent = defined $currParent ? $currParent.'/' : '/';

    my $str = '';

    while(my $s = $obj->next)
    {
        if (defined $ignore && $s->category_id == $ignore->category_id)
        {
            next;
        }
        my $children = $s->children;
        $str .= '<option value="'.$s->category_id.'"';
        if (defined $ignore && defined $ignore->parent && $ignore->parent->category_id == $s->category_id)
        {
            $str .= ' selected="selected"';
        }
        $str .= '>'.$currParent.$s->category_name.'</option>';
        $str .= $self->buildtree($c,$ignore,$children,$currParent.$s->category_name);
    }
    return $str;
}
1;
