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
 * The number of miliseconds between each poll.
 * Defaults to ten minutes.
 *
 * It can be changed on a per-page basis, either by setting a hidden
 * form element named pollServer_interval to the value you want,
 * or setting the javascript variable pollServer_interval_pageDefault to
 * the value you want. This value must be at least 30000.
 *
 * These can not be set programmatically, but must already be present on the
 * page when pollServer_init() gets called. If you need to change it at any
 * later point you will have to set pollServer_interval yourself,
 * though that won't have the same effect as the currently running timer
 * will have to finish before the new one takes effect.
 */
var pollServer_interval = 600000;

/*
 * Polls the server now, sending along any payload returned by subscribers
 */
function pollServer_now ()
{
    // Our payload, if any
    var payload = {},
    // The URL we request
        requestURI = '/admin/services/poll';
    try
    {
        $.publish('/polling/getPayload',[ payload ]);
    }
    catch(e)
    {
        lzException(e,'Error while generating server poll request with payload (will send standard empty request instead)');
    };

    // If we now have a payload, indicate that in the URL
    if(! $.isEmptyObject(payload))
    {
        requestURI = requestURI+'?hasPayload=1';
    }

    // Inside a try/catch block so that we keep polling even
    // if the request crashes.
    try
    {
        XHR.Form.POST('/admin/services/poll',payload,pollServer_success, pollServer_failure);
    }
    catch(e)
    {
        pollServer_setTimer();
    }
}

/*
 * Called when a poll succeeds, simply sets a new timer for the next poll
 */
function pollServer_success (reply)
{
    try
    {
        $.publish('/polling/success',reply);
    }
    catch (e) {}

    pollServer_setTimer();
}

/*
 * Called when something went wrong while polling
 * (usually related to backups, or network timeouts)
 *
 * TODO:
 * - Handle errors
 * - Should display a message to the user if it failed due to missing permissions
 */
function pollServer_failure (reply)
{
    try
    {
        $.publish('/polling/failure',reply);
    }
    catch (e) {}
    pollServer_setTimer();
}

/*
 * Sets a new pollServer timer
 */
function pollServer_setTimer ()
{
    setTimeout('pollServer_now()',pollServer_interval);
}

/*
 * Initializes our server polling code
 */
function pollServer_init ()
{
    // Look for a page-specific poll interval and replace our default
    // with that if present.
    try
    {
        // The located value
        var value,
        // A hidden form element containing our value
            newInt = $('#pollServer_interval').val();
        // A JS variable containing our value
        if(newInt == null && pollServer_interval_pageDefault != null)
        {
            value = pollServer_interval_pageDefault;
        }
        // If we have a value, and the value is an int, check if
        // it is too low, if not, use it
        var strVal = new String(value);
        if(value != null && ! strVal.match(/\D/) && strVal.length > 0)
        {
            if(value < 30000)
            {
                var message = 'pollServer_init(): fetched page specific value('+value+') is too low, must be above 30000, using the default value ('+pollServer_interval+') instead';
                // We might be too early in the page loading for lzError to be available (though it might be),
                // so ensure that if lzError fails, the user still gets the message.
                try{ lzError(message); } catch(e) { alert(message); }
            }
            else
            {
                pollServer_interval = value;
            }
        }
    }
    catch(e){}
    pollServer_setTimer();
}
