/*
 * LIXUZ content management system
 * Copyright (C) Utrop A/S Portu media & Communications 2008-2013
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

var Dashboard = {
    globalAcceptanceLock: false,
    acceptAssignment: function(id)
    {
        var self = this;
        if(this.globalAcceptanceLock !== false)
        {
            userMessage(i18n.get('Please wait until the other article has been accepted before accepting another'));
            return;
        }
        this.globalAcceptanceLock = id;
        $('#LZWorkflowAcceptButton_'+id).html(i18n.get('Accepting...'));
        XHR.GET('/admin/articles/workflow/acceptAssignment/'+id,function()
        {
            var id = self.globalAcceptanceLock;
            $('#LZWorkflowAcceptButton_'+id).html(i18n.get('Accepted!'));
           self.globalAcceptanceLock = false; 
        }, function(data)
        {
            var error = XHR.getErrorInfo(data,null),
                id = self.globalAcceptanceLock;
            if(error == 'DENIED')
            {
                $('#LZWorkflowAcceptButton_'+id).html(i18n.get('Acceptance denied'));
            }
            else
            {
                $('#LZWorkflowAcceptButton_'+id).html(i18n.get('Acceptance failed'));
                LZ_SaveFailure(data,i18n.get('Failed to accept assignment: '));
            }
            self.globalAcceptanceLock = false;
        });
    },


    initialize:function()
    {
        var self = Dashboard;
        $('.dashboardTable').on('click','.dashboard-accept-assignment',function (e)
        {
            var $this = $(this);
            e.preventDefault();
            self.acceptAssignment($this.data('accept-id'));
        });
    }
};
$.subscribe('/lixuz/init', Dashboard.initialize);
