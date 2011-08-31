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
 * Article JavaScript for LIXUZ
 *
 * Copyright (C) Portu media & communications
 * All Rights Reserved
 *
 * Needs: asyncHelper.js
 * Needs on article edit page only: workflow.js
 */

// Keep track of running requests in order to not run multiple at once
var artEditLockLost = false,
    artEditLockSoon = false;

/*
 * *************
 * Deleting from the list
 * *************
 */
var MoveToTrash_ArtID;
function moveArticleIdToTrash(artid,artname,status_id)
{
    MoveToTrash_ArtID = artid;
    if (status_id != null && status_id == 2)
    {
        AuserQuestion(i18n.get_advanced('Are you sure that you want to move the article "%(NAME)" to trash? This will permanently change the status of the article from "Live" to "Inactive" (if you restore it, you will need to manually set the article Live again).',{ NAME: artname}),'reallyMoveArticle');
    }
    else
    {
        AuserQuestion(i18n.get_advanced('Are you sure that you want to move the article "%(NAME)" to trash?',{ NAME: artname}),'reallyMoveArticle');
    }
}

function reallyMoveArticle(response)
{
    if (!response)
    {
        return;
    }
    showPI(i18n.get('Moving to trash...'));
    JSON_Request('/admin/articles/trash/move/'+MoveToTrash_ArtID,articleMoveSuccess,null);
}

function articleMoveSuccess ()
{
    window.location.reload();
}

/*
 * *************
 * Backup restoration/deletion
 * *************
 */

var LZ_numberOfArticleBackups = 0,
    LZ_newArticleDialog;

function LZ_DeleteArticleBackup (backup_id)
{
    showPI(i18n.get('Deleting...'));
    LZ_newArticleDialog.destroy();
    JSON_Request('/admin/services/backup?delete='+backup_id, LZ_DeleteArticleBackup_success, LZ_DeleteArticleBackup_failure);
}

function LZ_DeleteArticleBackup_failure (reply)
{
    var error = LZ_JSON_GetErrorInfo(reply,null);
    destroyPI();
    userMessage(i18n.get('Failed to delete: ')+error);
}

function LZ_DeleteArticleBackup_success (reply)
{
    if(LZ_numberOfArticleBackups > 1)
    {
        LZ_ArticleBackupsAvailable();
    }
    else
    {
        destroyPI();
        userMessage(i18n.get('Backup deleted.'));
    }

}

function LZ_ArticleBackupsAvailable ()
{
    showPI(i18n.get('Backups found on server, loading information...'));
    JSON_Request('/admin/services/backup?wants=list', LZ_ArticleBackupsAvailable_success, LZ_ArticleBackupsAvailable_failure);
}

function LZ_ArticleBackupsAvailable_success (reply)
{
    if (reply.hasBackups != 1)
    {
        destroyPI();
        userMessage(i18n.get('An error occurred, we recieved a message from the server saying that there was backups available for restoration. Now it says there aren\'t any. Something is not quite right somewhere'));
        return;
    }
    var tableHeaders = [ i18n.get('Article ID'), i18n.get('Title'), '&nbsp;' ],
        tableData = [];

    LZ_numberOfArticleBackups = 0;
    for(var i = 0; i < reply.list.length; i++)
    {
        LZ_numberOfArticleBackups++;
        var set = reply.list[i],
            info = [];
        var id = set.source_id;
        var href = '/admin/articles/edit/'+id+'?autorestore=1';
        if(id == null)
        {
            info.push('(unsaved)');
            href = '/admin/articles/add/?autorestore=1&folder_id='+set.folder_id;
        }
        else
        {
            info.push(id);
        }
        info.push('<a href="'+href+'">'+set.title+'</a>');
        info.push('<a href="#" onclick="LZ_DeleteArticleBackup('+set.backup_id+'); return false;">'+i18n.get('Delete backup')+'</a>');
        tableData.push(info);
    }
    var html = i18n.get('Backups of some of your articles was found. You may choose to restore these now, delete them, or postpone any action until later. Click on the title of an article to restore it');
    html = html + createTableFromData(tableHeaders, tableData);
    LZ_newArticleDialog = new dialogBox(html, {
        title: i18n.get('Backups found'),
        width: 480,
        height: 250
    }, { closeButton: i18n.get('Later')});
    destroyPI();
}

function LZ_ArticleBackupsAvailable_failure (reply)
{
    var error = LZ_JSON_GetErrorInfo(reply,null);
    userMessage('Failed to retrieve backup information ('+error+')');
}

