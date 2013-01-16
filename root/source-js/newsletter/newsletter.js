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
// This will contain the id of the newsletter to be deleted. We store it here
// because AuserQuestion() is used to process it.
var deleteThisNewsletter,
// This will contain the group editor window widget
    subscriptionGroupEditor,
// Array of recipients
    recipients = [],
// Same as deleteThisNewsletter, but used by editSubscriptionGroups.
    SGE_ID,
// Group editor window widget
    groupEditor,
// Same as deleteThisNewsletter, but used by deleteSubGroup
    deleteThisGroup,
// A hash mapping a group id to group title
    groupMap = {};

/*
 * List actions
 */

// Prompt the user to delete the supplied subscription
function deleteNewsletterSubscription (subscription_id)
{
    deleteThisNewsletter = subscription_id;
    AuserQuestion(i18n.get('Are you sure you wish to cancel this users subscription?'),'deleteNewsletterSubscriptionNow');
}

// Submit a delete request to the server if response is true
function deleteNewsletterSubscriptionNow (response)
{
    if(response)
    {
        showPI(i18n.get('Deleting...'));
        XHR.GET('/admin/newsletter/delete/'+deleteThisNewsletter,subscriptionDeleted);
    }
}

// Subscription request succeeded
function subscriptionDeleted ()
{
    window.location.reload();
}

// Handle changes in the newsletter action dropdown
function newsletterAction (id)
{
    var entry = $('#subscription_action_'+id);
    var val = entry.val();
    entry.val('label');
    if(val == 'delete')
    {
        deleteNewsletterSubscription(id);
    }
    else if(val == 'groupedit')
    {
        editSubscriptionGroups(id);
    }
    else if(val == 'label')
    {
        return;
    }
    else
    {
        lzError('Invalid action in newsletterAction for id '+id+': '+val);
    }
}

// Bring up the subscription group editor on the subscription_id supplied
function editSubscriptionGroups (id)
{
    showPI(i18n.get('Loading group data...'));
    SGE_ID=id;
    XHR.GET('/admin/newsletter/subscriptionGroupEdit/'+id, createSubscriptionGroupEditList);
}

// Generates the subscription group editor on the data supplied (retrieved from the server)
function createSubscriptionGroupEditList (data)
{
    var my_arr = [],
        checked = [];

    for(var i = 0; i < data.groups.length; i++)
    {
        var group = data.groups[i];
        my_arr.push([ group.group_id, group.group_name ]);
        if(group.enabled == 1)
        {
            checked.push(group.group_id);
        }
    }

    var table = createManagedChecklistTable ('subscriptionGroupEditor',['ID','Group'], my_arr);
    var html = '<br /><div style="overflow:auto; height: 75%;">'+table+'</div><br /><br />';
    var buttons = {};
    buttons[i18n.get('Save and close')] = function () {
        saveAndCloseGroupListEditor(SGE_ID);
    };
    subscriptionGroupEditor = new dialogBox(html,{
            modal: true,
            height:340,
            width: 500,
            buttons: buttons
            });
    for(var n = 0; n < checked.length; n++)
    {
        checklistTableSetChecked('subscriptionGroupEditor',checked[n],true);
    }
    destroyPI();
}

// Save and close the group list editor
function saveAndCloseGroupListEditor (id)
{
    showPI(i18n.get('Saving...'));
    var myGroups = getdataFromChecklistTable('subscriptionGroupEditor');
    XHR.GET('/admin/newsletter/subscriptionGroupEdit/'+id+'?groups='+encodeURIComponent(myGroups), saveAndCloseGroupListEditor_success);
}

// Succeeded, destroy it
function saveAndCloseGroupListEditor_success ()
{
    subscriptionGroupEditor.destroy();
    destroyChecklistTable('subscriptionGroupEditor');
    destroyPI();
}

