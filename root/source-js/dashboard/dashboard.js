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
    changeTriggered: function($this)
    {
        var newValue = $this.val(),
            type     = $this.data('type'),
            $indicator = $('#progInd').clone();
        $indicator.appendTo($this.parent()).css({
            'display':'inline-block',
            'max-height':'15px',
            'visibility':'visible'
        }).show();
        XHR.GET('/admin/articles?orderby=article_id&ordertype=DESC&_submitted_list_search=1&list_type=pure&filter_assigned_to='+newValue,function(list)
        {
            var styled = 'odd',
                $table = $this.parents('.dashboardTable').find('table'),
                selectedIsMe = $this.find(':selected').data('isme');
            $table.find('tr:not(.headerRow)').remove();
            _.each(list.contents,function(entry)
            {
                var $tr = $('<tr />');
                $('<td />').text(entry.article_id).appendTo($tr);

                var $title = $('<a />');
                var $titleTD = $('<td />');
                $title.attr('title',entry.title);
                $title.text(entry.shortTitle);
                $title.appendTo($titleTD);
                $titleTD.appendTo($tr);

                $('<td />').text(entry.status).appendTo($tr);
                $('<td />').text(entry.timeLimit).appendTo($tr);

                if(type == 'available')
                {
                    var $acceptTD = $('<td />');
                    if(selectedIsMe)
                    {
                        var $accept = $('<input />');
                        $accept.attr('type','button').addClass('dashboard-accept-assignment').data('accept-id',entry.article_id).attr('value',i18n.get('Accept')).button();
                        $accept.appendTo($acceptTD);
                        $acceptTD.attr('id','LZWorkflowAcceptButton_'+entry.article_id);
                    }
                    else
                    {
                        $acceptTD.text('-');
                    }
                    $acceptTD.appendTo($tr);
                }

                $tr.addClass(styled);
                $tr.appendTo($table);
                if(styled == 'even')
                {
                    styled = 'odd';
                }
                else
                {
                    styled = 'even';
                }
            });
            $indicator.remove();
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
        $('.dashboardTable').find('select').change(function()
        {
            var $this = $(this);
            self.changeTriggered($this);
        });
    }
};
$.subscribe('/lixuz/init', Dashboard.initialize);
