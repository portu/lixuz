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
 * Article submission JavaScript for LIXUZ
 *
 * Copyright (C) Portu media & communications
 * All Rights Reserved
 *
 * Needs: asyncHelper.js jqsimple-class.js
 */

var articleDataManager = jClass({
    getArticleData: function (disableValidation)
    {
        var fields = ['lixuzArticleEdit_uid','lixuzArticleEdit_type', 'LZ_ArticleMoveFilesFound'];
        if ($('#article_liveComments_enable')[0])
        {
            fields.push('article_liveComments_enable');
        }
        var result = getFieldItems(fields, { 'lixuzArticleEdit_uid': 'uid', 'lixuzArticleEdit_type' : 'type'}),
            adFields = LZ_ADField_GetFields(disableValidation);
        if(adFields == false)
        {
            return null;
        }
        $.each(adFields, function (key,value)
        {
            result[key] = value;
        });
        var secondaryFolders = LZ_GetSecondaryFoldersParams();
        if(secondaryFolders === null)
        {
            result['secondaryFolders'] = 'null';
        }
        else if(secondaryFolders)
        {
            result['secondaryFolders'] = secondaryFolders;
        }
        return result;
    },

    getWorkflowData: function (disableValidation)
    {
        var fields = [ 'workflow_priority','workflow_startdate','workflow_deadline','workflow_reassignToRole','workflow_reassignToUser','workflow_watch_article','lixuzArticleEdit_uid' ],
            convertFields = {
            'lixuzArticleEdit_uid': 'artid'
            };
        return getFieldItems(fields, convertFields);
    }
});

