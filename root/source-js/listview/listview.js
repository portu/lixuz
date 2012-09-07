//initial function for time entry preview
function previewTimeEntry(tid)
{
    destroyMessageBox();
    showPI(i18n.get('Loading time entry information...'));
    XHR.GET('/admin/timetracker/timeentryInfo/'+tid,previewWindow);
}

// open a popup and preview the time entry information.
function previewWindow(data)
{
    var ptitle = i18n.get( "Preview time entry");
    destroyPI();
    html = '<table>';
    html = html + '<tr><td>'+i18n.get('From')+':</td><td>'+data.time_start+'</td></tr>';
    html = html + '<tr><td>'+i18n.get('To')+':</td><td>'+data.time_end+'</td></tr>';
    html = html + '<tr><td>'+i18n.get('IP In')+':</td><td>'+data.ip_start+'</td></tr>';
    html = html + '<tr><td>'+i18n.get('IP Out')+':</td><td>'+data.ip_end+'</td></tr>';

    if (data.subject != "")
    {
        html = html + '<tr><td colspan="2"><b>'+i18n.get('Comments')+'</b></td></tr>';
        html = html + '<tr><td colspan="2"><div id="TimetrackerCommentsContainer"></div></td></tr>';

        $.get('/admin/timetracker/commentlist/'+data.timeentry_id, function (data)
        {
            $('#TimetrackerCommentsContainer').html(data);
        });
    }
    html = html + '</table>';

    var buttons = {};
    buttons[i18n.get('close')] = function () { closeEntryEditor() };

    entryEditor = new dialogBox(html,{
        buttons: buttons,
        title: ptitle
    });

}

// Close the preview time entry popup.
function closeEntryEditor()
{
    entryEditor.destroy();
    destroyPI();
}

//generate PDF format report of time entry list view. 
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

