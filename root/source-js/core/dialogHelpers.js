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
 * Copyright (C) Portu media & communications
 * All Rights Reserved
 */

var progIndicatorDisplayed = false,
    progressDialog = null,
    PI_currProgress = 0,
    PI_noSoonMessage = null,
    PI_currMessage = '',
    showingMessageBox = false,
    queuedMessages = [],
    prevMessage = null,
    PI_lastCaller = null,
    PI_exceptions = [];

/*
 * *************
 * Dialog helpers
 * *************
 */

/* **
 * Modal progress indicator dialog
 * **
 */

/*
 * Function called when a progress indicator has been shown for too long
 */
function PI_TooLong(iter,num)
{
    if (!progIndicatorDisplayed || num != PI_currProgress || !progressDialog || iter > 2)
    {
        return;
    }
    if(iter == 2)
    {
        var str = i18n.get('The operation has timed out. This is caused by an unknown error that occurred while performing this operation. Please try again. If the problem persists, contact your system administrator with the information at the bottom of this message.'),
            techStr = '';
        if (PI_lastCaller != null)
        {
            techStr = 'PI creator: '+PI_lastCaller+'<br/>';
        }
        try
        {
            if(PI_exceptions && PI_exceptions.length > 0)
            {
                techStr = techStr + 'Exceptions: <br/>';
                techStr = techStr + PI_exceptions.join('<br/>');
            }
        } catch (e) { }
        if(techStr != '')
        {
            str = str+'<br/><br/><small>'+getLzErrInfo(techStr)+'</small>';
        }
        destroyPI();
        quickDialog('Error',str);
    }
    else
    {
        if(PI_noSoonMessage != null && PI_noSoonMessage == PI_currProgress)
        {
            setTimeout('PI_TooLong(2,'+num+');',40000);
            return;
        }
        setTimeout('PI_TooLong(2,'+num+');',40000);
        showPI(PI_currMessage,true,i18n.get('Done any second now...'));
    }
}

/*
 * Summary: Display a progress indicator, optionally with a message supplied.
 * Usage: showPI(message?, forceDisplay?);
 * 
 * message can be omitted, if it is then it will use a default 'Please
 *   wait...' message.
 *
 * forceDisplay forces it to redraw the progression indicator, even if one
 * already exists. You generally don't need this
 */
function showPI ()
{
    // Full internal parameter list:
    // [0] = String, message
    var message = arguments[0],
    // [1] = Bool, force message display? = false
        forceDisplay = arguments[1],
    // [2] = String, secondary message, ie. called by 'toolong'
        secondaryMessage = arguments[2],
    // [3] = caller, this is supplied by the OO wrapper
        caller = arguments[3];

    if(progIndicatorDisplayed && !forceDisplay)
    {
        return;
    }
    try
    {
        if(!secondaryMessage && !caller)
        {
            caller = getCallerName(arguments);
        }
        if(caller)
            PI_lastCaller = caller;
    } catch(e) { }
    if(arguments.length < 2) { PI_exceptions = []; };
    progIndicatorDisplayed = true;

    if(!(arguments.length >= 2 && arguments[1]))
    {
        PI_currProgress++;
        setTimeout('PI_TooLong(1,'+PI_currProgress+');',15000);
    }
    else
    {
        //progressDialog.hide();
    }
    if(message)
    {
        message = arguments[0];
    }
    else
    {
        message = i18n.get('Please wait...');
    }
    PI_currMessage = message;
    var body = '<br /><br /><center><table border="0"><tr><td style="vertical-align:middle;padding-right: 5px;">'+$('#progInd').html()+'</td><td style="vertical-align:middle">'+message+'</td></tr></table>';
    if(secondaryMessage)
        body = body+'<i>'+secondaryMessage+'</i>';
    body = body+'</center><br />';
    $('#progressWrapper').html(body);
    progressDialog = $('#progressWrapper').dialog(
        {
            draggable: false,
            resizable: false,
            hide: 'explode',
            modal: true,
            zIndex: 9999,
            closeOnEscape: false,
            // Hides the close button
            open: function () { $(this).parent().children().children('.ui-dialog-titlebar-close').hide(); }
        }
    );
}

