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

# LIXUZ::HelperModules::Forms
#
# This module contains functions that assists with forms
#
# It exports nothing by default, you need to explicitly import the
# functions you want.
package LIXUZ::HelperModules::Forms;

use strict;
use warnings;
use Exporter qw(import);
use Carp;
our @EXPORT_OK = qw(finalize_form select_options select_options_manually get_checkboxes createCheckbox);

# Summary: Finalize a form
# Usage: finalize_form($form, $c, \%content);
# $c is allowed to be undef, if it is then it will not add a reset button
# \%content is in the following form, all keys optional:
# {
# 	action => FORM_ACTION,
# 	submit => [ list, of, submit, values ],
# 	submit => SINGLE_SUBMIT_VALUE,
# 	fields => {
# 		field_name => LABEL,
#		field_name => {
#			options => [list, of, options ],
#			label => LABEL,
#			},
#		field_name => {
#			label => LABEL,
#		},
# 		},
# 	fieldvalues => {
# 		field_name => INITIAL_VALUE,
# 	},
# }
#
# fieldvalues will ONLY be added for fields that are also present in the fields hashref.
#
# As you can see the fields hashref is either a name => label mapping, or a name => hashref
# mapping. The name => label mapping is simply a short form of name => {label => 'LABEL'}.
sub finalize_form
{
    my $form = shift;
    my $c = shift;
    my $content = shift;

    if(not defined $form)
    {
        croak('No form supplied');
    }
    elsif(not defined $content)
    {
        croak('No content supplied');
    }

    # Add action
    if ($content->{action})
    {
        $form->action($content->{action});
    }
    # Add submit, handling getting both a reference and a scalar
    if ($content->{submit})
    {
        if(ref($content->{submit}))
        {
            $form->submit($content->{submit});
        }
        else
        {
            $form->submit([$content->{submit}]);
        }
    }
    # Go through all normal fields we know of
    foreach my $title (keys %{$content->{fields}})
    {
        my $label;
        my $gotRef = ref($content->{fields}{$title}) ? 1 : 0;
        # If it's not a reference just shove it directly into $label
        if(not $gotRef)
        {
            $label = $content->{fields}->{$title};
        }
        else
        {
            $label = $content->{fields}->{$title}->{label};
        }
        # Set the options field and label
        if($gotRef && defined $content->{fields}->{$title}->{options})
        {
            $form->field(
                name => $title,
                label => $content->{fields}->{$title}->{label},
                options => $content->{fields}->{$title}->{options},
                value => '',
            );
        }
        # Set only the label
        elsif ($label)
        {
            $form->field(
                name => $title,
                label => $label,
                value => '',
            );
        }
        # Set default value if present in fieldvalues
        if (defined $content->{fieldvalues}->{$title})
        {
            $form->field(
                name => $title,
                value => $content->{fieldvalues}->{$title},
                selectname => 0,
            );
        }
    }
    if ($c)
    {
        $form->reset($c->stash->{i18n}->get('Reset'));
    }
    return 1;
}


# Summary: Generates the option fields for a 'select' field
# Usage: $options = select_options($form->field);
# <select><% $options %></select>
sub select_options{
    my $field = shift;
    my $i18n = shift;
    my $options='';

    for(@{$field->{options}})
    {
        my $var = (defined $field->{value} && $_ eq $field->{value}) ? 'SELECTED' : '';
        $options.="<option value=\"$_\" $var>$_</option>";
    }

	if(not $options)
	{
        if ($i18n)
        {
            $options = '<option value="">'.$i18n->get('-select-').'</option>';
        }
        else
        {
            $options = '<option value="">-select-</option>';
        }
	}

    return $options;
}

# Summary: Generates the option fields for a manually created 'select' field
# Usage: $options = select_options_manually({options});
# <select><% $options %></select>
# {options} is in the form:
# [
# 	{
#		value => 'VALUE',
# 		name => 'NAME',
# 		selected => bool,
# 	]
# }
sub select_options_manually
{
    my $values = shift;
    my $options='';

	foreach my $val (@{$values})
	{
		$options .= '<option value="'.$val->{value}.'"';
		if ($val->{selected})
		{
			$options .= ' selected="selected"';
		}
		$options .= '>'.$val->{name}.'</option>';
	}

	# FIXME: i18n
	if(not $options)
	{
		$options = '<option value="">-select-</option>';
	}

    return $options;
}

# Summary: Generates a list of checkboxes
# Usage: $boxes = get_checkboxes({options});
# {options} is identical to that of select_options_manually
sub get_checkboxes
{
    my $values = shift;
    my $boxes ='';

	foreach my $val (@{$values})
	{
        $boxes .= '<input type="checkbox" name="checkbox_'.$val->{value}.'" id="checkbox_'.$val->{value}.'"';
		if ($val->{selected})
		{
			$boxes .= ' checked="checked"';
		}
        if ($val->{uid})
        {
            $boxes .= ' uid="'.$val->{uid}.'"';
        }
		$boxes .= '>'.$val->{name}.'<br />';
	}

    return $boxes;
}

# Summary: Create a pretty checkbox, where the entire thing can be clicked
# Usage: createCheckbox(label,id, checked?, onchange?, addHtml)
#
# label is the text label for the checkbox
# id is the id= value, it is also used for name=
# checked is a boolean, true if it is checked. Defaults to false.
# onchange is a javascript string to put in onchange=, it will have an exceptions handler
#   wrapped around it.
# options is a hashref, with one or more of the following keys:
#   addHtml:  addHtml any HTML you want added to the generated checkbox
#       element, ie. you can set this to 'uid="meh"' or use it to append a name=
#   addHtmlLabel: if set, a span will be created around the label, and this
#       text will be inside the span tag.
sub createCheckbox
{
    my($label,$id,$checked,$onchange,$options) = @_;
    $options = $options ? $options : {};
    if ($onchange)
    {
        $onchange = 'try { '.$onchange.' } catch(oe) { lzException(oe); }';
    }

    my $js = 'try { var c = $(\''.$id.'\'); if(c.checked) { c.checked = false; } else { c.checked = true }; var oc = function() { '.$onchange.' }; oc.call(c); '.$onchange.'; } catch(e) { lzException(e); }; return false';
    my $s = '<a href="#" onclick="'.$js.'" style="text-decoration: none;"><input type="checkbox" id="'.$id.'"';
    if ($onchange)
    {
        $s .= ' onchange="'.$onchange.'"';
    }
    if ($checked)
    {
        $s .= ' checked="checked"';
    }
    if ($options->{addHtml})
    {
        $s .= ' '.$options->{addHtml};
    }
    $s .= ' /> ';
    if ($options->{addHtmlLabel})
    {
        $s .= '<span '.$options->{addHtmlLabel}.'>'.$label.'</span>';
    }
    else
    {
        $s .= $label;
    }
    $s .= '</a>';
    return $s;
}

1;
