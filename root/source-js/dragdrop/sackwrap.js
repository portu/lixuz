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
 * Wrapper around sack AJAX class that calls jQuery.
 * Used in the drag+drop javascript in LIXUZ
 *
 * Copyright (C) Portu media & communications
 * All Rights Reserved
 */

var sackWrapObj;
function sackWrap_setVar (variable, value)
{
    this.appendToURI = this.appendToURI + '&' + encodeURI(variable) + '=' + encodeURI(value);
}
function sackWrap_runAJAX()
{
    $.get(this.requestFile+this.appendToURI, sackWrap_complete);
    sackWrapObj = this;
}
function sackWrap_complete(response)
{
    if (! this.isSack)
    {
        sackWrapObj.sackWrap_complete(response);
        return;
    }
    this.response = new String(response);
    // We only want the first line, so chop off the rest
    this.response = this.response.split("\n");
    this.response = this.response.shift();
    this.onCompletion();
}
function sack ()
{
    this.isSack = true;
    this.setVar = sackWrap_setVar;
    this.sackWrap_complete = sackWrap_complete;
    this.appendToURI = "?";
    this.requestFile = "";
    this.onCompletion = null;
    this.response = "";
    this.runAJAX = sackWrap_runAJAX;
}
