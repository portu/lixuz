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

package LIXUZ::Controller::Admin::Dictionary;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
BEGIN { extends 'Catalyst::Controller::FormBuilder' };
with 'LIXUZ::Role::List::Database';

use LIXUZ::HelperModules::Search qw(perform_search perform_advanced_search);
use LIXUZ::HelperModules::Forms qw(finalize_form);

sub index : Path Args(0) Form('/core/search') {
    my ( $self, $c, $query ) = @_;

    my $dictionary = $c->model('LIXUZDB::LzKeyValue')->search({
            type => 'dictionary'
        });
    $c->stash->{pageTitle} = $c->stash->{i18n}->get('Dictionary');
    $self->handleListRequest($c,{
            c => $c,
            object => $dictionary,
            objectName => 'dictionary',
            template => 'adm/dictionary/index.html',
            orderParams => [qw(keyvalue_id thekey value)],
            searchColumns => [qw(keyvalue_id thekey value)],
            paginate => 1,
        });
}

# Summary: Delete a definition
sub delete: Local Args
{
    my ( $self, $c, $uid ) = @_;
    my $i18n = $c->stash->{i18n};
    my $definition;
    $c->stash->{template} = 'adm/core/dummy.html';
    # If we don't have an UID then just give up
    if (not defined $uid or $uid =~ /\D/)
    {
        $self->messageToList($c,$i18n->get('Error: Failed to locate UID. The path specified is invalid.'));
    }
    else
    {
        $definition = $c->model('LIXUZDB::LzKeyValue')->find({keyvalue_id => $uid, type => 'dictionary'});
        $definition->delete();
        $self->messageToList($c,$i18n->get('Definition deleted'));
    }
}

# Summary: Handle creating a new dictionary
sub add: Local Form('/dictionary/edit') {
    my ( $self, $c ) = @_;
    my $i18n = $c->stash->{i18n};
    my $form = $self->formbuilder;
    if ($form->submitted && $form->validate)
    {
        my $exists = $c->model('LIXUZDB::LzKeyValue')->find({thekey => $form->fields->{word}, type => 'dictionary'});
        if ($exists)
        {
            $c->stash->{message} = '<b>'.$i18n->get_advanced('Error: a definition of the word "%(WORD)" already exists with the word id %(WORDID)', {
                    WORD => $form->fields->{word},
                    WORDID => $exists->keyvalue_id,
                }).'</b>';
            $self->buildform($c,'add',{
                    word => $form->fields->{word},
                    definition => $form->fields->{definition},
                });
        }
        else
        {
            $self->savedata($c,$form);
        }
    }
    $self->buildform($c,'add');
}

# Summary: Handle editing an existing dictionary
sub edit: Local Args Form('/dictionary/edit') {
    my ( $self, $c, $uid ) = @_;
    my $form = $self->formbuilder;
    # Categoryname is not required here, it's just included for completeness
    $form->field(
        name => 'thekey',
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
            # Check if the dictionary exists
            my $dictionary = $c->model('LIXUZDB::LzKeyValue')->find({keyvalue_id => $uid, type => 'dictionary'});
            if(not $dictionary)
            {
                # Didn't exist, give up
                $self->messageToList($c,$i18n->get_advanced('Error: Failed to locate a dictionary with the UID %(UID).', { UID => $uid }));
            }
            else
            {
                # Existed, generate our form and display it
                $form->field(
                    name => 'uid',
                    type => 'hidden',
                    value => $uid,
                );
                $self->buildform($c,'edit',{
                        word => $dictionary->thekey,
                        definition => $dictionary->value,
                    }
                    ,$dictionary);
            }
        }
    }
}

# Summary: Build a form with localized field labels and optionally pre-populated
# Usage: $self->buildform($c,'TYPE',\%Populate);
# 'TYPE' is one of:
# 	add => we're adding a dictionary
# 	edit => we're editing an existing dictionary
# \%Populate is a hashref in the form:
# 	fieldname => default value
# This will pre-populate fieldname with the value specified
sub buildform: Private
{
    my ( $self, $c, $type, $populate, $dictionary ) = @_;
    my $form = $self->formbuilder;
    my $i18n = $c->stash->{i18n};
    $c->stash->{template} = 'adm/dictionary/editform.html';
    # Name mapping of field name => title
    my %NameMap = (
        word => $i18n->get('Word'),
        definition => $i18n->get('Definition'),
    );
    # Set some context dependant settings
    if ($type eq 'add')
    {
        # We're creating a definition
        $form->submit([$i18n->get('Create definition')]);

        $c->stash->{pageTitle} = $i18n->get('Create definition');
    }
    elsif ($type eq 'edit')
    {
        # Editing a definition
        $form->submit([$i18n->get('Save changes')]);
        $c->stash->{pageTitle} = $i18n->get_advanced('Editing definition %(DICTIONARY_ID)',{ DICTIONARY_ID => $dictionary->keyvalue_id});
    }
    else
    {
        die("Got invalid type in Dictionary.pm: $type");
    }
    # Add a hidden field with the type
    $form->field(
        name => 'type',
        value => $type,
    );
    # Create a default population if it doesn't already exist
    $populate = $populate ? $populate : {};
    # Finally, add names as defined in the NameMap, and populate the
    # fields if possible
    finalize_form($form,$c,{
            fields => \%NameMap,
            fieldvalues => $populate,
        });
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
        $category = $c->model('LIXUZDB::LzKeyValue')->find({keyvalue_id => $uid});
    }
    elsif($type eq 'add')
    {
        $category = $c->model('LIXUZDB::LzKeyValue')->create({ type => 'dictionary'});
    }
    else
    {
        die("Invalid type in Dictionary.pm: $type");
    }
    if(not $category)
    {
        die("Failed to look up or create dictionary entry");
    }
    $category->set_column('thekey',$fields->{word});
    $category->set_column('value',$fields->{definition});
    # Update the DB
    $category->update();
    $self->messageToList($c,$i18n->get('Definition saved'));
}

1;
