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
 * Workflow JavaScript for LIXUZ
 *
 * Copyright (C) Portu media & communications
 * All Rights Reserved
 *
 * Needs: asyncHelper.js contentTracker.js
 */

/*
 * Function that submits a new comment
 */
function LZWF_SubmitComment ()
{
    var cSub = new commentSubmit();
    return cSub.submit();
}

/*
 * ***********************
 * Accepting an assignment
 * ***********************
 */

/*
 * This is the function that gets called when a user clicks the
 * "Accept this assignment" button. It contacts the server and tells it that
 * the user wishes to accept this assignment
 */
function LZWF_AcceptAssignment ()
{
    $('#LZWorkflowAcceptButton').html(i18n.get('Accepting assingment ...'));
    JSON_Request('/admin/articles/workflow/acceptAssignment/'+$('#artid').val(),LZWF_AssignmentAccepted, LZWF_AssignmentAcceptFailure);
}

/*
 * This function gets called if a user successfully
 * accepts an assignment
 */
function LZWF_AssignmentAccepted (data)
{
    $('#LZWorkflowAcceptButton').html(i18n.get('You have accepted this assignment'));
    // We submit the workflow in order to update the fields on the page
    LZWF_SubmitWorkflow();
}

/*
 * This function gets called if we fail to accept an assignment.
 * It will provide the user with the reason why it failed.
 */
function LZWF_AssignmentAcceptFailure (data)
{
    var error = LZ_JSON_GetErrorInfo(data,null);
    if(error == 'DENIED')
    {
        $('LZWorkflowAcceptButton').html(i18n.get('You were denied access to accepting this assignment'));
    }
    else
    {
        $('#LZWorkflowAcceptButton').html(i18n.get('Failed to accept assignment.'));
        LZ_SaveFailure(data,i18n.get('Failed to accept assignment: '));
    }
}

/*
 * ***********************
 * Changelog
 * ***********************
 */

window.onbeforeunload = function () {
    try {
        if(changedSince === undefined)
        {
            return;
        }
    } catch(e) { return; }
    if (changedSince('save'))
    {
        return i18n.get('You have unsaved changes. If you move away from this page, those changes will be lost.');
    }
};
