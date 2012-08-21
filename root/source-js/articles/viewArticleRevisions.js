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
var artRevUI = {
    box: null,
    artid: null,

    curr: { 
        revision: null,
        status_id: null
    },

    showDialog: function (article_id)
    {
        if(article_id == null || article_id == '')
        {
            article_id = $('#artid').val();
        }
        if(article_id == null || article_id == '')
        {
            userMessage(i18n.get('This article has not been saved so there are no revisions to list'));
            return;
        }
        showPI(i18n.get('Fetching revisions...'));
        XHR.Form.POST('/admin/articles/ajax', {
            article_id: article_id,
            wants: 'revisionList'
        }, this._buildDialogFromData);

        if(this.box && this.box.destroy)
            this.box.destroy();
        this.artid = article_id;
    },

    revStatusChange: function (revision, status_id)
    {
        artRevUI.curr.revision = revision;
        artRevUI.curr.status_id = status_id;

        showPI(i18n.get('Loading statuses...'));
        XHR.Form.POST('/admin/articles/ajax', {
            wants: 'statusList'
            }, function (data) { artRevUI.revStatusChange_dialog(data) });
    },

    revStatusChange_dialog: function (data)
    {
        destroyPI();
        var opt = '<select id="revStatusChange">';
        $.each(data.statuses, function (key, value)
        {
            var id = value.id;
            var curr = '';
            curr = curr + '<option value="'+id+'"';
            if(artRevUI.curr.status_id == id)
            {
                curr = curr + ' SELECTED="SELECTED"';
                key = key +' '+i18n.get('(current)');
            }
            else if(! value.can_access)
            {
                return;
            }
            curr = curr +'>'+key+'</option>';
            opt = opt + curr;
        });
        opt = opt +'</select>';


        var html = i18n.get('Select which status you want to change this revision to. Changing a new revision to "Live" will result in the current live revision being changed to "Inactive".')+'<br /><br />'+i18n.get('Change it to:')+' '+opt;

        var dialog;
        var buttons = {};
        buttons[i18n.get('Change it')] = function ()
        {
            var newStatus = $('#revStatusChange').val();
            if(newStatus != artRevUI.curr.status_id)
            {
                showPI(i18n.get('Changing status...'));
                XHR.Form.POST('/admin/articles/ajax', {
                    wants: 'changeRevStatus',
                    revision: artRevUI.curr.revision,
                    article_id: artRevUI.artid,
                    status_id: newStatus
                }, function () {
                    artRevUI.box.destroy();
                    artRevUI.showDialog(artRevUI.artid);
                });
            }
            dialog.destroy();
        };
        buttons[i18n.get('Cancel')] = function ()
        {
            dialog.destroy();
        };
        dialog = new dialogBox(html,{
            title: i18n.get_advanced('Change the status of revision %(REVISION)', { REVISION: artRevUI.curr.revision }),
            buttons: buttons
        });
    },

    _buildDialogFromData: function (data)
    {
        destroyPI();
        var html = '<table id="artRevTable"><tr><th>'+i18n.get('Revision')+'</th><th>'+i18n.get('Saved by')+'</th><th>'+i18n.get('Saved at')+'</th><th>'+i18n.get('Status')+'</th><th>'+i18n.get('Title')+'</th><th style="min-width: 36px">&nbsp;</th></tr>';
        var viewURL = '/admin/articles/preview/';
        if (/articles\/read/.test(location.href))
        {
            viewURL = '/admin/articles/read/';
        }
        $.each(data.revisions, function (i, rev)
        {
            html = html + '<tr><td class="revNo">'+rev.revision+'</td><td>'+rev.savedBy+'</td><td>'+rev.savedAt+'</td><td class="revStatusID" uid="'+rev.status_id+'">'+rev.status+'</td><td>'+rev.title+'</td>'+'<td>';
            html = html +'<a href="/admin/articles/preview/'+artRevUI.artid+'?revision='+rev.revision+'" target="_blank" title="'+i18n.get('View this revision of the article')+'" class="useTipsy"><img src="/static/images/icons/article-preview.png" alt="" /></a>';
            html = html +'<a href="#" title="'+i18n.get('Change the status of this revision')+'" class="useTipsy changeRevStatus"><img src="/static/images/icons/article-status-change.png" alt="" /></a>';
            html = html + '</td></tr>';
        });
        html = html + '</table>';

        artRevUI.box = new dialogBox(html, {
            minWidth: 600,
            title: i18n.get_advanced('Revisions of %(ARTID)',{ ARTID: artRevUI.artid }),
        }, { closeButton: i18n.get('Close') });
        applyStyleToTable('artRevTable');
        $('.changeRevStatus').click(function ()
        {
            var $row = $(this).parents('tr');
            var status_id = $row.find('.revStatusID').attr('uid');
            var revision = $row.find('.revNo').text();
            artRevUI.revStatusChange(revision,status_id);
            return false;
        });
    }
};