/*
 * Summary: Destroy (hide) the progression indicator
 * Usage: destroyPI();
 */
function destroyPI ()
{
    if(progIndicatorDisplayed)
    {
        $('#progressWrapper').dialog('close');
        progIndicatorDisplayed = false;
        PI_lastCaller = null;
    }
}

/* **
 * Wrappers for user input/user messaging
 * **
 */

/*
 * This is pretty much the same as confirm() - but wrapped
 * so that we can replace it with another solution later.
 */
function userQuestion (content)
{
    if(confirm(content))
    {
        return true;
    }
    return false;
}

/*
 * This works like confirm(), except that it displays a pretty on-site dialog
 * and works asynchroniously.
 * functionName is the NAME of the function you wish to be called when this dialog
 * is closed. The function will reciveve a single parameter, boolean. true if the user
 * clicked yes, false if no.
 *
 * functionName must be supplied without ()
 */
function AuserQuestion(content, functionName, title)
{
    var buttons = {};
    buttons[i18n.get('No')] = closeDialogOn(function () {
        eval(functionName+'(false)');
    });
    buttons[i18n.get('Yes')] = closeDialogOn(function () {
        eval(functionName+'(true)');
    });
    showOrQueueMessage(content,title,buttons);
    return;
}

/*
 * Same as AuserQuestion, but takes functions instead of strings:
 * content = The question
 * title = Window title (can be null)
 * onYes = Function to run on yes
 * onNo  = Function to be run on no (can be null)
 */
function XuserQuestion(content, title, onYes, onNo)
{
    var buttons = {};
    if(onNo == null)
        onNo = $.noop;
    buttons[i18n.get('No')] = closeDialogOn(onNo);
    buttons[i18n.get('Yes')] = closeDialogOn(onYes);
    showOrQueueMessage(content,title,buttons);
    return;
}

function closeDialogOn (sub)
{
    return function () {
        if(sub)
            sub.apply(this);
        if($(this).id == 'messageWrapper')
        {
            destroyMessageBox();
        }
        else
        {
            $(this).dialog('close');
        }
    };
}

/*
 * This works like prompt(), except that it displays a pretty on-site dialog
 * and works asynchroniously.
 * functionName is the NAME of the function you wish to be called when this dialog
 * is closed. The function will recieve a single parameter. That parameter
 * is null when the user presses Cancel. Otherwise it is the content of the
 * entry form (which can be empty).
 *
 * Optionally it can also take a third string, this will be the name of
 * the Ok button (which, obviously, otherwise will be 'Ok').
 */
function userPrompt (question, functionName, okName)
{
    if(okName == null || okName == '')
    {
        okName = i18n.get('Ok');
    }
    var html = question +'<br />',
        buttons = {};
    html = html + '<input type="text" id="prompt_entry" name="prompt_entry" style="width: 98%;" />';
    buttons[okName] = closeDialogOn(function() {
        eval(functionName+'($("#prompt_entry").val())');
    });
    buttons[i18n.get('Cancel')] = closeDialogOn(function () {
        eval(functionName+'(null)');
    });
    showOrQueueMessage(html,null,buttons);
    return;
}

/*
 * The same as userPrompt, but takes a reference to a function instead of a
 * function string.
 *
 * Also has an additional parameter, defaltValue (can be null) that is
 * the value to display in the entry box
 */
