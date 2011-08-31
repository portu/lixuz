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
 * Comment submission JavaScript for LIXUZ
 *
 * Copyright (C) Portu media & communications
 * All Rights Reserved
 *
 * Needs: asyncHelper.js jqsimple-class.js
 */

/*
 * TODO: Make the comment handler return the html we need to redraw the comments section,
 * rather than have us submit yet another request for that data */

var commentDataManager = jClass({
    getCommentData: function ()
    {
        var fields = [ 'lixuzArticleEdit_uid','LZWF_CommentBody','LZWF_CommentSubject'],
            convertFields = { 
                'lixuzArticleEdit_uid': 'artid',
                'LZWF_CommentBody' : 'body',
                'LZWF_CommentSubject' : 'subject'
                };
        return getFieldItems(fields, convertFields);
    }
});

var commentSubmit = jClass.extend([commentDataManager,lzWrapperHelpers,lzProgressIndicators],{
    onComplete: null,
    fetchNewList: true,

    commentIsEmpty: function ()
    {
        try
        {
            var body = $('#LZWF_CommentBody').val(),
                subject = $('#LZWF_CommentSubject').val();
            if (body == null && subject == null)
            {
                return true;
            }
            else if(body.length < 1 && subject.length < 1)
            {
                return true;
            }
            else if(body.match(/\S+/) || subject.match(/\S+/))
            {
                return false;
            }
            return true;
        }
        catch(e)
        {
            return true;
        }
    },

    submit: function ()
    {
        try
        {
            if ($('#artid').val() && $('#artid').val().length > 0)
            {
                if(this.commentIsEmpty())
                {
                    userMessage(i18n.get('Refusing to submit empty comment, please enter a comment, then re-submit.'));
                }
                else
                {
                    this.showPI(i18n.get('Submitting comment...')); // Show progress indicator
                    var data = this.getCommentData();
                    data.revision = $('#lz_revision_value').text();
                    XHR.Form.POST('/admin/articles/workflow/submitComment',data, this.objMethodRef('success'), this.objMethodRef('failure'));
                }
            }
            else
            {
                userMessage(i18n.get('You have to save the article before you can comment on it'));
            }
        }
        catch (e) { lzException(e); }
    },

    fetchCommentList: function ()
    {
        // FIXME: Should use some variation of the asyncHelpers instead of rolling its own
        var URL = '/admin/articles/workflow/comments/'+$('#lixuzArticleEdit_uid').val();
        $.get(URL,this.objMethodRef('commentListSuccess'));
    },

    commentListSuccess: function (text)
    {
        // FIXME: Don't do it if the new text is shorter than the old one
        $('#LZWorkflowCommentsContainer').html(text);
        this.allDone();
    },

    allDone: function ()
    {
        this.destroyPI();
        if(this.onComplete)
            this.onComplete();
    },

    success: function ()
    {
        $('#LZWF_CommentBody').val('');
        $('#LZWF_CommentSubject').val('');
        if (this.fetchNewList)
            this.fetchCommentList();
        else
            this.allDone();
    },

    failure: function ()
    {
        LZ_SaveFailure(data, i18n.get('Failed to submit comment: '));
        this.allDone();
    }
});