// View a preview of the currently edited manual newsletter
function viewPreview ()
{
    displayThisNewsletter(getFieldData('mail_from'), getFieldData('mail_subject'), getFieldData('mail_editor'), $('#mail_type').val());
}

// Display a preview of a newsletter using the data supplied
function displayThisNewsletter(from,subject,body,format)
{
    var HTML = '<div style="width: 500px; height: 300px;"><code>'+i18n.get('From')+': '+from+'</code><br />';
    HTML = HTML+'<code>'+i18n.get('Subject')+': '+subject+'</code><br /><hr />';
    if(format == 'text' || format == 'TEXT')
    {
        HTML = HTML +'<pre>'+body+'</pre>';
    }
    else
    {
        HTML = HTML +'<div>'+body+'</div>';
    }
    HTML = HTML +'</div>';
    quickDialog(i18n.get('Message'),HTML);
}

// Retrieve the list of sent+saved newsletters from the server
function listSentNewsletters ()
{
    showPI(i18n.get('Loading list...'));
    XHR.GET('/admin/newsletter/sentPreviously?wants=list',showSentNewsletterList);
}

// Show the list of sent+saved newsletters retrieved by listSentNewsletters
function showSentNewsletterList (data)
{
    if(data.content.length == 0)
    {
        userMessage(i18n.get('There are no saved newsletters.'));
        destroyPI();
        return;
    }
    var table = createTableFromHashData([ i18n.get('Subject'), i18n.get('Sent at'),i18n.get('Action') ],data.content,['subject','sent_at','action'], { 'subject': { 'source':'saved_id','action':'viewSavedNewsletter' },'action': { 'source':'saved_id','action':'sendSavedNewsletter' } });
    quickDialog(i18n.get('Select newsletter'),table);
    destroyPI();
}

//Retive and view the single newsletter in send window.
function sendSavedNewsletter (id)
{
    location.href = '/admin/newsletter/send?nid='+id;
}    

// Retrieve a single newsletter from the server
function viewSavedNewsletter (id)
{
    showPI(i18n.get('Loading message...'));
    destroyMessageBox();
    XHR.GET('/admin/newsletter/sentPreviously?wants='+id,viewThisSavedNewsletter);
}
// View the retrieved newsletter
function viewThisSavedNewsletter (data)
{
    displayThisNewsletter(data.from, data.subject, data.body, data.format);
    destroyPI();
}

/*
 * Manual newsletter actions
 */

// Submit the newsletter form to the server
function submitManualNewsletter ()
{
    if (! recipients || recipients.length == 0)
    {
        userMessage(i18n.get('You need to add some recipients first'));
        return;
    }
    if(getFieldData('mail_subject') == "")
    {
        userMessage(i18n.get('You need to enter a subject'));
        return;
    }
    if(getFieldData('mail_editor') == '')
    {
        userMessage(i18n.get('The message can not be empty'));
        return;
    }
    if(getFieldData('mail_from') == '')
    {
        userMessage(i18n.get('The from e-mail can not be empty'));
        return;
    }
    var data = '';
    for(var i = 0; i < recipients.length; i++)
    {
        var entry = recipients[i];
        if(entry == '' || entry == null)
        {
            continue;
        }
        data = data + 'recipient='+encodeURIComponent(entry)+'&';
    }
    data = data + 'message='+encodeURIComponent(getFieldData('mail_editor'))+'&';
    data = data + 'subject='+encodeURIComponent(getFieldData('mail_subject'))+'&';
    data = data + 'type='+encodeURIComponent(getFieldData('mail_type'))+'&';
    data = data + 'from='+encodeURIComponent(getFieldData('mail_from'))+'&';
    showPI(i18n.get('Sending...'));
    // TODO: Add error handler
    XHR.Form.POST('/admin/newsletter/submitManual',data,manualNewsletterSent);
}

// The newsletter was successfully sent, let the user know
function manualNewsletterSent ()
{
    location.href = '/admin/newsletter';
}

