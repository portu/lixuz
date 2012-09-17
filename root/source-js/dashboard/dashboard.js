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
 * ***********************
 * Accepting an assignment
 * ***********************
 */

var CURR_LZDB_ID = null;

/*
 * This is the function that gets called when a user clicks the
 * "Accept this assignment" button. It contacts the server and tells it that
 * the user wishes to accept this assignment
 */
function LZDB_AcceptAssignment (id)
{
    if(CURR_LZDB_ID)
    {
        userMessage(i18n.get('Please wait until the other article has been accepted before accepting another'));
    }
    CURR_LZDB_ID = id;
    $('#LZWorkflowAcceptButton_'+CURR_LZDB_ID).html(i18n.get('Accepting...'));
    XHR.GET('/admin/articles/workflow/acceptAssignment/'+id,LZDB_AssignmentAccepted, LZDB_AssignmentAcceptFailure);
}

/*
 * This function gets called if a user successfully
 * accepts an assignment
 */
function LZDB_AssignmentAccepted (data)
{
    $('#LZWorkflowAcceptButton_'+CURR_LZDB_ID).html(i18n.get('Accepted!'));
    CURR_LZDB_ID = null;
}

/*
 * This function gets called if we fail to accept an assignment.
 * It will provide the user with the reason why it failed.
 */
function LZDB_AssignmentAcceptFailure (data)
{
    var error = LZ_JSON_GetErrorInfo(data,null);
    if(error == 'DENIED')
    {
        $('#LZWorkflowAcceptButton_'+CURR_LZDB_ID).html(i18n.get('Acceptance denied'));
    }
    else
    {
        $('#LZWorkflowAcceptButton_'+CURR_LZDB_ID).html(i18n.get('Acceptance failed'));
        LZ_SaveFailure(data,i18n.get('Failed to accept assignment: '));
    }
    CURR_LZDB_ID = null;
}

