function showTimeTracker(userAction)
{
    destroyMessageBox();
    $('#startBtn').html(i18n.get('Loading...')+'<img src="/static/images/progind.gif" width="24" height="25">');
    JSON_Request('/admin/timetracker/addTimeEntry/'+userAction,startedTime,starttime_failure);
}   

function startedTime(data)
{
    if (data.tt_status == 1)
    {
        $('#tracActive').show();
        $('#tracActive').html(data.current_time);
        $('#startBtn').hide();
    }
    else
    {
        $('#stopBtn').hide();
        $('#tracActive').html("");
        $('#tracActive').hide();
        $('#startBtn').show();
        $('#startBtn').html("<a href='#'  onclick=showTimeTracker('start');>Start</a>");
    }   
}

function starttime_failure (data)
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
        LZ_SaveFailure(data,i18n.get('Failed to start timetracker.'));
    }

}

