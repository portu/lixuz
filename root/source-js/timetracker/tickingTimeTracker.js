function showTimeTracker(userAction)
{
    destroyMessageBox();
    $('#startBtn').html(i18n.get('Loading...')+'<img src="/static/images/progind.gif" width="24" height="25">');
    XHR.GET('/admin/timetracker/addTimeEntry/'+userAction,startedTime,starttime_failure);
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

function timetrackerIsRunning ()
{
    return $('#tracActive').is(':visible') || $('#stopBtn').is(':visible');
}

function wiredUpEvents()
{
    var validNavigation= false;
    window.onbeforeunload = function(e)
    {
        if (!validNavigation && timetrackerIsRunning())
        {
            if (!e) e = window.event;
            e.cancelBubble = true;
            e.returnValue = i18n.get('The timetracker will keep running even after you close Lixuz. If you don\'t want this, please stay on the page and stop it before proceeding');
            if (e.stopPropagation)
            {
                e.stopPropagation();
                e.preventDefault();
            }
            return i18n.get('The timetracker will keep running even after you close Lixuz. If you don\'t want this, please stay on the page and stop it before proceeding');
        }
    }

    $(document).bind('keypress',function(e)
    {
        if (e.keyCode == 116)
        {
            validNavigation = true;
        }
    });

    $(document).bind('keydown',function(e){
        if (e.keyCode == 116)
        {
            validNavigation = true;
        }
    })

    $("a").bind('click',function()
    {
        validNavigation=true;
    });

    $("form").bind('submit', function () 
    {
        validNavigation=true;
    });

    $("input[type=submit]").bind('click', function()
    {
        validNavigation=true;
    });

    $("input[type=button]").bind('click', function()
    {
        validNavigation=true;
    });
}

$(document).ready(function()
{
    wiredUpEvents();

    $.subscribe('/polling/getPayload',function(payload)
    {
        payload.timetrackerRunning = timetrackerIsRunning();
    });
});

function timetrackerReminder ()
{
    $.get('/admin/timetracker/checkTimeTrackerStatus',currentstatusTimetracker);
}

function currentstatusTimetracker (data)
{
    if (data.tt_status != 1)
    {   
        XuserQuestion(
            i18n.get('Would you like to start the timetracker?'),
            i18n.get('Start timetracker?'), function()
        {
            console.log('started');
            showTimeTracker('start');
        });
    }   
}
