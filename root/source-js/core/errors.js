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
 * Lixuz shared error handling code
 *
 * Copyright (C) Portu media & communications
 * All Rights Reserved
 */

function displayErrorBox (title,message)
{
    var $dialog = $('<div/>').appendTo('body');
    $dialog.html(message);
    $dialog.dialog({
        buttons: {
                'Close': function() {
                    $(this).dialog('close');
                }
            },
        title: title,
        modal: true,
        width: 580,
        close: function ()
        {
            try
            {
                $dialog.remove();
            } catch(e) {
                $dialog.empty();
            }
        }
    });
}

/*
 * Get the file and line number that caused the exception if
 * possible. Returns null if it isn't possible.
 */
function getBacktraceFromException (exception)
{
    var fileAndLine = null;

    try
    {
        var line = null,
            file = null;
        // Some browsers use lineNumber, other use line.
        try { line = exception.lineNumber }
        catch(e) { try { line = exception.line } catch(e1) {} };
        try { file = exception.fileName; } catch(e2) {};
        try { file = file.replace(/^http:\/\/[^\/]+/,''); } catch(e2) {};
        if(line != null || file != null)
        {
            if(line == null) { line = '(unknown)'; }
            if(file == null) { file = '(unknown)'; }

            fileAndLine = file+' line '+line;
        }
    } catch(e) { fileAndLine = null; }

    return fileAndLine;
}

