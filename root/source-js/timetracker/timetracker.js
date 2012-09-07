/*
 *  LIXUZ content management system
 *  Copyright (C) Utrop A/S Portu media & Communications 2008-2011
 * 
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as
 *  published by the Free Software Foundation, either version 3 of the
 *  License, or (at your option) any later version.
 *  
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 * 
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 * 
 */

var deleteThisEntry;
// entryting mannually entry editing window
function entryEditorWindow (data)
{
    if(data == null)
    {
        data =  { 'time_start': '','time_end': '','ip_start': '','ip_end': '','subject': '','comment': 'dummy','timeentry_id':'new'};
        var ptitle  = i18n.get("Add time entry");
    }
    else
    {
        var ptitle = i18n.get( "View / edit time entry");
    }
    destroyPI();
    var html = '<input type="hidden" id="timeentry_id" value="'+data.timeentry_id+'" />';
    html = html + '<table><tr><td colspan="2"><div id="entryError"></div></td></tr>';
    html = html + '<tr><td>'+i18n.get('From')+':</td><td><input type="text" id="time_start" name="time_start" value="'+data.time_start+'" /><a href="#" id="time_start_triggerButton"><img src="/static/images/calendar.png"></a></td></tr>';
    html = html + '<tr><td>'+i18n.get('To')+':</td><td><input type="text" id="time_end" name="time_end"  value="'+data.time_end+'" /><a href="#" id="time_end_triggerButton"><img src="/static/images/calendar.png"></a></td></tr>';
    if (data.ip_start != "")
    {
        html = html + '<tr><td>'+i18n.get('IP In')+':</td><td>'+data.ip_start+'</td></tr>';
    }
    if (data.ip_end != "")
    {
        html = html + '<tr><td>'+i18n.get('IP Out')+':</td><td>'+data.ip_end+'</td></tr>';
    }
    
    if (/^ *[0-9]+ *$/.test(data.timeentry_id)) 
    {
        html = html + '<tr><td colspan="2"><b>'+i18n.get('Comments')+'</b></td></tr>';
        html = html + '<tr><td colspan="2"><div id="TimetrackerCommentsContainer"></div></td></tr>';

        $.get('/admin/timetracker/commentlist/'+data.timeentry_id, function (data)
        {
            $('#TimetrackerCommentsContainer').html(data);
        });
    }

    html = html + '<tr><td>'+i18n.get('Subject')+':</td><td><input type="text" id="subject" value="" /></td></tr>';
    html = html + '<tr><td>'+i18n.get('Comment')+':</td><td><textarea cols="30" rows="3" id="comment" name="comment"></textarea></td></tr>';

    var buttons = {};
    buttons[i18n.get('Save and close')] = function () { saveAndCloseEntryEditor(data) };

    entryEditor = new dialogBox(html,{
            buttons: buttons,
            title: ptitle
        });

    /* Force z-index for calendars here to be huge so that they don't appear
     * behind the dialog */
    $('<style />').appendTo('head').text('.calendar { z-index:999999; }');

    /*
     * Initialize calendars
     */
    Calendar.setup({
        inputField  : 'time_start',
        ifFormat    : "%d.%m.%Y %H:%M",
        showsTime   : true,
        timeFormat  : 24,
        button      : "time_start_triggerButton",
        singleClick : true,
        step        : 1
    });
    Calendar.setup({
        inputField  : "time_end",
        ifFormat    : "%d.%m.%Y %H:%M",
        showsTime   : true,
        timeFormat  : 24,
        button      : "time_end_triggerButton",
        singleClick : true,
        step        : 1
    });
}

function validateForm()
{
    var pstStartDate =  $('#time_start').val();
    var pstEndDate = $('#time_end').val();
    datereg =  /^\s*\d+\.\d+\.\d\d\d\d\s+\d\d?\:\d\d?\s*$/;

    if (pstStartDate == '' || !pstStartDate.match(datereg))
    {
        $('#entryError').html('Invalid data for start date');
        return false;
    }
    if (pstEndDate =='' || !pstEndDate.match(datereg))
    {   $('#entryError').html('Invalid data for end date');
        return false;
    }

    var pstStartDateFormat = pstStartDate.replace(/\./g,'/');
    var pstEndDateFormat = pstEndDate.replace(/\./g,'/');
    if (new Date(pstStartDateFormat).getTime() > new Date(pstEndDateFormat).getTime())
    {
        $('#entryError').html('Start date should be less than end date.');
        return false;
    }

   return true;

}

// Submit entry editor data to the server
function saveAndCloseEntryEditor (data) 
{
    data['subject'] = $('#subject').val();
    data['comment'] = $('#comment').val();
    data['time_start'] = $('#time_start').val();
    data['time_end'] = $('#time_end').val();

    if (validateForm())
    {
        showPI(i18n.get('Saving...'));
        XHR.Form.POST('/admin/timetracker/entrySave',data,timeTracker_success,timeTracker_failure);
    }
}

// called when successfull add or edit action on time entry.
function timeTracker_success ()
{
    window.location.reload();
}

// called when failure add or edit action on time entry.
function timeTracker_failure (data)
{
    var errorCode = LZ_JSON_GetErrorInfo(data,null);
    if(errorCode == 'INVALID_TIME_ID')
    {
        userMessage(i18n.get('An error occurred with the request that was submitted.'));
    }
    else if(errorCode == 'ACCESS_DENIED')
    {
        userMessage(i18n.get('You do not have permission to change any of the data.'));
    }
    else
    {
        LZ_SaveFailure(data,i18n.get('Failed to submit time entry data.'));
    }

    destroyPI();
}

// Entry data saved successfuly
function entryEditorSaveSuccess ()
{
    entryEditor.destroy();
    destroyPI();
    window.location.reload();
}

// Retrive time entry information from server
function editTimeEntry (timeentryid)
{
    destroyMessageBox();
    showPI(i18n.get('Loading time entry information...'));
    JSON_Request('/admin/timetracker/timeentryInfo/'+timeentryid,entryEditorWindow);
}

// Initial deletion function
function deleteTimeEntry (timeentry_id)
{
    deleteThisEntry = timeentry_id;
    AuserQuestion(i18n.get('Are you sure you wish to delete this time entry?'),'deleteTimeEntryNow');
}

// Actual deletion function
function deleteTimeEntryNow (response)
{
    if(response)
    {
        showPI(i18n.get('Deleting...'));
        JSON_Request('/admin/timetracker/deletetimeEntry/'+deleteThisEntry,timeEntryDeleted_success, timeEntryDeleted_failure);
    }
}

// called when time entry deleted successfully
function timeEntryDeleted_success (reply)
{
    userMessage(i18n.get('Time entry deleted.'));
    window.location.reload();
}

function timeEntryDeleted_failure (reply)
{
    var error = LZ_JSON_GetErrorInfo(reply,null);
    destroyPI();
    userMessage(i18n.get('Failed to delete: ')+error);
}

//generate PDF format report.
function generatePdfReport()
{
    var url = location.href;
    url = url.replace(/#(.*)/,'');
    if (url.indexOf('?') == -1)
    {
        url = url + '?';
    }
    url = url + '&';
    url = url.replace(/&+/,'&');
    url = url + 'reports=yes';
    window.open(url);
}