function XuserPrompt (question, cb, okName, defaultValue)
{
    if(okName == null || okName == '')
    {
        okName = i18n.get('Ok');
    }
    var html = question +'<br />',
        buttons = {};
    if (defaultValue == null)
    {
        defaultValue = '';
    }
    else
    {
        defaultValue = defaultValue.replace(/"/g,'\\"');
    }
    html = html + '<input type="text" id="prompt_entry" name="prompt_entry" style="width: 98%;" value="'+defaultValue+'" />';
    buttons[okName] = closeDialogOn(function() {
        cb($("#prompt_entry").val());
    });
    buttons[i18n.get('Cancel')] = closeDialogOn(function () {
        cb(null);
    });
    showOrQueueMessage(html,null,buttons);
    return;
}

/*
 * This is the same as alert(), but prettier and asynchronous
 */
function userMessage (message)
{
    return rawUserMessage(message,null,null);
}

function rawUserMessage (message,title,buttonName, settings)
{
    if (!buttonName)
        buttonName = 'Ok';
    var buttons = {}
    buttons[buttonName] = closeDialogOn();
    showOrQueueMessage(message,title,buttons,settings);
}

/*
 * Quickly create a dialog with the title 'title' and the HTML contents in
 * 'contents'.
 * This is essentially the same as rawUserMessage, but rawUserMessage
 * is not part of the actual public API and might change, so use this one.
 */
function quickDialog (title,contents, okName, settings)
{
    if(title == null)
    {
        title = '';
    }
    return rawUserMessage(contents,title, okName, settings);
}

/* **
 * General dialog wrappers
 * **
 */

function showThisMessage (content)
{
    try
    {
        showingMessageBox = true;
        var settings = {
            buttons: content.buttons,
            title: content.title,
            modal: true,
            width: 500,
            close: destroyMessageBox_onClose
        };
        if (content.settings)
            $.extend(settings,content.settings);
        $('#messageWrapper').html(content.html);
        $('#messageWrapper').dialog(settings);
        prevMessage = content;
    }
    // The message might be vital, so display it in an alert if all else fails. It'll
    // contain a bit of HTML, but they'll have to live with it.
    catch(e)
    {
        alert('(an error occurred while trying to display the Lixuz message dialog ("'+e.message+'"). dumping message contents here):\n\n'+content);
    }
}

function destroyMessageBox ()
{
    $('#messageWrapper').dialog('close');
}

function destroyMessageBox_onClose ()
{
    if(queuedMessages.length > 0)
    {
        var message = queuedMessages.shift();
        if(prevMessage != null && message == prevMessage)
        {
            // Ok, the message was the same as the one the user just clicked
            // OK on, so move along, nothing to see here.
            //
            // We re-call ourselves to check if we need to show another one
            // in the queue.
            destroyMessageBox();
            return;
        }
        showThisMessage(message);
    }
    else
    {
        prevMessage = null;
        showingMessageBox = false;
    }
}

function showOrQueueMessage (content, title, buttons, addSettings)
{
    var settings = {
        html: content,
        title: title,
        buttons: buttons,
        settings: addSettings
    };
    if (!showingMessageBox)
    {
        showThisMessage(settings);
    }
    else
    {
        queuedMessages.push(settings);
    }
}

var dialogNo = 0;

/* *******************************
 * Begin new class-style utilities
 * *******************************
 */
var lzWrapperHelpers = jClass.virtual({
    myGlobalTMPVar: null,

    _destructor: function ()
    {
        if(this.myGlobalTMPVar)
            window[this.myGlobalTMPVar] = undefined;
    },

    /*
     * Some of the functions available in standard.js has not yet been
     * converted to something that can handle direct function calls, therefore
     * we use globalSelfFunc to generate a globally available variable with
     * a unique random name that we can use to reference ourselves in
     * eval()ed code
     */

    globalSelfFunc: function (func)
    {
        if(this.myGlobalTMPVar)
            return 'window.'+this.myGlobalTMPVar+'.'+func;
        var globTMP = 'articleSubmit.',
            t = new Date();
        globTMP = globTMP + t.getTime()+'.';
        globTMP = globTMP + Math.random();
        globTMP = globTMP.replace(/\./g,'_');
        this.myGlobalTMPVar = globTMP;
        window[globTMP] = this;
        return 'window.'+globTMP+'.'+func;
    },

    /*
     * This returns a function, that function will run the method supplied
     * on the object that inherits this class.
     *
     * This means that if a child of this class does:
     * var myObj = this.objMethodRef('myMethod');
     * then myObj(1,2) is equivalent to calling theObject.myMethod(1,2).
     * This is very useful for callbacks, when you want to have the callback be
     * run on the object, instead of as a pure function. Arguments and return
     * values are propagated as one would expect.
     *
     * You can supply either the reference to a function, or a string. If a string
     * then that should be the name of the method on 'this' to run. In that case
     * the method is resolved to a function reference before this method returns.
    */

    objMethodRef: function (method)
    {
        var lzWHSelf = this;
        if(typeof(method) == 'string')
            method = this[method];
        var ret = function ()
        {
            return method.apply(lzWHSelf,arguments);
        };
        return ret;
    }
});

var lzProgressIndicators = jClass.virtual({
    showingPI: false,
    
    showPI: function (text,force)
    {
        if(this.showingPI && !force)
            return;
        showPI(text,force,null,getCallerName(arguments));
        this.showingPI = true;
    },

    destroyPI: function ()
    {
        if (!this.showingPI)
            return;
        destroyPI();
        this.showingPI = false;
    }
});

/*
 * dialogBox is a wrapper class for the jQuery-UI dialog. It will handle a lot of
 * the heavy lifting, making them easier to use.
 *
 * The first constructor parameter, content, is either an HTML string or a DOM
 * element. If it is a HTML string then DOM entries for it will automatically be
 * generated.
 *
 * The second parameter, dialogSettings, is the settings that should be passed to
 * the constructor for the jQuery-UI dialog, use it to pass parameters to it.
 *
 * The final parameter, dialogSettings, defines specific settings for this
 * dialogBox class.
 */
var dialogBox = jClass({

    dialogObj:null,
    $dialogObj:null,

    _constructor: function (content,dialogSettings,settings)
    {
        if(typeof(content) == 'string')
        {
            dialogNo++;

            this.dialogObj = document.createElement("div");
            this.dialogObj.id = 'dialog_no_'+dialogNo;
            this.$dialogObj = $(this.dialogObj);
            this.$dialogObj.html(content);
        }
        else
        {
            this.dialogObj = content;
            this.$dialogObj = $(this.dialogObj);
        }
        $('#dialogWrapper').append(this.$dialogObj);

        var set = this.constructParameters(dialogSettings,settings);
        UIHelper.update(this.$dialogObj);
        this.$dialogObj.dialog(set);
    },

    constructParameters: function (dialogParams, classSettings)
    {
        var ret = {},
            defaults = {
            modal: true,
            minWidth: 430
        };

        if(dialogParams == null)
            dialogParams = {};

        if(classSettings)
        {
            if(classSettings.closeButton != null)
            {
                var buttons = {};
                buttons[classSettings.closeButton] = closeDialogOn();
                if(dialogParams.buttons)
                    $.extend(dialogParams.buttons,buttons);
                else
                    $.extend(defaults, {buttons: buttons});
            }

            if(classSettings.close == false)
            {
                var hideCloseButton = function () { $(this).parent().children().children('.ui-dialog-titlebar-close').hide(); }
                if(dialogParams.open)
                {
                    var origP = dialogParams.open;
                    dialogParams.open = function ()
                    {
                        hideCloseButton.apply(this,arguments);
                        origP.apply(this,arguments);
                    };
                }
                else
                {
                    defaults.open = hideCloseButton;
                }
            }
        }

        /*
         * Empty our div on close so that any tags with id's will work if an identical window
         * is opened later */
        onClose = function () { $(this).empty() };
        if(dialogParams.close)
        {
            var cfunc = dialogParams.close;
            dialogParams.close = function() { var err; try { cfunc.apply(this,arguments); } catch(err) {}; onClose.apply(this,arguments); if(err) throw(err); };
        }
        else
        {
            defaults.close = onClose;
        }

        if (dialogParams.width == null)
            defaults.width = defaults.minWidth;

        $.extend(ret,defaults,dialogParams);
        return ret;
    },

    hide: function () {
        this.$dialogObj.dialog('hide');
    },

    close: function () {
        this.hide();
        this.$dialogObj.dialog('close');
    },

    _destructor: function () {
        this.close();
        this.$dialogObj.remove();
    }
});
