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
 * LIXUZ functions for drag+drop
 *
 * Requires: asyncHelper.js
 *
 * Copyright (C) Portu media & communications
 * All Rights Reserved
 */
var lixuz_DD_LastOrder;
var lixuz_DD_URL;
var lixuz_DD_FolderType = 'single';
var lixuz_DD_DialogBox;
var folderLimit_override;
var lixuz_DD_myDragDrop;

/*
 * Called whenever the ordering of the folder tree is changed
 */
function lixuz_DD_OrderChangeEvent ()
{
    // We're being run as a method on the dragdrop object, so we can
    // access it as this.

    // The actual ordering is alphabetical, so we don't care about simple
    // reordering the user is doing. Therefore we do our own sorting here
    // so that results are predictable, and to avoid sending useless
    // empty requests.
    var order;
    try
    {
        order = this.getNodeOrders().split(",").sort().join(",");
    }
    catch (n)
    {
        lzException(n);
        return;
    }
    if(order == lixuz_DD_LastOrder)
    {
        return;
    }
    lixuz_DD_LastOrder = order;
    $.get(lixuz_DD_URL+'?orderChange='+order,lixuz_DD_OrderReply);
}

/*
 * The reply from the server concerning the order change
 */
function lixuz_DD_OrderReply (text)
{
    text = text.split("\n");
    var reply = text.shift();
    if(! reply.match(/^OK/))
    {
        userMessage('An error occurred while saving the changes, press OK to refresh the list to the server copy.'+"\n\n(error: "+reply+")");
        showPI(i18n.get('Refreshing...'));
        lixuz_DD_RefreshList();
    }
}
/*
 * Sends a request for a new folder tree list
 */
function lixuz_DD_RefreshList ()
{
    $.get(lixuz_DD_URL+'?request=HTML_LIST',lixuz_DD_RefreshListReply);
}

/*
 * New folder tree recieved, rebuild using the new data
 */
function lixuz_DD_RefreshListReply (text)
{
    text = text.split("\n");
    var reply = text.shift();
    destroyPI();
    if(! reply.match(/^OK/))
    {
        userMessage("Error during fetching of new XHTML:\n"+reply);
        return;
    }
    $('#treeview').html(text.join("\n"));
    buildLXTreeView();
}

/*
 * Hide an item that has just been dropped
 */
function lixuz_DD_ItemHide(item,parentItem)
{
    parentItem.style.display = 'none';
    item.style.display = 'none';
    item.style.visibility = 'hidden';
    parentItem.style.visibility = 'hidden';

    // Handles hiding mouseOver elements from files/mouseOver.js if they
    // are present. We catch and ignore errors because if they're not, we don't care.
    try
    {
        if (mouseOverOut && ( $('#'+item.id+'_mouseOver').length || $('#'+parentItem.id+'_mouseOver').length))
        {
            mouseOverOut(item.id);
            mouseOverOut(parentItem.id);
        }
    }
    catch(e) {}
}

/*
 * Handle an item being dropped somewhere using d+d functions
 */
function lixuz_DD_ItemDropped(sourceId, targetId, mouseX, mouseY)
{
    var sourceObj = document.getElementById(sourceId);
    lixuz_DD_ItemHide(sourceObj,sourceObj.parentNode);
    var source = sourceObj.getAttribute('uid');
    targetId = targetId.replace(/^nodeATag/,'node');
    var targetObj = document.getElementById(targetId);
    if (!targetObj)
    {
        alert('Internal error: targetObj was false');
        return;
    }
    var target = targetObj.getAttribute('uid');
    if (target == null)
    {
        alert('target var was null, failed to fetch uid of targetObj. targetObj id='+targetObj.id);
        return;
    }
    $.get(lixuz_DD_URL+'?moveToFolder='+target+'&item='+source,lixuz_DD_ItemDropReply);
    return true;
}

/*
 * The reply from the server concerning the drop
 */
function lixuz_DD_ItemDropReply(text)
{
    text = text.split("\n");
    var reply = text.shift();
    if(! reply.match(/^OK/))
    {
        userMessage('An error occurred while saving the changes, please reload the page to update the state information of all entries.'+"\n\n(error: "+reply+")");
    }
}

