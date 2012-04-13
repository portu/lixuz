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
 * Submit active/inactive status to the server
 */
function submitRSSImportSettings ()
{
    try {
        var items = $('#rssItems').val().split(/,/);
        if(items.length == 0)
        {
            userMessage(i18n.get('Nothing to submit'));
            return;
        }
        var submit = {};
        for(var i = 0; i < items.length; i++)
        {
            var entry = items[i];
            var item = $('#rss_art_'+entry+'_checkbox');
            if (!item[0])
            {
                lzError('rss_art_'+entry+'_checkbox is null (i='+i+' - first='+first+')',null,true);
            }
            if(item.is(':checked'))
            {
                submit[entry] = 1;
            }
            else
            {
                submit[entry] = 0;
            }
        }
        submit['rssItems'] = $('#rssItems').val();
        submit['rss_submit'] = 1;
        showPI(i18n.get('Saving...'));
        JSON_HashPostRequest(document.URL, submit, submittedRSSImportSettings);
    } catch(e) { lzException(e); }
}

/*
 * Submission succeeded
 */
function submittedRSSImportSettings ()
{
    destroyPI();
}

/*
 * ***
 * Editing
 * ***
 */
var editFormDialog,
    editFormEditor;

/*
 * Fetch information for an entry and run constructRSSEditFormFromData on it
 * if it succeeds
 */
function editRSSEntry (rss_id)
{
    showPI(i18n.get('Retrieveing data...'));
    JSON_Request('/admin/rssimport/?getdata='+rss_id,constructRSSEditFormFromData);
}

/*
 * Create a new entry
 */
function createRSSEntry ()
{
    var data = {};
    data.rss_id = 'new';
    data.title = '';
    data.lead = '';
    data.link = '';
    data.source = '';
    constructRSSEditFormFromData(data);
}

/*
 * Create the edit form and handle saving it
 */
function constructRSSEditFormFromData (data)
{
    try
    {
        destroyPI();

        var html = '<input type="hidden" id="rssedit_id" value="'+data.rss_id+'" />';
        html = html+'<table style="width: 550px;"><tr><td><b>'+i18n.get('Title')+'</b></td><td><input id="rssedit_title" style="width:100%;" type="text" value="'+safe_HTML(data.title)+'" /></td></tr>';
        html = html+'<tr><td colspan="2" width="100%"><b>'+i18n.get('Content')+'</b><br /><textarea style="width:100%;" rows="5" width="100%" id="rsseditor">'+safe_HTML(data.lead)+'</textarea></td></tr>';
        html = html+'<tr><td><b>'+i18n.get('Link')+'</b></td><td><input id="rssedit_link" style="width:100%" type="text" value="'+safe_HTML(data.link)+'" /></td></tr>';
        html = html+'<tr><td><b>'+i18n.get('Source')+'</b></td><td><input id="rssedit_source" style="width:100%" type="text" value="'+safe_HTML(data.source)+'" /></td></tr>';
        html = html+'</table>';
        var buttons = {}
        buttons[i18n.get('Save and close')] = saveRSSItemInfo;
        editFormDialog = new dialogBox(html, {
            buttons: buttons,
            title: i18n.get('Edit RSS entry'),
            width: 600
        }, {
            closeButton: i18n.get('Cancel')
        });
        editorFormEditor = createLixuzRTE('rsseditor');
    }
    catch(e)
    {
        lzException(e);
    }
}

/*
 * Save information
 */
function saveRSSItemInfo ()
{
    try
    {
        showPI(i18n.get('Saving...'));
        var data = getFieldItems(['rssedit_id','rssedit_link','rssedit_source','rssedit_title','rsseditor'], {
                        'rsseditor':'lead',
                        'rssedit_link':'link',
                        'rssedit_source':'source',
                        'rssedit_title':'title',
                        'rssedit_id':'rss_id'
                    });
        data.rssEdit_submit = 1;
        JSON_HashPostRequest('/admin/rssimport', data, saveRSSItemInfo_success);
    }
    catch(e)
    {
        lzException(e);
    }
}

/*
 * Saving succeeded
 */
function saveRSSItemInfo_success ()
{
    destroyPI();
    showPI(i18n.get('Reloading...'));
    window.location.reload();
}

/*
 * ***
 * Deletion
 * ***
 */

var deleteThisEntry;

function deleteRSSEntry (rss_id)
{
    deleteThisEntry = rss_id;
    AuserQuestion(i18n.get('Are you sure you wish to permanently delete this entry?'),'reallyDeleteRSSEntry');
}

/*
 * Submit a deletion request
 */
function reallyDeleteRSSEntry (deleteIt)
{
    if(deleteIt)
    {
        showPI(i18n.get('Deleting...'));
        JSON_Request('/admin/rssimport/?delete='+deleteThisEntry,RSS_deletion_success);
    }
}

/*
 * Deletion suceeded, reload the page
 */
function RSS_deletion_success ()
{
    destroyPI();
    showPI(i18n.get('Reloading...'));
    window.location.reload();
}