function getLzErrInfo (add)
{
    var userAgent = '(unknown)',
        URL = '(unknown)',
        user = '(unknown)',
        lzVer = '',
        OS = '(unknown)';
    // Get the current URL
    try {
        if(document.url)
            URL = document.url;
        else if(document.URL)
            URL = document.URL;
        else if(window.location)
            URL = window.location;
        URL = URL.replace(/&/,'&amp;');
    } catch(e) { lzelog(e); }
    // Get a cleaned version of the user agent string
    try { 
        userAgent = navigator.userAgent;
        if(userAgent.match(/^Mozilla/))
            userAgent = userAgent.replace(/^[^\(]+/,'');
        if($.browser.msie)
        {
            userAgent = userAgent.replace(/^\(\s*(compatible)?\s*;?/,'')
                                 .replace(/\)$/,'')
                                 .replace(/Win[^;]+;/,'')
                                 .replace(/\s*\.NET[^;]+;?\s*/g,'');
        }
        else
        {
            userAgent = userAgent.replace(/^\([^\)]+\)/,'');
        }
        userAgent = userAgent.replace(/;/g,'')
                             .replace(/[^)]+\)/,'')
                             .replace(/\s+/g,' ')
                             .replace(/^\s*/,'');
    } catch(e){ }
    // Try to extract the OS from the user agent string
    try {
        OS = navigator.userAgent;
        if($.browser.msie)
        {
            OS = OS.replace(/.*(Win[^;]+).*/,'$1');
        }
        else
        {
            OS = OS.replace(/^[^\(]+\s*\(/,'');
            var info = OS.split('; ');
            if(info[0] != info[2] && info[2].indexOf(info[0]) == -1)
                OS = info[0]+'/'+info[2];
            else
                OS = info[2];
        }
    } catch(e) { }
    // Get the current Lixuz version
    try { lzVer = $('#lixuz_version').val(); } catch(e) { }
    // Get the current username+user id
    try { user = $('#currentUsername').val(); user = user +'/'+$('#currentUserId').val(); } catch(e) { }
    // Repair userAgent+OS if something went wrong in the earlier functions
    try
    {
        // Reset userAgent if it's empty
        if(userAgent == null || userAgent == '' || !/\S/.match(userAgent))
        {
            userAgent = navigator.userAgent;
        }
        // Set OS to null (supresses output) if it's not a useful value
        if(OS == userAgent || !/\S/.match(OS))
        {
            OS = null;
        }
    } catch(e) { }
    // Generate the actual message string
    var message = '<code>';
    message = message+add;
    message = message+'User&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;: '+user+'<br />';
    message = message+'On page&nbsp;&nbsp;&nbsp;: '+URL+'<br />';
    message = message+'User agent: '+userAgent+'<br />';
    if(OS != null)
        message = message+'OS&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;: '+OS+'<br />';
    message = message+'Lixuz&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;: '+lzVer;
    message = message+'</code>';
    return message;
}

/*
 * Summary: Lixuz javascript exception handler
 * Arguments:
 *  exception: exception object
 *  error: optional error message
 *
 * This will provide some additional information about the nature of the exception
 * and handle giving a generic error message if one isn't supplied.
 */
function lzException(exception,error)
{
    var exceptMsg = '(unknown/missing)';

    // Store exceptions
    if(exception && console && console.log)
    {
        lzStoredExceptions.push(exception);
    }

    var caller = '(unknown)';
    try
    {
        try { caller = exception.lzIntCaller; } catch(e) { caller = '(unknown)'; }
        if(caller === undefined || caller == '(unknown)')
        {
            caller = getCallerName(arguments);
        }

    } catch(e) {}
    try { 
        url = document.url; 
        url = url.replace(/&/,'&amp;');
    } catch(e) { }
    
    var message = '';
    if(error)
    {
        message = error;
    }
    else
    {
        var internal = false;
        try { if(exception.internalLixuzError) { internal = true }; }  catch(e) { }
        if(internal)
        {
            message = "An internal error occurred. This means that some part of your Lixuz instance just had a serious problem. If you were saving some data, that data may not have been saved. Please try again in a few moments. If the problem persists, please supply the Lixuz developers with the information at the bottom of this message.";
        }
        else
        {
            message = "An exception occurred. This means that some part of your Lixuz instance just crashed. Please try again in a few moments. If the problem persists, please supply the Lixuz developers with the information at the bottom of this message.";
        }
    }

    message = message+'<br /><br /><small>';

    if(error)
    {
        message = message+'<i>Error information:</i><br />';
    }

    try { 
        if (exception && exception.message)
        {
            exceptMsg = exception.message;
        }
        else
        {
            if(exception.lzIntCaller)
            {
                exceptMsg = '(exception data missing/null (lzError mode))';
            }
            else if(exception)
            {
                var type = 'unknown';
                try { type = typeof(exception); } catch(e) { }
                if(type == 'object')
                {
                    exceptMsg = '(exception message missing/null (got object))';
                }
                else if(type == 'string')
                {
                    exceptMsg = '(got string exception): '+exception;
                }
                else
                {
                    exceptMsg = '(exception message missing/null (got object of type "'+type+'" - stringifies as:'+exception+'))';
                }
            }
            else
            {
                exceptMsg = '(exception data missing/null)';
            }
        }
        try { if(exceptMsg === undefined || exceptMsg == null || exceptMsg == 'undefined' || exceptMsg == '') { exceptMsg = '(unknown/missing)'; } } catch(e) { }
    } catch (e) { }

    // Don't do anything if it's an lzError exception
    if (/^lzError/.test(exceptMsg))
    {
        return;
    }
    var fileAndLine = getBacktraceFromException(exception),
        extraInfo = '';

    extraInfo = extraInfo+'Exception : '+exceptMsg+"<br />";
    if(fileAndLine != null)
    {
        extraInfo = extraInfo+'At&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;: '+fileAndLine+'<br />';
    }
    extraInfo = extraInfo+'Caught by : '+caller+"<br />";
    if($.browser.ie && /JSON/.match(caller))
    {
        if(lixuz_curr_JSON_URL)
        {
            extraInfo = extraInfo+'JSON URL: '+lixuz_curr_JSON_URL;
        }
    }
    message = message+getLzErrInfo(extraInfo);

    // Try to clean up so that the page can be used in case something
    // has made it impossible to use
    try {
        for(var i = 0; i <= dialogNo; i++)
        {
            var dialog = $('#dialog_no_'+i);
            if (dialog)
            {
                if(dialog.dialog('option','isOpen'))
                {
                    dialog.dialog('option','modal',false);
                }
                else
                {
                    dialog.css({
                        'visibility':'hidden',
                        'display':'none'
                    });
                    dialog.empty();
                }
            }
        }
    } catch(e) { }

    // Ensure that any running progress indicator doesn't overwrite our dialog window
    try { PI_noSoonMessage = PI_currProgress; } catch(e) { }

    message = message +'</small>';

    if(fileAndLine != null)
    {
        lzelog(exception,true);
    }
    else
    {
        lzlog('Exception: "'+exceptMsg+'" caught by '+caller);
    }
    // Display our message
    try
    {
        displayErrorBox('Fatal error',message);
    }
    catch(e)
    {
        try
        {
            message = message.replace(/<br \/>/g,"\n");
            message = message.replace(/&nbsp;/g,' ');
            message = message.replace(/<[^>]+>/g,'');
        } catch(e) {}
        alert(message);
    }
}

/*
 * Summary: Lixuz javascript exception logger
 * Arguments: exception: exception object
 */
function lzelog (exception)
{
    try
    {
        var backtrace = null,
            funcname = null;
        try
        {
            backtrace = getBacktraceFromException(exception);
        } catch(e) { }
        try 
        {
            funcname = getCallerName(exception.stack);
        } catch(e) { }
        var message = exception.message;
        var output = '"'+message+'"';
        if(funcname != null)
        {
            output = output + ' in '+funcname;
        }
        if(backtrace != null)
        {
            output = output + ' at '+backtrace;
        }
        if(progIndicatorDisplayed && arguments.length != 2)
        {
            PI_exceptions.push(output);
        }
        lzlog('Exception: '+output);
        if (backtrace.stack)
        {
            lzlog("Stack trace of above exception:\n"+backtrace.stack);
        }
    } catch(e) { }
}

/*
 * Summary: Provide an exception dialog for non-exception errors
 *
 * This function lets you create the lzException() dialog, without
 * having to throw and catch an error.
 *
 * Arguments:
 *  error (required) = The error that will show up as the exception message
 *  userError = The user-facing error message, this is the same as the error
 *      parameter to lzException. It's optional. An autogenerated one will
 *      be shown if this is not supplied.
 *  fatal = bool, if true then lzError will throw() an exception matching
 *      /^lzError/ (this exception is ignored by lzException().
 */
function lzError (error,userError,fatal)
{
    var exception = {};
    exception.message = error;
    exception.internalLixuzError = true;
    if(arguments && arguments.length && arguments[3])
    {
        exception.lzIntCaller = arguments[3];
    }
    lzException(exception,userError);
    if(fatal === true)
    {
        throw({'message':'lzErrorException '+error});
    }
}

try
{
    window.onerror = function(msg, file, line)
    {
        if(file && line)
            msg = msg +' at '+file+':'+line;
        lzlog(arguments);
        lzlog(this);
        if (! (msg instanceof String))
        {
            lzlog(msg);
            return;
        }
        lzError(msg,null,false,'(onerror)');
        return false;
    };
} catch(e) {}
