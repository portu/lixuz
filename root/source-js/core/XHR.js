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
 * XHR wrapper object for Lixuz.
 *
 * This object can be used to perform various types of requests.
 * They are separated into subgroups. All requests return javascript
 * objects to their onSuccess/onFailure callbacks, parsed from data
 * returned by the server.
 *
 * The JSON subgroup performs requests which submit JSON data to the server.
 *
 * The Form subgroup performs requests which submits normal URI encoded
 * form elements to the server.
 *
 * Methods directly on the root of the object are generic (ie. GET).
 */
var XHR = {
    JSON:
    {
        POST: function (url,data,onSuccess,onFailure)
        {
            data = $.toJSON(data);
            url = XHR._private.addPartToURL(url,'_JSON_POST=1');
            XHR._private.submit({
                url          : url,
                submitString : data,
                onSuccess    : onSuccess,
                onFailure    : onFailure,
                contentType  : 'application/json; charset=utf-8',
                method       : 'POST'
            });
        }
    },

    Form:
    {
        POST: function (url,data,onSuccess,onFailure)
        {
            data = $.param(data);
            XHR._private.submit({
                url          : url,
                submitString : data,
                onSuccess    : onSuccess,
                onFailure    : onFailure,
                method       : 'POST'
            });
        }
    },

    GET: function (url, onSuccess, onFailure)
    {
        XHR._private.submit({
                url          : url,
                onSuccess    : onSuccess,
                onFailure    : onFailure,
                method       : 'GET'
            });
    },

    getErrorInfo: function (data, presetInfo)
    {
        var errorCode,
            genericError = '';
        if (presetInfo)
            genericError = presetInfo;
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
                    genericError = genericError + data.error;
                }
                errorCode = data.error;
            }
            else if(data.human_error)
            {
                errorCode = 'UNKNOWN_ERRORCODE_MISSING';
                genericError = genericError + data.human_error + ' (' + data.error + ')';
            }
            else if(data.internalStatus == 'timeout')
            {
                errorCode = data.internalStatus;
                genericError = genericError + i18n.get('The connection to the server has timed out. Please retry the request soon.');
            }
            else if(data.internalStatus == 'parsererror')
            {
                errorCode = 'Invalid JSON data returned from server.';
                if (data.internalThrown)
                    errorCode = errorCode + ' Threw: '+data.internalThrown;
                genericError = genericError + i18n.get('The server returned invalid JSON data. This is either a temporary server problem, or a bug in Lixuz. If the problem persists, contact your system administrator with the information listed below.');
            }
            else if(data.internalStatus)
            {
                errorCode = data.internalStatus;
                if(data.internalThrown)
                    errorCode = errorCode + ' Threw: '+data.internalThrown;
                genericError = genericError + i18n.get('An unhandled error occurred during the request to the server');
            }
            else
            {
                genericError = genericError + i18n.get('An unknown and unhandled error occurred during the request to the server');
                errorCode = $.toJSON(data);
            }
        }
        catch(e)
        {
            errorCode = 'UNKNOWN_BADDATA';
            genericError = genericError+errorCode;
        }

        try
        {
            if(data.url)
            {
                var url = data.url;
                url = url.replace(/^(https?...)?([^\/]+)/,'').replace(/^.?admin/,'');
                if(errorCode)
                {
                    errorCode = errorCode + ' ';
                }
                errorCode = errorCode + '(request to '+url+')';
            }
        } catch(e) { }

        var ret = { message: genericError, tech: errorCode };

        LIXUZ.error.log(data.tech);

        return ret;
    },

    _private:
    {
        addPartToURL: function(url,part)
        {
            if (! /\?/.test(url))
                url = url+'?';
            if (! /\?$/.test(url))
                url = url+'&';
            return url + part;
        },

        /*
         * Params is a hash.
         *
         * Required keys:
         *    onSuccess   - The success callback
         *    url         - the url to post/get
         *
         * Optional keys:
         *    onFailure   - the failure callback (uses automatic one if not supplied)
         *    method      - the HTTP method to use
         *    data        - the data to submit
         *    contentType - the content type to use for the request
         */
        submit: function (params)
        {
            if(params.onSuccess == null)
            {
                lzError('XHR called without onSuccess. The request will still be submitted, but this is still a bug. Use $.noop instead of null if a callback isn\'t needed');
                params.onSuccess = $.noop;
            }

            lixuz_curr_JSON_URL = params.url;

            if(params.method == null)
                params.method = 'POST';
            params.url = XHR._private.addPartToURL(params.url,'_JSON_Submit=1');
            var reqParams = {
                url     : params.url,
                success : function (response)
                {
                    XHR._private.dataRetrieved(response,params);
                },
                type    : params.method,
                cache   : false,
                error   : function (xhrO, status, thrownError)
                {
                    var error = {
                        'status'         : 'ERR',
                        'internalStatus' : status,
                        'internalThrown' : thrownError,
                        'url'            : params.url
                    };
                    XHR._private.dataRetrieved(error,params);
                },
                data    : params.submitString
            };

            if(params.contentType)
                reqParams.contentType = params.contentType;

            $.ajax(reqParams);
        },

        dataRetrieved: function (data,params)
        {
            try
            {
                if(data == null)
                    lzError("_dataRetrieved got no data",null,true);
                if(typeof(data) == 'string')
                {
                    try
                    {
                        data = $.secureEvalJSON(data);
                    } catch(e)
                    {
                        data = {
                            status: 'ERR',
                            internalStatus: 'parsererror',
                            internalThrown: e.message,
                            url:            params.url
                        };
                    }
                }
                if (! $.isPlainObject(data))
                {
                    data = {
                        'internalStatus':data,
                        'status':'ERR'
                    };
                }
                if(data.status == 'ERR')
                {
                    if($.isFunction(params.onFailure))
                    {
                        // We do this so that the error gets logged
                        XHR.getErrorInfo(data);
                        params.onFailure(data);
                    }
                    else
                    {
                        destroyPI();
                        var errorI = XHR.getErrorInfo(data);
                        lzError(errorI.tech,errorI.message,true);
                    }
                }
                else
                {
                    params.onSuccess(data);
                }
            }
            catch(e)
            {
                destroyPI();
                lzException(e);
            }
        },
    }
};

// Lixuz uses "traditional" request parameters
jQuery.ajaxSettings.traditional = true;
