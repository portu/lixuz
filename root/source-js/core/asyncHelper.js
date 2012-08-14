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
 * Asynchronous JavaScript helper for LIXUZ
 *
 * Copyright (C) Portu media & communications
 * All Rights Reserved
 *
 * Needs: standard.js asyncQueue.js
 */
/* Function references */
var lixuz_curr_JSON_success,
    lixuz_curr_JSON_error,
/* String with method names */
    lixuz_curr_JSON_eval,
/* Object */
    lixuz_curr_JSON_obj,
    lixuz_curr_JSON_cacheEnabled = false,
/*
 * Global variable keeping track of if we're running a request now or not.
 * Used for queue checks
 */
    lixuz_JSON_Running = false,
/* Our request queue */
    lixuz_JSON_Queue,
    lixuz_curr_JSON_URL = null,

    lixuz_JSON_dataCache = {};

/*
 * This creates a XMLHttpRPC request, and lets you have an object
 * as the target.
 *
 * URL is the URL to request
 * obj is the object that the functions successName/errorName will run on
 * methname is a STRING, the name of the method to run on obj when
 *      a request has finished. Will get a single argument, which is the
 *      contents of the request.
 * POSTDATA can be null, if not it is the data to POST to URL
 */
function JSON_Request_WithObj(URL, obj, methname, POSTDATA)
{
    deprecated('JSON_* functions have been superseeded by the XHR object');
    try
    {
        lixuz_curr_JSON_eval = methname;
        lixuz_curr_JSON_obj = obj;
        _runOrQueue_JSON_Request(URL,POSTDATA,ASYNCRequestWithObject_Response,null);
    } catch(e) { lzException(e); }
}

/*
 * Internal handler function for replies to JSON_Request_WithObj(),
 * you shouldn't ever have to call this yourself.
 */
function ASYNCRequestWithObject_Response(text,xml)
{
    deprecated('Superseeded by the XHR object');
    try
    {
        var obj = lixuz_curr_JSON_obj,
            evalmeth = lixuz_curr_JSON_eval;
        lixuz_curr_JSON_obj = null;
        lixuz_curr_JSON_eval = null;
        try
        {
            eval('(obj.'+evalmeth+'(text))');
        }
        catch(e)
        {
            lzException(e);
        }
    } catch(e) { lzException(e); }
    return true;
}

/*
 * This creates a XMLHttpRPC request that returns JSON and
 * does all the parsing and handling for you.
 *
 * URL is the URL to request
 * success_func is the function to call on success, prototype (data)
 * error_func is the function to call on error, prototype (error)
 */
function JSON_Request (URL, successFunc, errorFunc)
{
    deprecated('JSON_* functions have been superseeded by the XHR object');
	_runOrQueue_JSON_Request(URL, null, successFunc, errorFunc);
}

/*
 * This is identical to JSON_Request, with the exception
 * that this will permanently cache the results in memory until the user
 * leaves the page
 */
function JSON_Cachable_Request(URL, successFunc, errorFunc)
{
    deprecated('JSON_* functions have been superseeded by the XHR object');
    if(lixuz_JSON_dataCache != null && lixuz_JSON_dataCache[URL])
    {
        successFunc(lixuz_JSON_dataCache[URL]);
        return;
    }
	_runOrQueue_JSON_Request(URL, null, successFunc, errorFunc,true);
}

/*
 * This invalidates the entire JSON cache
 */
function JSON_Invalidate_Cache ()
{
    deprecated('Data cache should not be used');
    lixuz_JSON_dataCache = {};
}

/*
 * This works just like JSON_PostRequest, with the exception that it takes a
 * JS hash as a data parameter instead of a string. The JS hash is converted
 * to URL post strings and then given to JSON_PostRequest. The hash has to be
 * one-dimensional, but arguments can be an array, in which case it will
 * generate one parameter for each value in the array.
 */