/*
 * *************
 * Saving
 * *************
 */

function LZ_ArticleSaveAndClose ()
{
	LZ_SubmitArticle(true);
    return false; // Stop buttons
}

function LZ_ArticleSave ()
{
	LZ_SubmitArticle(false);
    return false; // Stop buttons
}
function LZ_SubmitArticle (close)
{
    var submit = new articleSubmit();
    if (close)
    {
        submit.submitAndClose();
    }
    else
    {
        submit.submit();
    }
}

function articleKeepLockStatus(stat,reply)
{
    // TODO: Implement this using a dialogBox rather than userMessage, so that we can change its contents
    if(stat == 'success')
    {
        if (artEditLockLost)
        {
            artEditLockLost = false;
        }
        if(artEditLockSoon)
        {
            artEditLockSoon = false;
        }
        return;
    }
    var $errorDialog = $('#timeoutDialog');
    if(! $errorDialog.length)
    {
        $errorDialog = $('<div />');
        $errorDialog.appendTo('body');
        $errorDialog.attr('id','timeoutDialog');
    }
    if(stat == 'successSoonTimeout')
    {
        if (artEditLockLost)
        {
            artEditLockLost = false;
        }
        if(artEditLockSoon)
        {
            return;
        }
        $errorDialog.dialog('destroy');
        artEditLockSoon = true;
        $errorDialog.attr('title','Warning');
        $errorDialog.html(i18n.get('If you do not save this article within ten minutes, you will lose the edit lock on it.'));
    }
    else if(stat == 'failed')
    {
        if(artEditLockLost)
        {
            return;
        }
        $errorDialog.dialog('destroy');
        $errorDialog.attr('title',i18n.get('Edit lock lost'));
        if(reply.lockHeldBy)
        {
            $errorDialog.html(i18n.get_advanced('You have lost the edit lock for this article, it is now locked by <i>%(USER)</i>. Your data has been backed up, but you will not be able to save or restore the backup until the article has been unlocked.', { 'USER': reply.lockHeldBy }));
        }
        else
        {
            if((i % 3) == 0)
            {
                html = html +'</tr><tr><td>&nbsp;</td></tr><tr>';
            }
            var UID = UIDs[i],
                entry;
            if(data[UID].is_image !== 0)
            {
                entry = '<td align="right"><a href="#" onclick="LZ_AddImageToArticle('+UID+'); return false">'+buildIconItemFromEntry(data[UID],filesAssigned,spotlist)+'</a></td>';
            }
            else if(data[UID].is_video !== 0)
            {
                if(data[UID].has_flv == 1)
                {
                    entry = '<td align="right"><a href="#" onclick="LZ_AddVideoToArticle('+UID+'); return false">'+buildIconItemFromEntry(data[UID],filesAssigned,spotlist)+'</a></td>';
                }
                else
                {
                    var running;
                    if(data[UID].flv_failed == 1)
                    {
                        running = 0;
                    }
                    else
                    {
                        running = 1;
                    }
                    entry = '<td align="right"><a href="#" onclick="LZ_VideoFLVMissing('+UID+','+running+'); return false">'+buildIconItemFromEntry(data[UID],filesAssigned,spotlist)+'</a></td>';
                }
            }
            else if(data[UID].is_flash !== 0)
            {
                entry = '<td align="right"><a href="#" onclick="LZ_AddFlashToArticle('+UID+'); return false">'+buildIconItemFromEntry(data[UID],filesAssigned,spotlist)+'</a></td>';
            }
            else
            {
                entry = '<td align="right">'+buildIconItemFromEntry(data[UID],filesAssigned,spotlist)+'</td>';
            }
            entry = entry + '<td style="vertical-align:bottom;" align="left"><br /><br />';
            entry = entry + '<a href="/files/get/'+data[UID].identifier+'/'+data[UID].file_name+'" target="blank">'+i18n.get('Download')+'</a><br /><a href="#" onclick="LZ_deleteFileFromArticle('+UID+'); return false;">'+i18n.get('Remove')+'</a></td>';

            html = html + entry;
        }
        artEditLockLost = true;
        artEditLockSoon = false;
    }
    else
    {
        userMessage('Error: Unkown reply to articleKeepLockStatus: '+stat);
        return;
    }
    $errorDialog.dialog({
        modal: true,
        buttons: {
            Ok: function() {
                $( this ).dialog( "close" );
            }
        }
    });
}