// Handle onchange for the newsletter format (text/html)
function manualNewsletterFormatChange ()
{
    var t = $('#mail_type').val();
    if(t == 'text')
    {
        try
        {
            var editor = lixuzRTE.get('mail_editor');
            editor.hide();
            editor.destroy();
            editor = null;
        } catch (e) { }
    }
    else
    {
        lixuzRTE.init('mail_editor');
    }
}

// Create the dialog to add recipients from the DB
function addManualRecipientsFromDB ()
{
    var buttons = {};
    buttons[i18n.get('Add recipients')] = LZ_addRecipientsFromDB_OK;
    newFilteringObjectSelector(null,'/admin/newsletter?','newsletter',"/admin/services/jsFilter?source=newsletter",buttons,null,i18n.get('Add recipients'));
}

// Successfully added recipients from the DB
function LZ_addRecipientsFromDB_OK ()
{
    destroyObjectSelector();
    var elements = destroyChecklistTable('genericList');
    addTheseRecipients(elements);
}

// Create the dialog to manually enter recipients
function addManualRecipientsFromEntry ()
{
    userPrompt(i18n.get('Enter e-mail addresses here, separated by commas.'),'addRecipientsFromCommaString',i18n.get('Add'));
}

// Add recipients from str, where they are separated by commas
function addRecipientsFromCommaString (str)
{
    if(str == null || str == '')
    {
        return;
    }
    var entries = str.split(/,/);
    addTheseRecipients(entries);
}

// Add the recipients in the array list to the recipient list for this newsletter.
// This function also locates and removes dupes.
function addTheseRecipients (list)
{
    for(var i = 0; i < list.length; i++)
    {
        var entry = list[i];
        if(entry == null || entry == '')
        {
            continue;
        }
        entry = entry.replace(/\s+/g,'');
        recipients.push(entry);
    }

    var found = {},
        newRec = [],
        maillist = '';
    for(var n = 0; n < recipients.length; n++)
    {
        if(recipients[n] == null || recipients[n] == '' || found[recipients[n]])
        {
            continue;
        }
        var title = recipients[n];
        if (/^group_\d+$/.test(title))
        {
            title = i18n.get('Group:')+' '+groupMap[title];
        }
        maillist = maillist + title +' <a href="#" onclick="removeThisRecipient('+n+'); return false;">'+i18n.get('remove')+'</a><br />';
        newRec.push(recipients[n]);
        found[recipients[n]] = true;
    }
    recipients = newRec;
    if(recipients.length == 0)
    {
        maillist = '<i>(no recipients added)</i>';
    }
    $('#mail_recipients').html(maillist);
}

// Remove a recipient from the recipient list
function removeThisRecipient (recipientId)
{
    recipients[recipientId] = null;
    addTheseRecipients([]);
}

// Add recipients to the current manual newsletter from a group
function addManualRecipientsFromGroup ()
{
    showPI(i18n.get('Loading group list...'));
    XHR.GET('/admin/newsletter/groupList',finalize_groupAddWin);
}

// Create the group adding window using the data supplied
function finalize_groupAddWin (data)
{
    destroyPI();
    var html = '<ul>';
    for(var i = 0; i < data.groups.length; i++)
    {
        var name = data.groups[i].group_name,
            gid = data.groups[i].group_id;
        if(name == '')
        {
            name = '&nbsp;&nbsp;';
        }
        html = html +'<li><a href="#" id="groupAdd_'+gid+'" onclick="addGroupRecipient('+gid+'); return false;">'+name+'</a></li>';
    }
    html = html + '</ul>';
    quickDialog(i18n.get('Select the group(s) to add'),html);
}

// Add the group id supplied to the recipients list
function addGroupRecipient (gid)
{
    groupMap['group_'+gid] = $('#groupAdd_'+gid).html();
    addTheseRecipients(['group_'+gid]);
}

