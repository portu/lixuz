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

function LZ_AddImageToRTE(imageId, RTE)
{
    deprecated();
    try
    {
        var d = new Date();
        var identifier = articleFiles.getIdentifierByID(imageId);
        articleFiles.removeFromSpot(imageId);
        var image = '<img alt="" title="" style="float:right;" src="/files/get/'+identifier+'?width=210" imgId="'+identifier+'" id="image_'+RTE+identifier+d.getTime()+'" /> ';
        lixuzRTE.pushContent(RTE,image);
        articleFiles.buildFileList();
    }
    catch(e)
    {
        lzException(e);
    }
}

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

function LZ_AddAudioToArticle (audioId)
{
    deprecated();
    LZ_AddAudioToRTE(audioId,'inline_body');
}

function LZ_AddAudioToRTE(audioId, RTE)
{
    deprecated();
    try
    {
        var d = new Date();
        var audio = '<div name="lixuz_audio" uid="'+audioId+'" style="display:block;width:400px;height:50" id="player_'+RTE+audioId+d.getTime()+'"><img src="/static/images/icons/audio.png" alt="" /></div>';
        lixuzRTE.pushContent(RTE,audio);
    }
    catch(e)
    {
        lzException(e);
    }
}

function LZ_AddVideoToArticle (videoId)
{
    deprecated();
    LZ_AddVideoToRTE(videoId,'inline_body');
}

function LZ_AddVideoToRTE(videoId, RTE)
{
    deprecated();
    try
    {
        var d = new Date();
        var identifier = articleFiles.getIdentifierByID(videoId);
        var video = '<div name="lixuz_video" uid="'+identifier+'" style="display:block;width:400px;height:300px" id="player_'+RTE+identifier+d.getTime()+'"><img src="/files/get/'+identifier+'?flvpreview=1" style="border:0;" /></div>';
        lixuzRTE.pushContent(RTE,video);
    }
    catch(e)
    {
        lzException(e);
    }
}

function LZ_AddFileToArticle (fileId)
{
    deprecated();
    LZ_AddFileToRTE(fileId,'inline_body');
}

function LZ_AddFileToRTE(fileId, RTE)
{
    deprecated();
    try
    {
        var d = new Date();
        var file = articleFiles.getFileByID(fileId).file;
        var title = file.title;
        var fileName = file.file_name.replace(/"/g,'').replace(/\s/g,'_');;
        if(title == null || title.length == 0)
        {
            title = file.file_name;
            if(title == null || title.length == 0)
            {
                title = 'file_id '+fileId;
                fileName = fileId;
            }
        }
        title = title.replace(/<imageId/g,'&gt;').replace(/>/g,'&lt;');
        var identifier = articleFiles.getIdentifierByID(fileId);
        var entry = '<a href="/files/get/'+identifier+'/'+fileName+'">'+title+'</a>';
        lixuzRTE.pushContent(RTE,entry);
    }
    catch(e)
    {
        lzException(e);
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

function LZ_ArtAddVideo (videoId)
{
    deprecated();
    stub();
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

var takenResponseData;

function LZ_spotTakenResponse (response)
{
    deprecated();
    if (!response)
    {
        return;
    }
    LZ_assignFileToSpot(takenResponseData[0],takenResponseData[1],takenResponseData[2],true);
}

function LZ_assignFileToSpot (destroy, spot, file,force)
{
    deprecated();
    if(articleFiles.spotTaken(spot) && !force)
    {
        var spotFile = articleFiles.getFileBySpot(spot);
        if(spotFile.file_id != file)
        {
            var thisFile = articleFiles.getFileByID(file);
            takenResponseData = [destroy,spot,file];
            AuserQuestion(i18n.get_advanced('A file named "%(NAME)" (id %(ID)) is already assigned to this spot. Do you want to replace it with the file "%(NEWNAME)"?', {
                'NAME': spotFile.file.file_name,
                'ID': spotFile.file_id,
                'NEWNAME': thisFile.file.file_name
            }), 'LZ_spotTakenResponse');
            return;
        }
        else // This file is already assigned to this very spot.
        {
            destroy();
            return;
        }
    }
    destroy();
    articleFiles.assignToSpot(file,spot);
    articleFiles.buildFileList();
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

function setCaptionForImage(destroy,caption,fileId)
{
    deprecated();
    destroy();
    articleFiles.getFileFromVar(fileId).caption = caption;
}

function LZ_addToRTE (type, id, RTE)
{
    deprecated();
    if (type == 'video')
    {
        LZ_AddVideoToRTE(id,RTE);
    }
    else if (type == 'image')
    {
        LZ_AddImageToRTE(id,RTE);
    }
    else
    {
        lzError('LZ_addToRTE(): Unknown type "'+type+'"');
    }
}

function LZ_RetrieveSpots (spotType,onDone)
{
    deprecated();
    if(onDone == null)
        onDone = LZ_RetrievedSpots;
    articleFiles.retrieveFileSpots(spotType,onDone);
}

function LZ_RetrievedSpots  (data)
{
    deprecated();
    LZ_ArtFilePrompt(currFileUID,currFileType,data['/admin/services/templateInfo'].spots,data['/admin/articles/JSON/getTakenFileSpots'].taken);
}

function fileSpotTaken ()
{
    deprecated();
    stub();
}
/*
 * *************
 * Article <-> Files
 * *************
 */

var deleteThisFile = null,

    fidToNameMap = {},
    fidToCaptionMap = {};

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

// Initial deletion function
function LZ_deleteFileFromArticle (fileId)
{
    deleteThisFile = fileId;
    AuserQuestion(i18n.get('Are you sure you wish to remove that file from this article? The file will not be deleted.'),'LZ_reallyDeleteFile');
}

// Toggle the files section closed/open
function LZ_toggleFilesSection ()
{
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
        LZ_RetrieveSpots('image',function (data)
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
}

function buildIconItemFromEntry (entry,filesAssigned,spotlist)
{
    deprecated();
    var iconItem = '';
    try
    {
        iconItem = '<div name="fileEntry" style="height:80px; width:80px;"><img class="filePreview" style="border:0;" src="'+entry.icon+'" /></div>';
        // FIXME: Sanitize the filename length
        iconItem = iconItem+'<span class="fileName">'+entry.fileName+'</span>';
        iconItem = iconItem+'<br /><span class="fileInfo">'+i18n.get('File ID:')+' '+entry.file_id+'<br />';
        iconItem = iconItem+i18n.get('Size:')+' '+entry.sizeString+'<br />';
        var spotName = i18n.get('(none)');
        if(filesAssigned[entry.file_id])
        {
            var spot = filesAssigned[entry.file_id];
            try
            {
                for(var i = 0; i < spotlist.length; i++)
                {
                    if (spotlist[i].id == spot)
                    {
                        spotName = spotlist[i].name;
                    }
                }
            } catch(e) { lzelog(e); }
            if(spotName == i18n.get('(none)'))
            {
                lzlog('Failed to locate spot with id '+spot);
            }
        }
        iconItem = iconItem+i18n.get('Spot:')+' '+spotName;
        iconItem = iconItem+'</span>';
        fidToNameMap[entry.file_id] = entry.fileName;
        fidToCaptionMap[entry.file_id] = entry.caption;
        return iconItem;
    }
    catch(e)
    {
        lzException(e);
    }
}
