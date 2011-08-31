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
function getPermBoxes ()
{
    // This function currently depends upon that getElementsByTagName returns
    // the elements in the order that they appear in the HTML. We might want to
    // make sure that this is a reasonable assumption in all browsers.
    var input = document.getElementsByTagName('input'),
        entries = [];
    for(var i = 0; i < input.length; i++)
    {
        var e = input[i];
        if(e.type != 'checkbox')
        {
            continue;
        }
        if ( e.getAttribute('isPermCheckbox') != 'true')
        {
            continue;
        }
        entries.push(e);
    }
    return entries;
}
function toggleSuperUser ()
{
    var input = getPermBoxes();
    for(var i = 0; i < input.length; i++)
    {
        var e = input[i];
        e.checked = true;
    }
}
function recalculateCheckedBoxes (caller)
{
    try
    {
        if(caller && caller.name == 'SUPER_USER' && caller.checked)
        {
            toggleSuperUser();
        }
    }
    catch(e) { }
    var input = getPermBoxes(),
        enabled = {};
    for(var i = 0; i < input.length; i++)
    {
        var e = input[i];
        if(e.getAttribute('parent') != null && e.getAttribute('parent') != '')
        {
            if (enabled[e.getAttribute('parent')] != true)
            {
                e.checked = false;
                e.disabled = 'disabled';
                try
                {
                    var child = $('#'+e.getAttribute('childLabel'));
                    child.html('<i>'+child.html()+'</i>');
                }
                catch(e) { }
                continue;
            }
            else
            {
                e.disabled = false;
                try
                {
                    var child = $('#'+e.getAttribute('childLabel'));
                    child.html(child.html().replace(/<i\/?>/g,''));
                }
                catch(e) { }
            }
        }
        if (! e.checked)
        {
            $('#SUPER_USER')[0].checked = false;
            continue;
        }
        enabled[e.name] = true;
    }
}
function getEnabledPerms ()
{
    var input = getPermBoxes(),
        enabled = {},
        entries = [];
    for(var i = 0; i < input.length; i++)
    {
        var e = input[i];
        if (! e.checked)
        {
            continue;
        }
        if(e.getAttribute('parent') != null && e.getAttribute('parent') != '')
        {
            if (enabled[e.getAttribute('parent')] != true)
            {
                continue;
            }
        }
        enabled[e.name] = true;
    }
    $.each(enabled, function(key,value)
    {
        var all = key.split(',');
        $.merge(entries,all);
    });
    return entries;
}
function roleSaveSuccess ()
{
    document.location.href = '/admin/users/roles';
}
function submitRoleData ()
{
    showPI(i18n.get('Saving...'));
    var submission = {},
        url = document.URL;
    submission['accessRights'] = getEnabledPerms().join(',');
    submission['name'] = $('#role_name').val();
    submission['status'] = $('#role_status').val();
    submission['roles_submitted'] = true;
    try
    {
        var id = $('#role_id');
        if(id[0])
        {
            submission['role_id'] = id.val();
        }
    } catch(e) { }
    if (! submission['name'])
    {
        destroyPI();
        userMessage(i18n.get('A name for the role is required. Please enter one.'));
        return;
    }
    JSON_HashPostRequest(url, submission, roleSaveSuccess);
}
