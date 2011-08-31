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
 * Categories JavaScript for LIXUZ
 *
 * Copyright (C) Portu media & communications
 * All Rights Reserved
 */

var hilightedFolders;

/*
 * Summary: Loads the seed array of hilighed folders into our hilightedFolders hash, and
 *  deletes the seed. This is because the hash is a lot easier to manipulate later to contain
 *  boolean fields (arrays indexOf and friends doesn't work reliably), and the hash object
 *  isn't available to the HTML until after loading, therefore this can be used as an onload
 *  action to initialize.
 */
function loadHilightedFolderSeedInit ()
{
    hilightedFolders = {};
    try
    {
        for(var i = 0; i < hilightedFoldersSeed.length; i++)
        {
            toggleHilight(hilightedFoldersSeed[i]);
        }
        hilightedFoldersSeed = null;
        hilightedFoldersPush();
    }
    catch(e)
    {
        alert('Failed to init folder seed. Folders are now out of sync with the server.'+"\n\n"+e);
    }
}

/*
 * Summary: Toggles hilighting of a folder in the folder list, updating the hilightedFolders
 *  hash in the process. To be called as an onclick action.
 */
function toggleHilight(uid)
{
    if(uid == 'root' || uid == null)
        return;
    if (!hilightedFolders)
    {
        setTimeout('toggleHilight("'+uid+'");',500);
        return;
    }
    var $obj = $('[uid='+uid+'] a').first();
    if (!$obj.length)
    {
        userMessage('Failed to locate object with uid: '+uid);
        return;
    }
    var content = $obj.html();
    if(hilightedFolders[uid])
    {
        content = content.replace(/<\/?b>/,'');
        delete hilightedFolders[uid];
    }
    else
    {
        content = '<b>'+content+'</b>';
        hilightedFolders[uid] = true;
    }
    $obj.html(content);
    if(hilightedFoldersSeed == null)
    {
        hilightedFoldersPush();
    }
}

/*
 * Summary: Push a list of hilighted UIDs into a hidden field on the page
 */
function hilightedFoldersPush ()
{
    if (! $('#hilightedFolders').length)
    {
        return;
    }
    var folders = getHilightedFoldersList();
    var folderList = '';
    for(var i = 0; i < folders.length; i++)
    {
        folderList = folderList+folders[i]+',';
    }
    $('#hilightedFolders').val(folderList);
}

/*
 * Summary: Get an array containing the UIDs of the folders that are hilighted in
 *  the folder list.
 */
function getHilightedFoldersList ()
{
    var folders = [];
    $.each(hilightedFolders, function (key,value) {
        folders.push(key);
    });
    return folders;
}