/*
 * Group editing
 */

// Retrieve the grup list from the server
function groupEditPrompt ()
{
    showPI(i18n.get('Loading group list...'));
    XHR.GET('/admin/newsletter/groupList',finalizeGroupEditPrompt);
}

// Create the group list window using the data retrieved from the server
function finalizeGroupEditPrompt (data)
{
    destroyPI();
    var html = '<ul>';
    for(var i = 0; i < data.groups.length; i++)
    {
        var name = data.groups[i].group_name;
        if(name == '')
        {
            name = '&nbsp;&nbsp;';
        }
        html = html +'<li><a href="#" onclick="editGroup('+data.groups[i].group_id+'); return false;">'+name+'</a></li>';
    }
    html = html + '</ul>';
    quickDialog(i18n.get('Select the group to edit'),html,i18n.get('Close'));
}

// Retrieve information about group_id
function editGroup (groupid)
{
    destroyMessageBox();
    showPI(i18n.get('Loading group information...'));
    XHR.GET('/admin/newsletter/groupInfo/'+groupid,groupEditorWindow);
}

// Actually create the group editing window
function groupEditorWindow (data)
{
    if(data == null)
    {
        data =  { 'group_name': '', 'group_id':'new', 'internal':false };
    }
    destroyPI();
    var internalChecked = '';
    if(data.internal == true || data.internal == 1)
    {
        internalChecked = ' checked="checked"';
    }
    var html = '<input type="hidden" id="group_id" value="'+data.group_id+'" />';
    html = html + '<table><tr><td>'+i18n.get('Group name')+':</td><td><input type="text" id="group_name" value="'+data.group_name+'" /></td></tr>';
    html = html + '<tr><td colspan="2"><input type="checkbox" id="group_internal"'+internalChecked+' /> '+i18n.get('Internal only')+'</td></tr></table>';
    var buttons = {};
    buttons[i18n.get('Save and close')] = function () { saveAndCloseGroupEditor() };
    if(data.group_id != 'new')
    {
        buttons[i18n.get('Delete group')] = function () { deleteSubGroup(data.group_id); };
    }
    groupEditor = new dialogBox(html,{
            buttons: buttons,
            title: i18n.get('Newsletter group editor')
            });
}

// Delete a subscription group
function deleteSubGroup (group_id)
{
    deleteThisGroup = group_id;
    AuserQuestion(i18n.get('Are you sure you wish to delete this group?'),'deleteSubGroupNow');
}

// Submit deletion request
function deleteSubGroupNow (reply)
{
    if(reply)
    {
        showPI(i18n.get('Deleting...'));
        XHR.GET('/admin/newsletter/groupDelete/'+deleteThisGroup,groupEditorSaveSuccess);
    }
}

// Submit group editor data to the server
function saveAndCloseGroupEditor ()
{
    var submit = '/admin/newsletter/groupSave?group_id='+encodeURIComponent(getFieldData('group_id'))+'&group_name='+encodeURIComponent(getFieldData('group_name'))+'&group_internal='+encodeURIComponent(getFieldData('group_internal'));
    showPI(i18n.get('Saving...'));
    XHR.GET(submit,groupEditorSaveSuccess);
}

// Group editor data successfully saved
function groupEditorSaveSuccess ()
{
    groupEditor.destroy();
    destroyPI();
}

