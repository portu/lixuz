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
// Handle changes in the template action dropdown
function templateAction (id)
{
    var entry = $('#template_action_'+id);
    var val = entry.val();
    entry.val('label');
    if(val == 'delete')
    {
        userMessage('Delete is not implemented.');
        return;
        deleteTemplate(id);
    }
    else if(val == 'setdefault')
    {
        template_setDefault(id);
    }
    else if(val == 'replace')
    {
        userMessage('Replace is not implemented.');
        return;
    }
    else if(val == 'label')
    {
        return;
    }
    else
    {
        lzError('Invalid action in templateAction for id '+id+': '+val);
    }
}
var deleteThisTemplate,
    setTemplateAsDefault;

function template_asyncDone ()
{
    setTemplateAsDefault = null;
    deleteThisTemplate = null;
    window.location.reload();
}

// Prompt the user to delete the supplied subscription
function deleteTemplate (template_id)
{
    deleteThisTemplate = template_id;
    AuserQuestion(i18n.get('Are you sure you wish to delete this template? If there are no other templates of the same type the website might crash when rendering pages that used to use this template.'),'deleteTemplateNow');
}

// Submit a delete request to the server if response is true
function deleteTemplateNow (response)
{
    if(response)
    {
        showPI(i18n.get('Deleting...'));
        XHR.GET('/admin/templates/delete/'+deleteThisTemplate,template_asyncDone);
    }
}

// Prompt the user to delete the supplied subscription
function template_setDefault (template_id)
{
    setTemplateAsDefault = template_id;
    AuserQuestion(i18n.get('Are you sure you wish to set this template as the default for its type?'),'template_setDefaultNow');
}

// Submit a delete request to the server if response is true
function template_setDefaultNow (response)
{
    if(response)
    {
        showPI(i18n.get('Setting as default...'));
        XHR.GET('/admin/templates/setDefault/'+setTemplateAsDefault,template_asyncDone);
    }
}
