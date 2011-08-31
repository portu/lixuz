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
 * Simple content tracker
 *
 * The purpose of these functions is to track if content has changed
 * since a set point.
 *
 * Note: This should be used with backup.js as that does some initialization
 * for us and sets dataTrackingFunction. If you don't want to use backup.js
 * then this needs to be modified to do that itself.
 *
 * Some definitions:
 * A point in this file is a 'tracking point'. Which is a point in a data's
 * lifespan that you want to track. This can be for instance "backup", or "save",
 * to track changes since last backup or save respectively.
 *
 * This allows contentTracker to track multiple points at once.
 */

var dataTracking,
    dataTrackingFunction;

/*
 * Update the tracking point 'point' to the current data.
 * If global is boolean true then all other tracking points will also
 * get set to the current data. This is useful if you're tracking 'save'
 * and 'backup', and want to update 'backup' whenever you 'save'.
 *
 * Optionally, you may supply a third parameter, which is the data
 * to set at this track point. If the third is not supplied then the
 * usual dataTrackingFunction() will be called.
 */
function updateTrackPoint(point, global)
{
    if (!dataTracking)
    {
        dataTracking = {};
    }
    var data;
    if(arguments && arguments[2])
    {
        data = arguments[2];
    }
    else
    {
        data = dataTrackingFunction();
    }
    if(global == true)
    {
        $.each(dataTracking, function(key,value) {
            data[key] = value;
        });
    }
    else
    {
        dataTracking[point] = data;
    }
    return true;
}

/*
 * Check if data for the tracking point has changed since the last
 * track point update. Returns boolean true if it has changed, false otherwise.
 *
 * Note that if you have never called updateTrackPoint() on any point before
 * this then it will return true.
 */
function changedSince(point)
{
    if (!dataTracking)
    {
        return true;
    }
    if(dataTracking[point] == dataTrackingFunction())
    {
        return false;
    }
    return true;
}

function trackPointExists(point)
{
    if (!dataTracking)
    {
        return false;
    }
    else if (!dataTracking[point])
    {
        return false;
    }
    return true;
}
