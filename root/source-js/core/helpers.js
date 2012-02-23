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
 * Standard shared JavaScript functions for LIXUZ
 *
 * Copyright (C) Portu media & communications
 * All Rights Reserved
 */

var lzStoredExceptions = [];

/*
 * *************
 * IE detection helpers
 * *************
 */

/*
 * Summary: Check if we're running in IE or not
 * Returns: boolean, true if we are in IE
 */
function is_ie ()
{
    return /msie/i.test(navigator.userAgent) && !/opera/i.test(navigator.userAgent) && !/chromeframe/i.test(navigator.userAgent);
}

/*
 * Summary: Check which IE version we are running in
 * Returns: IE major version number, for instance 7 for IE7, 6 for IE6.
 */
function ie_majVer ()
{
    if (!is_ie())
    {
        lzError("Error: ie_majVer() called in non-IE browser. Proper browsers do not need IE workarounds");
        return 9999;
    }
    var verNo = navigator.userAgent;
    verNo = verNo.replace(/.*MSIE\s*/,'');
    verNo = verNo.replace(/\D+.*/,'');
    return verNo;
}

/*
 * *************
 * Various unsorted helpers
 * *************
 */

/*
 * Massage a string of HTML into a format that is safe to put on the site
 * and return the massaged string.
 */