function JSON_HashPostRequest(URL, postHashData, successFunc, errorFunc)
{
    deprecated('JSON_* functions have been superseeded by the XHR object');
    try
    {
        var data = '';

        $.each(postHashData, function (key,value)
               {
                    if(key == '$family')
                       return; // Works like 'continue' when inside $.each()
                    if(value == undefined || value == null)
                    {
                        lzlog('The value for the key '+key+' was undefined or null in JSON_HashPostRequest to '+URL+' - ignoring');
                    }
                    else if(typeof(value) == 'array' || typeof(value) == 'object' )
                    {
                        $.each(value, function(i,item) {
                                data = data+'&'+encodeURIComponent(key)+'='+encodeURIComponent(item);
                            });
                    }
                    else if(typeof(value) == 'object')
                    {
                        lzError('JSON_HashPostRequest got an object as the key '+key+': this is unhandled.',null,true);
                    }
                    else if(typeof(value) == 'function')
                    {
                            // Skip
                    }
                    else
                    {
                        data = data+'&'+encodeURIComponent(key)+'='+encodeURIComponent(value);
                    }
               });
        _runOrQueue_JSON_Request(URL, data, successFunc, errorFunc);
    }
    catch(e)
    {
        lzException(e);
    }
}

/*
 * Response handler for JSON_Request
 */
function JSON_Request_Response (reply,code,xhr_obj)
{
    var response;
    try
    {
        if(reply == null || reply.length <= 0)
        {
            reply = null;
            response = 'EMPTY_REPLY';
        }
    }
    catch(e)
    {
        lzException(e,'Fatal error while interpreting JSON response');
    }

	var onError = lixuz_curr_JSON_error,
	    onSuccess = lixuz_curr_JSON_success,
        enableCache = lixuz_curr_JSON_cacheEnabled;
	lixuz_curr_JSON_error = null;
	lixuz_curr_JSON_success = null;
    lixuz_curr_JSON_cacheEnabled = null;

	if(reply == null || reply.status == null || reply.status == 'ERR' || reply.status != 'OK')
	{
        if(response == null)
        {
            if(reply == null)
            {
                response = 'UNSAFE_JSON';
            }
            else
            {
                response = reply;
            }
        }
		if(onError)
		{
            try
            {
			    onError(response);
            }
            catch(e)
            {
                lzException(e,'This is a bug, something went wrong when calling the onError handler');
            }
		}
		else
		{
            LZ_SaveFailure(response,null);
		}
	}
	else
	{
		if (!onSuccess)
		{
            lzError('Failed to locate any lixuz_curr_JSON_success object');
            destroyPI(); // Destroy progress indicator
		}
		else
		{
            try
            {
                _LZ_JSON_AddToCache(lixuz_curr_JSON_URL,reply);
                onSuccess(reply);
            }
            catch(e)
            {
                var name = 'unknown';
                try
                {
                    name = onSuccess.toString();
                    name = getFuncNameFromOutput(name);
                } catch(err) {}
                lzException(e,'This is a bug, something went wrong when calling the onSuccess handler '+name);
            }
		}
	}
    lixuz_JSON_Running = false;
    _runNextInJSONQueue();
	return;
}

/*
 * This is a function that can extract either the error code from
 * returned JSON data, or provide you with a generic error message
 * that you can use if you can't handle the error code yourself.
 *
 * data is the data you get from your JSON request
 * type is the generic error message you want appended.
 *
 * If type is false then the error code will get returned.
 * If type is not false then the generic error message wil get returned.
 */
function LZ_JSON_GetErrorInfo (data, type)
{
    deprecated('Replaced by XHR.getErrorInfo');
    var errorCode,
        genericError = type ? type : '';
    genericError = genericError + ' ';
    try
    {
        if(data.error)
        {
            if(data.human_error)
            {
                genericError = genericError + data.human_error + ' (' + data.error + ')';
            }
            else
            {
                genericError = genericError+data.error;
            }
            errorCode = data.error;
        }
        else if(data.human_error)
        {
            errorCode = 'UNKNOWN_ERRORCODE_MISSING';
            genericError = genericError + data.human_error + ' (' + data.error + ')';
        }
        else
        {
            errorCode = data;
            genericError = genericError+data;
        }
    }
    catch(e)
    {
        errorCode = 'UNKNOWN_BADDATA';
        genericError = genericError+errorCode;
    }

    var ret;

    if(type)
    {
        ret = genericError;
    }
    else
    {
        ret = errorCode;
    }

    if(typeof(ret) != 'string')
    {
        try
        {
            lzlog('Strange return from LZ_JSON_GetErrorInfo was not string. It was '+typeof(ret)+' - toJSON: '+$.toJSON(ret));
        }
        catch(e) { lzlog('toJSON of strange return from LZ_JSON_GetErrorInfo failed'); };
    }
    return ret;
}

