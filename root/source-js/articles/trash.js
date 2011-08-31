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
var delete_ArtID,
    restore_ArtID;
function deleteArticleId(artid,artname)
{
    delete_ArtID = artid;
    AuserQuestion(i18n.get_advanced('Are you sure that you want to permanently delete the article "%(NAME)"? This operation can not be reversed.',{ NAME: artname}),'reallyDeleteArticle');
}

function reallyDeleteArticle(response)
{
    if (!response)
    {
        return;
    }
    showPI(i18n.get('Deleting...'));
    JSON_Request('/admin/articles/trash/delete/'+delete_ArtID,articleDeletionSuccess,null);
}

function articleDeletionSuccess ()
{
    window.location.reload();
}

function restoreArticleId(artid,artname)
{
    restore_ArtID = artid;
    AuserQuestion(i18n.get_advanced('Are you sure that you want to restore the article "%(NAME)"?',{ NAME: artname}),'reallyRestoreArticle');
}

function reallyRestoreArticle(response)
{
    if (!response)
    {
        return;
    }
    showPI(i18n.get('Restoring...'));
    JSON_Request('/admin/articles/trash/restore/'+restore_ArtID,articleRestoreSuccess,null);
}

function articleRestoreSuccess()
{
    window.location.reload();
}
