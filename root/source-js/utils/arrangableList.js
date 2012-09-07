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
/*
 * An arrangeable javascript list for Lixuz.
 *
 * Copyright (C) Portu media & communications
 * All Rights Reserved
 */

/*
 * PUBLIC FUNCTIONS
 */

/*
 * Creates a new modal JS window containing a table-like structure of data
 * that can be rearranged.
 *
 * settings is a hash that can contain the following values (those ending with
 * * are obligatory)
 *
 * title*            = the title of the window
 *
 * saveFunction*     = the function to call with the new data when done.
 *                     NOTE: This does not get called if the window is closed
 *                     using the X, or Cancel
 *
 * headers*          = a one-level array of table headers with their names
 *
 * data*             =  A hash of arrays. The hash keys are the ID related to
 *                      the element being sorted (ie. UID). THe inner arrays
 *                      are equal to the inner arrays from createTableFromData
 *                      in standard.js
 * saveButtonName    = The name of the button that closes the app and provides
 *                      saveFunction with the list of data. Defaults to 'Save
 *                      and close'
 *
 * defaultOrder      = An array of IDs (from data) in the order that you want
 *                     them to appear. If this is not supplied then the order
 *                     will pretty much be random (or rather, whichever order
 *                     .each() supplies them).  Caveat: If you supply this it
 *                     must contain ALL keys from data. Those NOT present will
 *                     NOT get displayed as we only loop over this.
 *
 * checkButtonMode   = the first column gets made into a checkbutton field
 *                      named "Enabled?" or the value of checkButtonName.  This
 *                      is a bool. If it is enabled then only those with their
 *                      checkbuttons checked will be returned, and those that
 *                      don't have will be at the bottom and not arrangable.
 *
 * checkButtonName   = see above
 *
 * defaultChecked    = a hash of the IDs that should be checked by default in
 *                      checkButtonMode. The IDs whose value is boolean true in
 *                      this hash will be checked in the list by default.
 *                      WARNING: If you do NOT supply defaultOrder (or supply a
 *                      defaultOrder that is not valid) then this might mess up
 *                      the internal state of the dialog completely, as all
 *                      checked entries should be at the top of the dialog at
 *                      all times. It will probably work fine, but it will look
 *                      strange to users.
 */
function newArrangableListWindow (settings)
{
    /*
     * First - prepare settings and do some basic validation
     */

    currListSettings = {
        'order': []
    };
    // Required settings
    var required = ['title', 'saveFunction', 'headers','data'];
    for(var i = 0; i < required.length; i++)
    {
        var name = required[i];
        if(settings[name] == null)
        {
            lzError('newArrangableListWindow(): error: '+name+' is missing/null. Failed to create window');
            return;
        }
        currListSettings[name] = settings[name];
    }
    var defaults = {
        'checkButtonMode': false,
        'checkButtonName': i18n.get('Enabled?'),
        'saveButtonName': i18n.get('Save and close')
    };
    currListSettings.headers.push('&nbsp');
    currListSettings.headers.push('&nbsp');
    if (settings['defaultOrder'] == null)
    {
        $.each(currListSettings.data, function(key,value)
        {
            currListSettings['order'].push(key);
        });
    }
    else
    {
        currListSettings['order'] = settings['defaultOrder'];
    }
    var optional = ['checkButtonMode','checkButtonName', 'saveButtonName'];
    for(var name in optional)
    {
        name = optional[name];
        var value = settings[name];
        if(value == null)
        {
            value = defaults[name];
        }
        currListSettings[name] = value;
    }

    if (currListSettings.checkButtonMode)
    {
        currListSettings.headers.unshift(currListSettings.checkButtonName);
        if(settings.defaultChecked != null)
        {
            currListSettings.checked = settings.defaultChecked;
        }
        else
        {
            currListSettings.checked = {};
        }
    }

    /*
     * Ok, now we have all the data we need, we can now create the initial list
     * and display it.
     */
    var HTML_table = getCurrentList();
    displayListDialog('<div style="height:90%; overflow: auto;" id="arrListInner">'+HTML_table+'</div>',currListSettings.title);
}

/*
 * INTERNAL FUNCTIONS
 */
var currListSettings;

function toggleListChecked (id,oldPos)
{
    var button = $('#listCheckButton_'+id)[0];
    if (!button)
    {
        lzError('Error: toggleListChecked('+id+'); called - but the param is unknown');
        return;
    }
    var moveTo;
    if(button.checked)
    {
        currListSettings.checked[id] = true;
        if(currListSettings.lastChecked)
        {
            moveTo = currListSettings.lastChecked + 1;
        }
        else
        {
            moveTo = 0;
        }
        currListSettings.lastChecked = moveTo;
    }
    else
    {
        currListSettings.checked[id] = false;
        if(currListSettings.lastChecked != null)
        {
            moveTo = currListSettings.lastChecked;
        }
    }
    if(moveTo != null)
    {
        listBumpThisTo(id,moveTo,oldPos);
    }
}