/*
 * This is a function that you can call if you can not handle the
 * errorCode returned by the JSON request.
 * It can handle generic and common errors that might get returned,
 * and provide useful messages for you.
 *
 * data is the data returned by the JSON request
 * genericError is the generic error message that will be used in case
 *  the error code can't be handled by LZ_SaveFailure either. It is the same
 *  as the type parameter to LZ_JSON_GetErrorInfo
 */
function LZ_SaveFailure (data, genericError)
{
	var errorCode,
        hadGeneric = false;
    LZWF_WF_ForwardToPage = null;

    errorCode = XHR.getErrorInfo(data,null).tech;
    if(genericError)
    {
        hadGeneric = true;
    }
    genericError = XHR.getErrorInfo(data, genericError).message;
    destroyPI(); // Destroy progress indicator
    var myLzError,
        errorInfoMsg = i18n.get('If the problem persists please contact your system administrator and include the information at the bottom of this message.');
	if(errorCode == 'NEEDSLOGIN')
	{
        // TODO: We could open up the login frame in a pop-under iframe and have the user
        // log in right on the page and then auto-submit again once the iframe is deleted.
		userMessage(i18n.get('Failed to submit data, you have been logged out of Lixuz. Please open the Dashboard page in another tab or window and log in there, and then try to save your data again'));
	}
    else if(errorCode == 'ACCESS_DENIED')
    {
        userMessage(i18n.get('You do not have access to save or access this data'));
    }
    else if(errorCode == 'UNSAFE_JSON')
    {
        myLzError = i18n.get('The data returned from the server was not safe, this is a bug. Your data may not have been saved.')+' '+errorInfoMsg;
    }
    else if(errorCode == 'UNKNOWN_ERRORCODE_MISSING' || errorCode == 'UNKNOWN_BADDATA' || errorCode == 'UNKNOWN')
    {
        myLzError = i18n.get('The data returned from the server was missing essential fields, this is a bug. Your data may not have been saved.')+' '+errorInfoMsg;
    }
    else if(errorCode == 'EMPTY_REPLY')
    {
        myLzError = i18n.get('The server did not reply with any data, this is a bug. Your data may not have been saved.')+' '+errorInfoMsg;
    }
    else if(errorCode == 'SQL_ERROR')
    {
        myLzError = i18n.get('A failure occurred while talking to the database server, this is most likely a bug. Your data has probably not been saved.')+' '+errorInfoMsg;
    }
    else if(errorCode == 'INTERNAL_ERROR')
    {
        myLzError = i18n.get('An internal server error occurred while the server was processing your request. Please try again soon.')+' '+errorInfoMsg;
    }
    else if(errorCode == 'MASON_HANDLER_GOT_JSON')
    {
        myLzError = i18n.get('The server misunderstood our request and attempted to return invalid data. Please try again soon.')+' '+errorInfoMsg;
    }
    // The following errors are not translated on purpose, they are very technical and should only
    // occur during development.
    else if(errorCode == 'MISSING_PARAMS' || errorCode == 'INVALID_PARAMS' || errorCode == '404_ERROR')
    {
        myLzError = i18n.get('An error occurred with the request that was submitted.')+' '+errorInfoMsg;
    }
	else
	{
        if(hadGeneric)
        {
            myLzError = genericError;
        }
        else
        {
            myLzError = 'Unhnadled error while fetching data: '+genericError;
        }
	}
    if(myLzError !== null)
    {
        lzError(errorCode+' while submitting to '+lixuz_curr_JSON_URL,myLzError,false);
        lzlog(data);
    }
}

/*
 * Dummy function that does nothing with the data supplied to it.
 * You can use this if you don't really care about errors.
 */