// Actually create the Subscriber editing window
function subscriberWindow(data)
{
    if(data == null)
    {
        data =  { 'email': '','name': '','format': '','interval': '','subscriber_id':'new'};
    }
    destroyPI();
    var html = '<input type="hidden" id="subsciber_id" value="'+data.subscriber_id+'" />';
    html = html + '<table><tr><td>'+i18n.get('Email')+':</td><td><input type="text" id="email" value="'+data.email+'" /></td></tr>';
    html = html + '<tr><td>'+i18n.get('Name')+':</td><td><input type="text" id="name" value="'+data.name+'" /></td></tr>';
    html = html + '<tr><td>'+i18n.get('Format')+':</td><td><input type="radio" id="format" checked="checked" value="text" name="format">'+i18n.get('Text')+'<input type="radio" value="html" id="format" name="format">'+i18n.get('HTML')+'</td></tr>';
    html = html + '<tr><td>'+i18n.get('Interval')+':</td><td><input type="radio" value="day" id="interval" name="interval">'+i18n.get('Daily')+' <input type="radio" checked="checked" value="week" id="interval"  name="interval">'+i18n.get('Weekly')+'<input type="radio" value="month" id="interval" name="interval">'+i18n.get('Monthly')+'<input type="radio" value="none" id="interval" name="interval">'+i18n.get('None')+' </td></tr></table>';

    var buttons = {};
    buttons[i18n.get('Save and close')] = function () { saveAndCloseSubscriberEditor() };

    subscriberEditor = new dialogBox(html,{
        buttons: buttons,
        title: i18n.get('Add Subscriber')
    });
    
    if (data.format != "")
    {
        $("[name=format]").filter("[value="+data.format+"]").prop("checked",true);
    }

    if (data.interval != "")
    {
        $("[name=interval]").filter("[value="+data.interval+"]").prop("checked",true);
    }
}

// Submit Subscriber editor data to the server
function saveAndCloseSubscriberEditor ()
{
  var getinterval = $('input[name=interval]:checked').val();
  var getformat = $('input[name=format]:checked').val();

    var submit = '/admin/newsletter/subscriberSave?subsciber_id='+encodeURIComponent(getFieldData('subsciber_id'))+'&email='+encodeURIComponent(getFieldData('email'))+'&name='+encodeURIComponent(getFieldData('name'))+'&format='+encodeURIComponent(getformat)+'&interval='+encodeURIComponent(getinterval);
    showPI(i18n.get('Saving...'));
    XHR.GET(submit,subscriberEditorSaveSuccess);
}

// Subscriber data successfully saved
function subscriberEditorSaveSuccess ()
{
    subscriberEditor.destroy();
    destroyPI();
    window.location.reload();
}

// Retrive subscriber data for edit using subscriber id
function editSubscriber (subscriberid)
{
    destroyMessageBox();
    showPI(i18n.get('Loading subscriber information...'));
    XHR.GET('/admin/newsletter/subscriberInfo/'+subscriberid,subscriberWindow);
}

//show window for import subscriber
function importSubscriberWindow ()
{
    var html = '<form action="/admin/newsletter/importsubscriber" name="importSubscriber" id="importSubscriber" method="post" enctype="multipart/form-data">';
    html = html +'<table><tr><td colspan="2"><div style="overflow:auto; height: 75%;" id="LzGroupList"></div></td></tr>';

    $.get('/admin/newsletter/groupList', function (data)
    {
        var my_arr = [],
        checked = [];
        var table;
        table = '<table>';

        for(var i = 0; i < data.groups.length; i++)
        {
             var name = data.groups[i].group_name,
             gid = data.groups[i].group_id;
             if(name == '')
             {
                 name = '&nbsp;&nbsp;';
             }
             table = table +'<tr><td><input type="checkbox" name="chk_bk" id="chk_'+gid+'" value="'+gid+'"/></td><td>'+name+'</td></tr>';
         }
         table = table+'</table>';
         $('#LzGroupList').html(table);
   })
    html = html + '<tr><td>'+i18n.get('Import CSV')+':</td><td><input type="file" id="impsub" name="impsub" /></td></tr>';
    html = html + '</table></form>';
    var buttons = {};
    buttons[i18n.get('Upload and close')] = function () { $('form#importSubscriber').submit(); };

    subscriberEditor = new dialogBox(html,{
        buttons: buttons,
        title: i18n.get('Import Subscribers')
    });
}
