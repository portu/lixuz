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
 * Image handling code for Lixuz. Interacts with the RTE, allowing
 * the user to add and edit images
 */

// TODO: At some point we probably want to autorefresh data about the file
function LZ_VideoFLVMissing (videoId,running)
{
    deprecated();
    if(running == 1)
    {
        userMessage(i18n.get_advanced('The video file with file_id %(FILEID) has not been converted to the FLV format used to serve video through Lixuz yet, the process is still running, please reload and try again in a few minutes.\n\nIf the conversion takes more than an hour, please contact your system administrator', { 'FILEID': videoId }));
    }
    else
    {
        userMessage(i18n.get_advanced('The conversion of this file (%(FILEID)) to the FLV format failed. Please contact your system administrator.', { 'FILEID':videoId}));
    }
}

// New
var templateSpots,
    currFileUID,
    currFileType,

    spotList;

function LZ_AddImageToArticle (imageId)
{
    currFileType = 'image';
    currFileUID = imageId;
    LZ_ArtFilePrompt(imageId,'image')
}

function LZ_AddFlashToArticle (flashId)
{
    currFileType = 'flash';
    currFileUID = flashId;
    LZ_ArtFilePrompt(flashId,'flash')
}

function LZ_ArtFilePrompt (fileId, fileType)
{
    deprecated();
    var title = i18n.get('File');
    var html =  '';
    var leadSel = true;
    if(currFileType != 'flash')
    {
        var currentCaption = articleFiles.getFileCaption(fileId);
        if(currentCaption == null)
        {
            currentCaption = '';
        }
        leadSel = false;
        html = html + htmlCheckbox('fileActionChangeCaption',i18n.get('Change the caption to:'),'setCaption','radio',true,'fileAction')+'<br />';
        html = html + '<textarea onfocus="$(\'#fileActionChangeCaption\').attr(\'checked\',\'true\');" id="fileSetCaptionEntry" rows="5" style="width:96%">'+currentCaption+'</textarea><br />';
    }

    if (fileType != 'video')
    {
        html = html + htmlCheckbox('fileActionAddToLead',i18n.get('Add to the lead'),'addToLead','radio',leadSel,'fileAction')+'<br />';
        html = html + htmlCheckbox('fileActionAddToBody',i18n.get('Add to the body'),'addToBody','radio',false,'fileAction')+'<br />';
    }
    else
    {
        html = html + htmlCheckbox('fileActionAddToBody',i18n.get('Add to the body'),'addToBody','radio',leadSel,'fileAction')+'<br />';
    }
    var buttons = {};
    buttons[i18n.get('Ok')] = LZ_FileSpotOK;
    addFileDialog = new dialogBox(html,{buttons:buttons, title:title}, { closeButton: i18n.get('Cancel') });
    destroyPI();
}

function LZ_FileSpotOK ()
{
    deprecated();
    var fileActions = document.getElementsByName('fileAction');

    var destroy = function () {
        addFileDialog.hide();
        addFileDialog.destroy();
    };
    
    for(var i = 0; i < fileActions.length; i++)
    {
        var e = fileActions[i];
        if(e.checked)
        {
            if (e.value == 'addToLead')
            {
                destroy();
                LZ_addToRTE(currFileType, currFileUID, 'lead');
                return;
            }
            else if (e.value == 'addToBody')
            {
                destroy();
                LZ_addToRTE(currFileType, currFileUID, 'body');
                return;
            }
            else if (e.value == 'setCaption')
            {
                var caption = $('#fileSetCaptionEntry').val();
                setCaptionForImage(destroy,caption,currFileUID);
                return;
            }
            else
            {
                destroy();
                lzError('Unrecognized value: '+e.value);
                return;
            }
        }
    }
    lzError('No spot setting appears to have been active. Had '+fileActions.length+' fileActions');
    destroy();
}

/*
 * *************
 * Article <-> Files
 * *************
 */

// Add a file to an article
function LZ_addFileToArticle ()
{
    var folder = $('#folder').val();;
    newMultiFileSelector(LZ_addThisFileToArticle,folder);
}

// The function that actually adds the file, contacts the server
function LZ_addThisFileToArticle (fileIds)
{
    if (fileIds.length == 0)
    {
        return;
    }
    showPI(i18n.get('Fetching file information...'));
    var files = '';
    for(var i = 0; i < fileIds.length; i++)
    {
        files = files+'&fileId='+fileIds[i];
    }
    XHR.GET('/admin/articles/ajax?wants=fileInfo'+files,articleFiles.addTheseFiles);
}

// Toggle handler
$.subscribe('/articles/toggleSection/files',function(evData)
{
    evData.handled = true;
    var toggler = function()
    {
        $("#files_slider_inner").slideToggle(null,function()
        {
            $.publish('/article/files/sectionToggled');
        });
    };
    if(articleFiles.imageSpots.length == 0)
    {
        showPI(i18n.get('Retrieving file spots'));
        articleFiles.retrieveFileSpots('image',function (data)
        {
            articleFiles.imageSpots = data['/admin/services/templateInfo'].spots;
            articleFiles.buildFileList();
            destroyPI();
            toggler();
        });
    }
    else
    {
        toggler();
    }
});
