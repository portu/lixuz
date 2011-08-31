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
 * Core JS helper for live Lixuz sites
 */

/*
 * Development notes:
 * This file is going to be running on live websites. Error handling here
 * is *essential*. If something goes wrong, we must handle it in a 
 * graceful manner so that the site does not break.
 */

(function($)
{
    function jqIDify (id)
    {
        if (/^#/.test(id))
            return id;
        return '#'+id;
    }
    /*
     * This is a helper function that forwards to the page supplied.
     * It does this by simply either modifying or appending the page=
     * parameter to the current URL.
     */
    window.pagerChange = function (page)
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
    };

    /*
     * This helper toggles the visibility of an element. You should probably
     * use jQuery directly in new code.
     */
    window.toggleVisibility = function (id)
    {
        $( jqIDify(id) ).slideToggle();
    };

    /*
     * Logging
     */
    window.lzlog = function (message)
    {
        try
        {
            if(console && console.log)
            {
                var dt = new Date();
                console.log('['+dt.toString()+'] Lixuz Live: '+message);
                return true;
            }
            else
            {
                // Turn ourselves into a no-op
                lzlog = $.noop;
            }
        }
        catch(e)
        {
        }
        return false;
    };

    window.$L = function (id)
    {
        return $( jqIDify(id) )[0];
    };
})(jQuery);