/*
 * Fetches the current list
 */
function getCurrentList ()
{
    var myList = [],
        lastChecked;
    for(var i = 0; i < currListSettings.order.length; i++)
    {
        var id = currListSettings.order[i],
            val = currListSettings.data[id],
            myArray = [],
            isChecked = false;
        for(var n = 0; n < val.length; n++)
        {
            myArray.push(val[n]);
        }
        if (currListSettings.checkButtonMode)
        {
            var checked = '';
            if(currListSettings.checked[id] != null && ( currListSettings.checked[id] == true || currListSettings.checked[id] == 1))
            {
                isChecked = true;
                checked='checked="checked"';
                currListSettings.lastChecked = i;
            }
            myArray.unshift('<input type="checkbox" '+checked+' id="listCheckButton_'+id+'" onchange="toggleListChecked(\''+id+'\','+i+');" />');
        }
        else
        {
            isChecked = true;
        }
        if(i > 0 && isChecked)
        {
            var bump = i - 1;
            myArray.push('<a href="#" onclick="listBumpThisTo('+id+','+bump+','+i+'); return false;"><img style="border:0;" src="/static/images/arrow_up-16x16.png" alt="Up" /></a>');
        }
        else
        {
            myArray.push('&nbsp');
        }
        if(i != (currListSettings.order.length - 1) && isChecked)
        {
            var bump = i + 1;
            myArray.push('<span id="bumpDown_'+id+'"><a href="#" onclick="listBumpThisTo('+id+','+bump+','+i+'); return false;"><img style="border:0;" src="/static/images/arrow_down-16x16.png" alt="Down" /></a></span>');
        }
        else
        {
            myArray.push('&nbsp');
        }
        myList.push(myArray);
        if(isChecked)
        {
            lastChecked = myList.length -1;
        }
    }
    if (lastChecked != null)
    {
        myList[lastChecked].pop();
        myList[lastChecked].push('&nbsp;');
    }
    var HTML_table = createTableFromData(currListSettings.headers, myList);
    return HTML_table;
}

/*
 * Create a new dialog and display the HTML supplied in it
 */
function displayListDialog (html,title)
{
    var button = '<input type="button" name="listDialogOK" onclick="listDialog_saveAndClose();" value="'+currListSettings.saveButtonName+'" />',
        buttons = {};
    buttons[currListSettings.saveButtonName] = listDialog_saveAndClose;
    currListSettings.dialog = new dialogBox(html,{buttons:buttons, title:title, width:500, height:340}, { closeButton: i18n.get('Cancel') });
}

/*
 * The function called when the user clicks the save and close button.
 * This handles calling the callback and destroying the dialog.
 */
function listDialog_saveAndClose ()
{
    currListSettings.dialog.hide();
    currListSettings.dialog.destroy();
    var finalList = [];
    if(currListSettings.checkButtonMode == true)
    {
        for(var i = 0; i < currListSettings.order.length; i++)
        {
            var id = currListSettings.order[i];
            if(currListSettings.checked[id] != null && ( currListSettings.checked[id] == true || currListSettings.checked[id] == 1))
            {
                finalList.push(id);
            }
        }
    }
    else
    {
        finalList = currListSettings.order;
    }
    currListSettings.saveFunction(finalList);
    currListSettings = {};
}

/*
 * Summary: Bump an item to a new position
 */
function listBumpThisTo(id, newpos, oldpos)
{
    currListSettings.order.splice(oldpos,1);
    insertAtPos(id, currListSettings.order, newpos);
    var HTML_table = getCurrentList();
    $('#arrListInner').html(HTML_table);
}

/*
 * Summary: This function inserts some data at a specified position in an array.
 * Usage: insertAtPos(data, the_array, position);
 *
 * It modifies the_array directly.
 */
function insertAtPos(data, arr, pos)
{
    // If we're inserting at the start or end (or beyond the end, which we
    // don't allow) then it's simple. Either push or unshift the value.
    if(arr.length <= pos)
    {
        arr.push(data);
        return arr;
    }
    else if(pos == 0)
    {
        arr.unshift(data);
        return arr;
    }
    // Otherwise, use splice()
    arr.splice(pos,0,data);
    return;
}
