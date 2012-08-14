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
var secondaryFolders_list;

function LZ_toggleSecondaryFolders ()
{
    if(secondaryFolders_list == null)
    {
        LZ_secondaryFolders_request();
    }
    else
    {
        $('#secondaryFolders_slider_inner').slideToggle('slow');
    }
}

function LZ_secondaryFolders_request ()
{
    var article_id = $('#lixuzArticleEdit_uid').val();

    if(article_id == null || article_id == '')
    {
        userMessage(i18n.get('You must first save the article.'));
        return;
    }

    showPI(i18n.get('Loading folders...'));
    XHR.GET('/admin/articles/ajax?&wants=secondaryFolders&article_id='+article_id,LZ_secondaryFolders_success,null);
}

function LZ_secondaryFolders_success (reply)
{
    secondaryFolders_list = reply;
    $('#secondary_folders_tree').html(reply.tree);
    hilightedFoldersSeed = reply.folders;
    $('#SecondaryFoldersForArticle').html(reply.folders.length);
    try
    {
        var treeObj = new JSDragDropTree();
        treeObj.setImageFolder("/static/images/dragdrop/");
        treeObj.setTreeId("treeview");
        treeObj.setMaximumDepth(7);
        treeObj.filePathRenameItem = "/admin/articles/folderAjax/";
        treeObj.filePathDeleteItem = "/admin/articles/folderAjax/";
        lixuz_DD_URL = "/admin/articles/folderAjax/";
        treeObj.setMessageMaximumDepthReached("Maximum depth of nodes reached");
        treeObj.initTree();
        lixuz_DD_LastOrder = treeObj.getNodeOrders();
        treeObj.orderChangeEvent = lixuz_DD_OrderChangeEvent;
        treeObj.expandAll();
    } catch(e)
    {
        lzException(e);
        destroyPI();
        return;
    }
    loadHilightedFolderSeedInit();
    LZ_toggleSecondaryFolders();
    destroyPI();
}

function LZ_GetSecondaryFoldersParams ()
{
    try
    {
        if(hilightedFolders == null)
        {
            return null;
        }
        var folders = getHilightedFoldersList();
        if(folders.length < 1)
        {
            return '';
        }
        return folders.join(',');
    }
    catch(e){}
    return null;
}