var articleSubmit = jClass.extend([articleDataManager,lzWrapperHelpers,lzProgressIndicators],{

    hasDoneFolderCheck: false,
    hasDoneCommentCheck: false,
    hasDoneReassignCheck: false,
    forwardToPage: null,
    moveArticlesFound: 0,

    submit: function ()
    {
        // This method can be called several times before it succeeds,
        // therefore it should not perform any actions that should not
        // be run more than once.

        this.showPI(i18n.get('Saving article...'));
        if (!this.reassignCheck())
            return;
        if(!this.folderCheck())
            return;
        if (!this.commentCheck())
            return;
        this.submitArticle();
    },

    submitAndClose: function ()
    {
        var folder = $('#lz_forwardToFolder').val(),
            forwardToPage = '/admin/articles';

        if(folder != null)
            forwardToPage = forwardToPage+'?folder='+folder;
        this.forwardToPage = forwardToPage;

        this.submit();
    },

    submitArticle: function ()
    {
        var workflow = this.getWorkflowData(false),
            article = this.getArticleData(false);
        if(article == null || workflow == null)
        {
            return this.abort('article or workflow is null');
        }
        if(this.forwardToPage)
        {
            article.articleSaveAndClose = 1;
        }
        var submit = $.extend({
            LZ_ArticleMoveFilesFound: this.moveArticlesFound,
            relationships: relationships.getMap(),
            // FIXME: We don't actually need to submit the entire filesList
            files: articleFiles.filesList,
            tags: articleTags.getList(),
            elements: additionalElements.getList()
        }, workflow,article);
        XHR.JSON.POST('/admin/articles/submit',submit,this.objMethodRef('submitArticle_success'),this.objMethodRef('submitArticle_failure'));
    },

    submitArticle_success: function (data)
    {
        // Update UID to the one from the reply
        $('#lixuzArticleEdit_uid').val(data.uid);
        $('#artid').val(data.uid);
        $('#lz_artid_value').html(data.uid);
        $('#lz_revision_value').html(data.revision);
        var dt = new Date();

        // Update workflow info
        $('#LZWorkflowMessage').html(i18n.get_advanced('<b><i>Changes saved at %(date)<b></i>', {  'date': dt.toLocaleString() }));

        if(data.assigned_to)
        {
            $('#LZWorkflowAssignedTo').html(data.assigned_to);
        }
        if(data.assigned_by)
        {
            $('#LZWorkflowAssignedBy').html(data.assigned_by);
        }
        
        // Update backup tracking point
        updateTrackPoint('save',true);
        if(this.forwardToPage)
        {
            
            // Stops the onbeforeunload handler from triggering
            changedSince = undefined;

            window.location = this.forwardToPage;
        }
        else
        {
            this.destroyPI();
        }
    },

    submitArticle_failure: function (data)
    {
        var errorCode = LZ_JSON_GetErrorInfo(data,null);
        LZWF_WF_ForwardToPage = null;
        if(errorCode == 'STATUSCHANGE_DENIED')
        {
            // FIXME: Horrible phrasing, including the status name would be better.
            userMessage(i18n.get('You don\'t have permission to set the article to the attempted status'));
        }
        else if(errorCode == 'LOCKED')
        {
            userMessage(i18n.get_advanced('Failed to save the article, it is currently locked for editing by <i>%(USER)</i>.', {'USER': data.lockedBy}));
        }
        else if(errorCode == 'ACCESS_DENIED')
        {
            userMessage(i18n.get('You are neither the assigner nor the assignee of this article, so you can not change any of the data.'));
        }
        else
        {
            LZ_SaveFailure(data,'Failed to submit article data: ');
        }
        this.destroyPI();
    },

    folderCheck: function ()
    {
        if(this.hasDoneFolderCheck)
            return true;

        this.hasDoneFolderCheck = true;

        if($('#lixuzArticleEdit_uid').val() == "")
            return true;

        if ($L('folder') != null)
        {
            folder = $L('folder').value;
            if ($L('lixuzArticleEdit_uid') == null)
            {
                return true;
            }
            XHR.Form.POST('/admin/articles/ajax', { 'wants':'folderMove', 'article_id':$L('lixuzArticleEdit_uid').value, 'newFolder':folder }, this.objMethodRef('folderCheck_response'));
            return;
        }
        return true;
    },

    folderCheck_response: function(data)
    {
        if (! data.foundFiles)
        {
            this.submit();
            return;
        }
        else
        {
            this.destroyPI();
            AuserQuestion(i18n.get('There are files that live in the same directory as this article, do you want to move them to the new folder as well?'),this.globalSelfFunc('folderCheck_reply'));
        }
    },

    folderCheck_reply: function (response)
    {
        if(response)
            this.moveArticlesFound = 1;
        this.submit();
    },

    commentCheck: function ()
    {
        if(this.hasDoneCommentCheck)
            return true;
        this.hasDoneCommentCheck = true;
        var csubmit = new commentSubmit();
        if (csubmit.commentIsEmpty())
            return true;
        var message;
        if (this.forwardToPage)
            message = i18n.get('You have an unsaved comment. Do you want to save it now? If you choose not to save it, the comment will be lost.');
        else
            message = i18n.get('You have an unsaved comment. Do you want to save it too?');

        this.destroyPI();
        AuserQuestion(message, this.globalSelfFunc('commentCheck_msgReply'));
        return false;
    },

    commentCheck_msgReply: function (response)
    {
        if (!response)
        {
            this.submit();
            return true;
        }
        var csubmit = new commentSubmit();
        // Don't bother requesting a new comment list when we're closing
        if(this.forwardToPage)
            csubmit.fetchNewList = false;
        csubmit.onComplete = this.objMethodRef('submit');
        csubmit.submit();
    },

    reassignCheck: function ()
    {
        if(this.hasDoneReassignCheck)
            return true;
        this.hasDoneReassignCheck = true;

        // Already closing, don't bother checking it
        if(this.forwardToPage)
        {
            return true;
        }

        var toUser,
            toRole,
            currUID;
        try { toUser = $L('workflow_reassignToUser').value; } catch(err) { toUser = 'null'; };
        try { toRole = $L('workflow_reassignToRole').value; } catch(err) { toRole = 'null'; };
        try { currUID = $L('currentUserId').value; } catch(err) { currUID = 'notfound'; lzlog('Failed to retrieve currentUserId'); };

        if(toUser == 'null' && toRole == 'null')
        {
            return true;
        }
        if(toUser == currUID)
        {
            return true;
        }

        this.destroyPI();

        AuserQuestion(i18n.get('You have reassigned this article. This will result in the article being automatically closed after saving. Do you want to save it now?'),this.globalSelfFunc('reassignCheck_reply'));

        return false;
    },

    reassignCheck_reply: function (reply)
    {
        if(reply)
            return this.submitAndClose();
    },

    abort: function(reason)
    {
        if(reason)
        {
            lzlog('article submission aborted: '+reason);
        }
        this.destroyPI();
        return false;
    }
});
