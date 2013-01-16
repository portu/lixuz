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

# LIXUZ::HelperModules::Editor
#
# This module generates HTML and JS for the editor widget.
#
# SYNOPSIS:
# use LIXUZ::HelperModules::Editor qw(create_editor);
# $c->stash->{yourEditorStash} = create_editor($c, 'id tag', { params });
#
# value is optional, the default value of the field.
#
# Then in the view:
# <% $yourEditorStash |n%>
#
# This does all the magic, generating the HTML, JS and adding needed
# includes.
package LIXUZ::HelperModules::Editor;
use strict;
use warnings;
use Carp;
use Exporter qw(import);
use LIXUZ::HelperModules::Includes qw(add_jsIncl add_cssIncl add_globalJSVar add_bodyClass add_jsOnLoad add_jsHeadCode add_CDNload);
our @EXPORT_OK = qw(create_editor add_editor_incl);

sub add_editor_incl
{
    my $c = shift;

    # For now the editor is loaded statically by the footer as long as
    # the loadRTE boolean in the stash is true
    $c->stash->{loadRTE} = 1;
}

# Summary: Create a editor widget
# Usage: html = create_editor($c, widget_id, default_value);
# { params } can be undef, or contain zero or more of the following:
# {
# 	value => default value,
#   name => the name of the field, defaults to widget_id,
#   cols => cols of the textarea (defaults to 50 OR data from $form),
#   rows => rows of the textarea (defaults to 10 OR data from $form),
# 	form => $form object,
#   inline => the inline field that this editor is for,
# }
sub create_editor
{
	my ($c, $id, $params) = @_;

    my $formFields;

    if(not $params)
    {
        $params = {};
    }
    if ($params->{form})
    {
        $formFields = {};
        foreach my $field ($params->{form}->fields)
        {
            $formFields->{$field} = $field;
        }
    }
    if(not $params->{cols})
    {
        if ($formFields && $formFields->{$id}->{cols})
        {
            $params->{cols} = $formFields->{$id}->{cols};
        }
        else
        {
            $params->{cols} = 75;
        }
    }
    if(not $params->{rows})
    {
        if ($formFields && $formFields->{$id}->{rows})
        {
            $params->{rows} = $formFields->{$id}->{rows};
        }
        else
        {
            $params->{rows} = 10;
        }
    }
    if(not $params->{name})
    {
        $params->{name} = $id;
    }
    if(not $params->{value})
    {
        $params->{value} = '';
    }

    add_editor_incl($c);

    my $html = '<span class="yui-skin-sam">'."\n"; 
    $html .= '<textarea class="yui-RTE" name="'.$params->{name}.'" id="'.$id.'" cols="'.$params->{cols}.'" rows="'.$params->{rows}.'">';
    $html .= $params->{value};
    $html .= '</textarea>';
	$html .= "\n<script type='text/javascript'>\n";
    my $js = '';
    $js = '$LAB.queue(function () {'."\n";
    $js .= '$(function () {'."\n";
    my $inline = $params->{inline} ? "'".$params->{inline}."'" : 'null';
    $js .= "\tlixuzRTE.init('".$id."',".$inline.");\n";
    $js .= '})});'."\n";
    $html .= $js;
    $html .= "\n".'</script>';
    $html .= '</span>'."\n";

    return $html;
}
1;
