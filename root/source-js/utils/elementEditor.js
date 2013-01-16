/*
 * LIXUZ content management system
 * Copyright (C) Utrop A/S Portu media & Communications 2008-2011
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as
 * published by the Free Software Foundation, either version 3 of the
 * License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
var elementEditor;
// Override this if you want to trigger some action when an element is
// updated.
var savedElementReply = function () {
    destroyPI();
};

function editElement (element)
{
    showPI(i18n.get('Loading element data...'));
    XHR.GET('/admin/services/elements?action=info&elementId='+element,editElementReply,null);
}

function editElementReply (content)
{
    destroyPI();
    showElementEditor(content.id, content.key, content.value, content.type);
}

function addElement (type)
{
    if(type == null)
    {
        type = 'dictionary';
    }
    showElementEditor('','','',type);
}

function showElementEditor(elementId, key, value,type)
{
    var keyName,
        valueName;
    if (type == 'dictionary')
    {
        keyName = i18n.get('Word/phrase');
        valueName = i18n.get('Definition');
    }
    else
    {
        keyName = 'Key';
        valueName = 'Value';
    }
    var myWin = '<table>';
    myWin = myWin+'<tr><td>'+keyName+': </td><td><input id="element_key" type="text" value="'+key+'" /></td></tr>';
    myWin = myWin+'<tr><td>'+valueName+': </td><td><textarea id="element_value" name="element_value" cols="45" rows="5">'+value+'</textarea></td></tr>';
    myWin = myWin+'</table>';
    myWin = myWin+'<input type="hidden" id="element_type" value="'+type+'" /><input type="hidden" id="element_id" value="'+elementId+'" />';
    var buttons = {};
    buttons[i18n.get('Save changes')] = saveElementData;
    elementEditor = new dialogBox(myWin,{buttons:buttons, width:600, height:400}, { closeButton: i18n.get('Cancel') });
}

function saveElementData ()
{
    var data = {
            elementId: $('#element_id').val(),
            value: $('#element_value').val(),
            key: $('#element_key').val(),
            type: $('#element_type').val()
    };
    showPI(i18n.get('Saving...'));
    XHR.Form.POST('/admin/services/elements?action=save',data,savedElementReply,null);
    elementEditor.destroy();
    elementEditor = null;
}
