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

var validNavigation= false;

function wiredUpEvents()
{
    window.onbeforeunload = function(e)
    {
        if(jstimetrackerStatus == 1)
        {
            if (!validNavigation)
            {
                if (!e) e = window.event;
                e.cancelBubble = true;
                e.returnValue = i18n.get('Timetracker is still on. Do you want to stop it?');
                if (e.stopPropagation)
                {
                    e.stopPropagation();
                    e.preventDefault();
                }
                return i18n.get('Timetracker is still on . Do you want stop it?');
            }
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
});