function safe_HTML (str)
{
    if(str != null)
    {
        var type = 'string';
        try
        {
            type = typeof(str);
        }
        catch(e) { }
        if(type != 'string')
        {
            var err = 'safe_HTML() got non-string non-null parameter of type: '+type;
            try
            {
                var caller = getFuncNameFromOutput(arguments.callee.caller.toString());
                if(caller != null)
                {
                    err = err + ' - called from '+caller;
                }
            } catch(e) { }
            if(type == 'object')
            {
                err = err + ' (JSON: '+$.toJSON(str)+')';
            }
            lzError(err,null,true);
        }
        str = str.replace(/"/,'&quot;');
        str = str.replace(/<\/?\s*script[^>]>/,'');
    }
    return str;
}

/*
 * Create an HTML checkbox (or radio box)
 *
 * id is the id= value
 * text is the text label
 *
 * The following are optional and can be omitted, in which case they willl default:
 * value is the value= - defaults to none
 * mode is either 'checkbox' or 'radio', defaults to checkbox.
 * selected is a bool, if it is either false or null/omitted then SELECTED will not be added
 * name is the name= value, defaults to the id= value if omitted
 * onchange is the onchange text string, defaults to nothing if null/omitted
 */
function htmlCheckbox (id, text, value, mode, selected, name, onchange)
{
    if(name == null)
    {
        name = id;
    }
    if(mode == null)
    {
        mode = 'checkbox';
    }
    if(selected === true)
    {
        selected = ' SELECTED="SELECTED" checked="checked"';
    }
    else
    {
        selected = '';
    }
    if(value != null)
    {
        value = ' value="'+value+'"';
    }
    else
    {
        value = '';
    }
    if(onchange != null)
    {
        onchange = 'try { '+onchange+' } catch(oe) { lzException(oe); }';
        onchange = ' onchange="'+onchange+'"';
    }
    else
    {
        onchange = '';
    }

    var str = '<span><input type="'+mode+'"'+selected+' id="'+id+'" name="'+name+'"'+value+onchange+' />';
    str = str + '<span onclick="htmlCheckboxToggle(\''+id+'\');">'+text+'</span></span>';
    return str;
}

/*
 * Helper function used by htmlCheckbox() to toggle
 * checkboxes and radioboxes
 */
function htmlCheckboxToggle (id)
{
    try
    {
        var b = $('#'+id)[0];
        if(b.checked)
        {
            if (b.type == 'radio')
            {
                return;
            }
            b.checked = false;
        }
        else
        {
            b.checked = true;
        }
        if(b.onchange)
        {
            b.onchange();
        }
    }
    catch(e)
    {
        lzException(e);
    }
}

/*
 * Change to a page in a pager
 */
function LZ_pagerChange (page)
{
    var url = new String(window.location);
    if (/page=/.test(url))
    {
        url = url.replace(/page=\d*/,'page='+page);
    }
    else
    {
        if (! /\?/.test(url))
        {
            url = url + '?';
        }
        else
        {
            url = url + '&';
        }
        url = url +'page='+page;
    }
    window.location = url;
}

/*
 * Summary: Parse the name of a function out of its toString value
 * Returns: The name of the function with prototype
 */
function getFuncNameFromOutput (func)
{
    try
    {
        var arr = func.split("\n");
        func = arr[0];
        func = func.replace(/^function\s*/,'');
        func = func.replace(/\{.*/,'');
        func = func.replace(/\s+$/,'');
        func = func.replace(/@\S+$/,'');
    }
    catch(e) { }
    try
    {
        if(/^\(.*\)$/.test(func))
        {
            func = 'anonymous function';
        }
    }
    catch(e) { }
    return func;
}

/*
 * Summary: try to fetch information about the caller from an arguments object
 */
function getCallerName (args)
{
    var name;
    var skipStack = false;
    if($.browser.mozilla)
    {
        // FF can hang when we try to fetch the stack and generate a
        // caller from that. So unless debugging has been explicitly
        // requested - skip it.
        if (! document.URL.match(/debug=1/))
        {
            skipStack = true;
        }
    }
    if (!skipStack)
    {
        try
        {
            var stack = (new Error).stack;
            if(stack)
            {
                stack = stack.split("\n");
                // Shift away ourselves and our caller
                stack.shift();
                stack.shift();
                stack.shift();

                var allGood = false;
                $.each(stack, function(index,entry)
                       {
                           if(allGood)
                               return false;
                           if(name == null)
                               name = entry;
                           if(!entry.match(/standard\.js/))
                           {
                               name = entry;
                               allGood = true;
                               return;
                           }
                       });
            }
        } catch(e) { dbglog(e) };
    }
    if(name != null)
    {
        if($.isFunction(name))
        {
            name = getFuncNameFromOutput(name);
        }
        name = new String(name);
        try
        {
            if($.browser.mozilla)
            {
                // Strip off additional stack information
                name = name.replace(/(:\d+),.*/,'$1');
                // *TRY* to strip off arguments
                name = name.replace(/(\S+)\(.+\)@\//,'$1()@/');
                name = name.replace(/(\S+)\(.+/,'$1()/');
                name = name.replace(/.+\[object/,'[object');
                name = name.replace(/\[object Object\]\)?/,'[Object]');
            }
            else if($.browser.webkit)
            {
                name = name.replace(/^\s*at\s*/g,'');
            }
            // Strip off unneccesary URL info
            name = name.replace(/http:\/\/[^\/]+/g,'');
            name = name.replace(/\/+$/,'');
        } catch(e) {}
        if(name != null && name != '')
            return name;
    }
    try
    {
        var manualStack = args.callee.caller,
            stackNo = 0;
        while(manualStack !== null)
        {
            stackNo++;
            try
            {
                name = getFuncNameFromOutput(manualStack.toString());
            } catch(e) {
                name = getFuncNameFromOutput(args.stack);
            }
            if (/lz(Error|Exception)/.match(name))
            {
                manualStack = manualStack.caller;
                continue;
            }
            if(name == '()')
            {
                name = 'anonymous function';
                try
                { 
                    var cc = getFuncNameFromOutput(arguments.callee.caller.caller.toString());
                    if(cc && !/lzError/.match(cc))
                    {
                        name = name + ' (anonymous function called by: '+cc+')';
                    }
                }catch(e) { }
            }
            if(stackNo > 49)
                break;
        }
    }
    catch(e) { }
    if(name == null || name == '')
        return '(unknown)';
    return name;
}

/*
 * Summary: output logging if console exists
 * Returns: bool, true if logging was successful
 */
function lzlog (message,second)
{
    try
    {
        if(console && console.log)
        {
            var dt = new Date(),
                second;
            if(typeof(message) != 'string' && typeof(message) != 'number')
            {
                second = message;
                message = '(got non-string/number)';
            }
            if(second && typeof(second) != 'object')
            {
                message = message+second;
                second = null;
            }
            message = '['+dt.toTimeString().replace(/\s+.*/,'')+'] Lixuz: '+message;
            if(second)
                console.log(message,second);
            else
                console.log(message);

            return true;
        }
        else
        {
            // Turn ourselves (and related functions) into a no-op
            window.lzlog = window.dbglog = window.deprecated = window.stub = $.noop;
        }
    }
    catch(e)
    {
    }
    return false;
}
lzlog('Logging enabled'); // Only gets processed if logging *IS* enabled, so it is harmless to leave it here. And if logging isn't enabled, lzlog will just turn itself into a no-op, speeding up later calls.

/*
 * Summary: Debug logging. This is just an alias for lzlog, so that it is easy to grep for
 *      debugging calls left in by accident
 */
function dbglog (message)
{
    return lzlog('Debug: ',message);
}

/*
 * Summary: Mark a function as stubbed
 */
function stub ()
{
    var caller = '(unknown)';
    try
    {
        caller = getCallerName(arguments);
    } catch(e) { }
    if(! lzlog('Stubbed: '+caller))
    {
        lzError('Stubbed','A function that is not ready was called. This is a bug, please report the following error information to the development team.',false,caller);
    }
}

/*
 * Summary: Mark a function as deprecated
 */
function deprecated (info)
{
    var caller = '(unknown)';
    var calledBy = '(unknown)';
    try { calledBy = getFuncNameFromOutput(arguments.callee.caller.caller.toString()); } catch (e) {}
    try { caller = getCallerName(arguments); } catch (e) { }
    var message = 'Call to deprecated function '+caller+' from '+calledBy;
    if(info)
        message = message+'. '+info;
    lzlog(message);
}

/*
 * Summary: Get field data from the current page in a hash.
 * Arguments:
 * [1] fieldArray : required = Array of field IDs that we should extract data from
 * [2] convertNames : optional, can be omitted = Hash of field IDs => name pairs.
 *  If a fieldID in the fieldArray exists in convertNames, then the value of that
 *      field will be named what convertNames.get(fieldId) says, instead of simply
 *      being named the field's id.
 */
function getFieldItems (fieldArray)
{
    var convertNames = {};
    if(arguments && arguments.length > 1)
    {
        convertNames = arguments[1];
    }

    var data = {};
    for(var f = 0; f < fieldArray.length; f++)
    {
        var fname = fieldArray[f];
        var fvalue = getFieldData(fname);
        if(convertNames[fname])
        {
            fname = convertNames[fname];
        }
        data[fname] = fvalue;
    }
    return data;
}

/*
 * Summary: Get field data from the current page
 * Argument: The field ID we should extract data from
 *
 * This function is the worker function used by getFieldItems. It can also be
 * used to retrieve a single value from an arbitary field in any other code
 * around Lixuz
 */
function getFieldData (fname)
{
    var $field, fvalue,field;
    $field = $('#'+fname);
    field = $field[0];
    try
    {
        if (! field)
        {
            fvalue = '';
        }
        else
        {
            try
            {
                if(field.disabled)
                {
                    fvalue = '';
                }
                else if(field.tagName.match(/^textarea$/i))
                {
                    // Perform editor processing
                    if(lixuzRTE.exists(fname))
                    {
                        // We might get called before the editor has had a chance
                        // to settle (ie. get any data). When that happens, pretend it
                        // contained an empty string.
                        try
                        {
                            fvalue = lixuzRTE.getContent(fname);
                        }
                        catch(e)
                        {
                            fvalue = '';
                        }
                    }
                    // It's a standard textarea, just fetch the value
                    else
                    {
                        fvalue = field.value;
                    }
                }
                // Handle checkboxes
                else if(field.type == 'checkbox')
                {
                    if(field.checked)
                    {
                        fvalue = true;
                    }
                    else
                    {
                        fvalue = false;
                    }
                }
                // 'catch all' for all other fields
                else
                {
                    try
                    {
                        fvalue = $field.val();
                        if($.isArray(fvalue))
                        {
                            fvalue = fvalue.join(',');
                        }
                        else if (
                            (!/^(number|string)/.test( typeof(fvalue))) &&
                            fvalue != null
                        )
                        {
                            lzlog('Unknown value type for field '+fname+' of type '+field.type+': '+typeof(fvalue));
                            console.log(fvalue);
                            throw('failure');
                        }
                    }
                    catch (e)
                    {
                        try
                        {
                            fvalue = field.value;
                            lzlog('Catch all field handler triggered for field type '+field.type+' for field '+fname);
                        }
                        catch(e)
                        {
                            var type = 'unknown';
                            try{type = field.type;} catch(e) {}
                            userMessage('Error while fetching data from field "'+fname+'" (this is a bug): '+e.message+"\n\nDumping some info:\n tagName="+field.tagName+"\n.type:"+type);
                        }
                    }
                }
            }
            catch(e)
            {
                lzException(e);
            }
        }
    }
    catch(e)
    {
        lzException(e);
    }
    return fvalue;
}