// Prepare entities for dragdrop
function lixuz_DD_CreateDragDropEntities()
{
    var sources = [];
    var targets = [];
    var foundEntities = false;
    var foundSources = false;
    var foundTargets = false;
    var lastFound = true;
    for (var n = 0; n != null; n != null && n++)
    {
        var obj = document.getElementById('dragDropEntry'+n);
        if(obj)
        {
            foundEntities = true;
            foundSources = true;
            lastFound = true;
            sources.push(obj.id);
        }
        else
        {
            if (!lastFound)
            {
                n = null;
            }
            else
            {
                lastFound = false;
            }
        }
    }
    lastFound = true;
    for (var n = 0; n != null; n != null && n++)
    {
        var obj = document.getElementById('nodeATag'+n);
        if(obj)
        {
            foundTargets = true;
            foundEntities = true;
            lastFound = true;
            targets.push(obj.id);
        }
        else
        {
            if (!lastFound)
            {
                n = null;
            }
            else
            {
                lastFound = false;
            }
        }
    }
    if (!foundEntities || !foundTargets || !foundSources)
    {
        return;
    }
    else
    {
        try
        {
            var dragdrop = new dragDrop_dragDrop();
            for(var i = 0; i < sources.length; i++)
            {
                dragdrop.addSource(sources[i],true);
            }
            for(var i = 0; i < targets.length; i++)
            {
                dragdrop.addTarget(targets[i],'lixuz_DD_ItemDropped');
            }
            dragdrop.init();
            lixuz_DD_myDragDrop = dragdrop;
        }
        catch(e)
        {
            lzException(e);
        }
    }
}

/*
 * Limit our view to items that are in a specified folder
 */
function folderLimit (uid)
{
    if(folderLimit_override)
    {
        folderLimit_override(uid);
        return;
    }
    var uri = location.href;
    uri = uri.replace(/folder=[^\&]+/,'');
    uri = uri.replace(/#/,'');
    if (uri.indexOf('?') == -1)
    {
        uri = uri + '?';
    }
    uri = uri + '&';
    uri = uri.replace(/&+/,'&');
    if(uid == 'root')
    {
        uri = uri.replace(/\?\&$/,'');
    }
    else
    {
        uri = uri + 'folder='+uid;
    }
    location.href = uri;
    return false;
}

/*
 * ***
 * Create a new folder
 * ***
 */
/*
 * Fetches folder data and prepares for folder creation
 */
function lixuz_DD_NewItem(junk,parentObj)
{
    showPI(i18n.get('Loading folder data ...'));
    var myparent = 'root';
    if(parentObj != 'root')
    {
        parentObj = parentObj.parentNode;
        myparent = parentObj.getAttribute('uid');
        if (!myparent)
        {
            return;
        }
    }
    JSON_Request('/admin/services/folderList?showRoot=true&selected='+encodeURIComponent(myparent),lixuz_DD_NewFolderItem,null);
    return false;
}
/*
 * Shows the 'new folder' dialog
 */
function lixuz_DD_NewFolderItem(form)
{
    destroyPI();
    var html = '<b>'+i18n.get('Parent folder')+': <select id="newFolder_parent" name="newFolder_parent" style="width:470px;">';
    html = html+form.tree;
    html = html+'</select><br /><br />';
    html = html + '<b>'+i18n.get('Folder name')+': <input id="newFolder_name" name="name" size="45" type="text" value="" /><br />';
    var buttons = {};
    buttons[i18n.get('Create')] = function ()
    {
        lixuz_DD_CreateNewFolder();
        lixuz_DD_DialogBox.destroy();
    };
    try
    {
        if(lixuz_DD_DialogBox && lixuz_DD_DialogBox.hide)
        {
            lixuz_DD_DialogBox.hide();
        }
        lixuz_DD_DialogBox = new dialogBox(html,{title: i18n.get('New folder'), buttons: buttons, minWidth: 500});
    }
    catch(e)
    {
        lzException(e);
    }
}
/*
 * Sends the new folder data to the server
 */
function lixuz_DD_CreateNewFolder()
{
    var name;
    var myparent;
    try
    {
        var name = $('#newFolder_name').val();
        if(name == null || name.length <= 0)
        {
            userMessage(i18n.get('You have to enter a name for the folder'));
            return;
        }
        myparent = $('#newFolder_parent').val();
    }
    catch (e)
    {
        lzException(e);
        return;
    }
    lixuz_DD_DialogBox.hide();
    showPI(i18n.get('Creating folder...')); // Show progress indicator
    JSON_Request(lixuz_DD_URL+'?parent='+encodeURIComponent(myparent)+'&addName='+encodeURIComponent(name), lixuz_DD_NewItemSuccess, lixuz_DD_NewItemFailure);
}
/*
 * All good, new folder created, so we kick off a refresh of the data
 */
function lixuz_DD_NewItemSuccess (reply)
{
    lixuz_DD_RefreshList();
}
/*
 * Something went wrong
 */
function lixuz_DD_NewItemFailure (reply)
{
    //var error = LZ_JSON_GetErrorInfo(reply,false);
    LZ_SaveFailure(reply, i18n.get('Failed to create a new folder'));
}
