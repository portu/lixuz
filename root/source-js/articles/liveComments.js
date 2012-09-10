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
 * JS for handling of live comments on articles
 *
 * Copyright (C) Portu media & communications
 * All Rights Reserved
 *
 * Needs: asyncHelper.js
 */
var CommentsForArticle = 0,
    LiveCommentsLoaded = false,
    deleteThisComment;

function LZ_LiveCommentChangeSuccess (data)
{
    LZ_fetchLiveCommentsForArticle(false);
}

// Initial deletion function
function LZ_deleteCommentFromArticle (commentId)
{
    deleteThisComment = commentId;
    AuserQuestion(i18n.get('Are you sure you wish to delete that comment? It will be permanently lost.'),'LZ_reallyDeleteComment');
}

// Actual deletion function
function LZ_reallyDeleteComment (deleteIt)
{
    if(deleteIt)
    {
        showPI(i18n.get('Deleting comment ...'));
        XHR.GET('/admin/articles/deleteComment/'+deleteThisComment,LZ_LiveCommentChangeSuccess,null);
        deleteThisFile = null;
        $('#CommentsForArticle').html(CommentsForArticle--);
    }
}

// Fetch file list for an article
function LZ_fetchLiveCommentsForArticle (toggle)
{
    XHR.GET('/admin/articles/getCommentListFor/'+$('#lixuzArticleEdit_uid').val(),LZ_newLiveCommentList,LZ_newLiveCommentListFailure);
}

// New file list recieved
function LZ_newLiveCommentList (reply)
{
    var html = buildLiveCommentListFromDataset(reply.commentList);
    $('#article_liveComments_list').html(html);
    $('#CommentsForArticle').html(CommentsForArticle);
    destroyPI();
    if(!LiveCommentsLoaded)
    {
        $('#liveComments_slider_inner').slideToggle();
        LiveCommentsLoaded = true;
    }
}

function buildLiveCommentListFromDataset (data)
{
    if(data == null)
    {
        return '';
    }
    var html = '<br /><table width="100%" id="commentList">';
    CommentsForArticle = 0;
    for(var i = 0; i < data.length; i++)
    {
        CommentsForArticle++;
        var e = data[i];
        html = html + '<tr><td><hr />';
        html = html + '</td></tr><tr><td>';
        html = html + '<b>'+e.subject+'</b> ('+e.comment_id+')';
        html = html + '</td></tr><tr><td>';
        html = html + i18n.get('By: ')+' <i>'+e.author_name+'</i> on '+e.datetime+' from '+e.ip;
        html = html + '</td></tr><tr><td>';
        html = html + e.body;
        html = html + '</td></tr><tr><td>';
        html = html + '<input type="button" onclick="LZ_deleteCommentFromArticle('+e.comment_id+'); return false" value="'+i18n.get('Delete this comment')+'" />';
        html = html + '</td></tr><tr><td>&nbsp;</td></tr>';
    }
    html = html+'</table>';
    return html;

}

// Something went wrong when recieving the file list
function LZ_newLiveCommentListFailure (reply)
{
    var error = LZ_JSON_GetErrorInfo(reply,null);
    if(error == 'ACCESS_DENIED')
    {
        destroyPI(); // Destroy progress indicator
        userMessage(i18n.get('You do not have the sufficient priviliges required to retrieve the live comment list'));
    }
    else
    {
        LZ_SaveFailure(reply,i18n.get('Failed to retrieve the live comment list'));
    }
}

// Toggle handler
$.subscribe('/articles/toggleSection/liveComments',function(evData)
{
    evData.handled = true;
    if ($('#lixuzArticleEdit_uid').val() == null || $('#lixuzArticleEdit_uid').val() == '')
    {
        userMessage(i18n.get('You must save the article before you can view comments made to it'));
        return;
    }
    if (!LiveCommentsLoaded)
    {
        showPI(i18n.get('Loading comment list ...'));
        LZ_fetchLiveCommentsForArticle(true);
    }
    else
    {
        $('#liveComments_slider_inner').slideToggle();
    }
});
