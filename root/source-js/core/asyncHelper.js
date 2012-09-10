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
/*
 * Global variable keeping track of if we're running a request now or not.
 * Used for queue checks
 */
    lixuz_JSON_Running = false,
/* Our request queue */
    lixuz_JSON_Queue,
    lixuz_curr_JSON_URL = null;

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
	    onSuccess = lixuz_curr_JSON_success;
	lixuz_curr_JSON_error = null;
	lixuz_curr_JSON_success = null;

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
function _runOrQueue_JSON_Request (URL, postData, successFunc, errorFunc)
{
    if (!lixuz_JSON_Running && (lixuz_JSON_Queue == null || lixuz_JSON_Queue.length == 0))
    {
        _run_JSON_Request(URL, postData, successFunc, errorFunc);
    }
    else
    {
        try
        {
            var queueEntry = {
                        'URL':  URL,
                        'postData': postData,
                        'successFunc': successFunc,
                        'errorFunc': errorFunc
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
function _run_JSON_Request (URL, postData, successFunc, errorFunc)
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

// Run the next queued request
function _runNextInJSONQueue ()
{
    if(lixuz_JSON_Running || lixuz_JSON_Queue == null || lixuz_JSON_Queue.length == 0)
    {
        return;
    }
    var q = lixuz_JSON_Queue.shift();
    _run_JSON_Request(q.URL, q.postData, q.successFunc, q.errorFunc);
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

    return XHR.Form.POST('/admin/services/multiRequest',argHash,function (data) { console.log(data); onSuccess(data); },errorFunc);
}
