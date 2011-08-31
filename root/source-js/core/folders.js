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
var lixuzFolders = {
    renameDialog: function ()
    {
        this.loadFolderData(function (reply) {
            lixuzFolders.showRenameDialog(reply);
        });
    },

    showRenameDialog: function (reply)
    {
        var folderList = reply.tree,
            html = i18n.get('Select the folder that you want to rename.')+'<br />';
        html = html+'<select id="folderRename_folder" name="folderRename_folder" style="width:100%;">';
        html = html+folderList;
        html = html+'</select><br />';
        html = html+i18n.get('Rename to')+': <input type="text" id="folderRename_name" value="" />';
        var buttons = {},
            self = this;
        buttons[i18n.get('Rename')] = function () {
            var name = $('#folderRename_name').val();
            if (!name || !name.match(/\S/) || name.length == 0)
            {
                userMessage(i18n.get('Please enter a folder name'));
                return false;
            }
            self.performRename( $('#folderRename_folder').val(), name);
            $(this).dialog('close');
        };
        var LZ_newArticleDialog = new dialogBox(html,
        {
            title: i18n.get('Rename folder'),
            buttons: buttons,
            width: 550
        },
        {
            closeButton: i18n.get('Cancel')
        });
        destroyPI();
    },

    performRename: function(folder,name)
    {
        showPI(i18n.get('Renaming...'));
        XHR.Form.POST('/admin/services/renameFolder', {
            folder_id: folder,
            folder_name: name
        }, lixuz_DD_RefreshList);
    },

    loadFolderData: function (action)
    {
        showPI(i18n.get('Loading folder data ...'));
        XHR.GET('/admin/services/folderList',function (r) {
            action(r);
        });
    },

    deleteDialog: function()
    {
        this.loadFolderData(function (reply) {
            lixuzFolders.showDeleteDialog(reply);
        });
    },

    showDeleteDialog: function(reply)
    {
        var folderList = reply.tree,
            html = i18n.get('Select the folder that you want to delete.')+'<br />';
        html = html+'<select id="folderDelete_folder" name="folderDelete_folder" style="width:100%;">';
        html = html+folderList;
        html = html+'</select>';
        html = html+'<br /><br />'+i18n.get('Note: This action is permanent, there is no undo');
        var buttons = {},
            self = this;
        buttons[i18n.get('Delete')] = function () {
            self.deleteFolder( $('#folderDelete_folder').val(), $('#folderDelete_folder').find('[value='+$('#folderDelete_folder').val()+']').text());
            $(this).dialog('close');
        };
        var LZ_newArticleDialog = new dialogBox(html,
        {
            title: i18n.get('Delete folder'),
            buttons: buttons,
            width: 550
        },
        {
            closeButton: i18n.get('Cancel')
        });
        destroyPI();
    },

    deleteFolder: function(folder, title)
    {
        XuserQuestion(i18n.get_advanced('<b>WARNING:</b> This action is permanent and can NOT be undone.<br /><br />Are you sure you want to delete the folder %(folder) and ALL OF ITS SUBFOLDERS?<br /><br />Any articles or files whose primary folder is the folder you are deleting will be moved to the first folder that can be located.', { folder: title}),
        i18n.get('Confirm deletion'),
        function()
        {
            lixuzFolders.reallyDelete(folder);
        });
    },

    reallyDelete: function(folder)
    {
        showPI(i18n.get('Deleting...<br />This is a heavy operation and may take a while'));
        PI_noSoonMessage = PI_currProgress;
        XHR.GET('/admin/services/deleteFolder/?folder_id='+folder, lixuz_DD_RefreshList);
    }
};