function JSON_IgnoreError (data)
{
    deprecated('Should use $.noop');
    // Do nothing, successfully
    return true;
}

/*
 * Internal functions
 */

// Run a request, or add it to the queue
function _runOrQueue_JSON_Request (URL, postData, successFunc, errorFunc, enableCache)
{
    if (!lixuz_JSON_Running && (lixuz_JSON_Queue == null || lixuz_JSON_Queue.length == 0))
    {
        _run_JSON_Request(URL, postData, successFunc, errorFunc,enableCache);
    }
    else
    {
        try
        {
            var queueEntry = {
                        'URL':  URL,
                        'postData': postData,
                        'successFunc': successFunc,
                        'errorFunc': errorFunc,
                        'enableCache':enableCache
            };
            if (lixuz_JSON_Queue == null)
            {
                lixuz_JSON_Queue = [];
            }
            lixuz_JSON_Queue.push(queueEntry);

            if (!lixuz_JSON_Running)
            {
                _runNextInJSONQueue();
            }
        }
        catch(e)
        {
            lzException(e);
        }
    }
}

// Run a request
function _run_JSON_Request (URL, postData, successFunc, errorFunc, enableCache)
{
    if(URL == null)
    {
        destroyPI();
        lzError('_run_JSON_Request: Fatal: URL is null. Refusing to send request to the void!');
        _runNextInJSONQueue();
        return false;
    }
    try
    {
        lixuz_curr_JSON_cacheEnabled = enableCache;
        lixuz_JSON_Running = true;
        lixuz_curr_JSON_error = errorFunc;
        lixuz_curr_JSON_success = successFunc;

        if(postData)
        {
            postData = postData + '&_JSON_Submit=1';
        }
        else
        {
            postData = '_JSON_Submit=1';
        }

        lixuz_curr_JSON_URL = URL;
        
        $.ajax({
            url: URL,
            success: JSON_Request_Response,
            type: 'POST',
            data: postData
        });
    }
    catch(e)
    {
        destroyPI();
        lzError('While submitting a JSON request to "'+URL+'": '+e.message);
        lixuz_JSON_Running = false;
        _runNextInJSONQueue();
    }
}

// Add data from a URL to the cache
function _LZ_JSON_AddToCache (URL,data)
{
    lixuz_JSON_dataCache[URL] = data;
}

// Run the next queued request
function _runNextInJSONQueue ()
{
    if(lixuz_JSON_Running || lixuz_JSON_Queue == null || lixuz_JSON_Queue.length == 0)
    {
        return;
    }
    var q = lixuz_JSON_Queue.shift();
    _run_JSON_Request(q.URL, q.postData, q.successFunc, q.errorFunc, q.enableCache);
}

/*
 * multiRequest helper
 *
 * Parameters:
 *  paths: an array []  of strings, the strings are the paths that you want
 *      JSON_multiRequest to retrieve
 *  argHash: an hash {} of key=>value pairs that will be posted as request
 *      parameters to the server.
 *  onSuccess: function reference to the function that will be called on
 *      success.
 *  errorFunc: function reference to the function that will be called on
 *      error. Like with all other JSON_* functions, it can be null.
 *  dontRequireAll: a boolean. If it is true then if any of the paths supplied
 *      in the paths array fail to return data for some reason (ie. the
 *          path is invalid or the user does not have permission)
 *      it will not be considered a fatal error, and the server will return
 *      the partial data instead of an error.
 */
function JSON_multiRequest(paths,argHash,onSuccess,errorFunc,dontRequireAll)
{
    deprecated('JSON_* functions have been superseeded by the XHR object');
    // Ensure variables are of proper types
    argHash = argHash;
    if(argHash['mrSource'])
    {
        if(typeof(argHash['mrSource']) != 'string')
        {
            paths.extend(argHash['mrSource']);
        }
        else
        {
            paths.push(argHash['mrSource']);
        }
    }

    argHash['mrSource'] = paths;

    if (!dontRequireAll)
    {
        argHash['multiReqFail'] = true;
    }

    return JSON_HashPostRequest('/admin/services/multiRequest',argHash,onSuccess,errorFunc);
}
