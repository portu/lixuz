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
 * Backup handler for articles.
 *
 * Requires: utils/backup.js
 */
function init_article_backup ()
{
    try
    {
        // Auto-restore backup if needed
        if ($('#article_autoRestoreBackup').val() == 'true')
        {
            showPI(i18n.get('Restoring backup...'));
            restore_articleBackup();
        }
        // Initialize
        backup_init(get_articleBackupData,'article');
    }
    catch(e)
    {
        lzException(e);
    }
}

function get_articleBackupData ()
{
    try
    {
        var data = {},
            manager = new articleDataManager(),
            cManager = new commentDataManager();
        data['article'] = manager.getArticleData(true);
        data['workflow'] = manager.getWorkflowData(true);
        data['comment'] = cManager.getCommentData(true);
        data['primaryID'] = data.article.uid;
    }
    catch(e)
    {
        lzException(e);
    }
    return data;
}

function restore_articleBackup ()
{
    var myMap = {
                'article': { 
                    'uid' : false,
                    'type' : false
                    },
                'workflow' :  { 
                    'artid' :false 
                    },
                'comment' : {
                    'artid' : false,
                    'body' : 'LZWF_CommentBody',
                    'subject' : 'LZWF_CommentSubject'
                    }
            },
        uid = $('#lixuzArticleEdit_uid').val() || null;
    backup_restore(myMap, 'article', uid);
}
