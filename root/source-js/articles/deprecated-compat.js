function LZ_AddFileToRTE(fileId, RTE)
{
    deprecated('Use articleFiles.addToRTE');
    articleFiles.addToRTE(fileId,RTE);
}

function LZ_AddVideoToRTE(videoId, RTE)
{
    deprecated('Use articleFiles.addToRTE');
    articleFiles.addToRTE(videoId,RTE);
}

function LZ_AddAudioToRTE(audioId, RTE)
{
    deprecated('Use articleFiles.addToRTE');
    articleFiles.addToRTE(audioId,RTE);
}

function LZ_AddVideoToArticle (videoId)
{
    deprecated();
    LZ_AddVideoToRTE(videoId,'inline_body');
}

function LZ_AddFileToArticle (fileId)
{
    deprecated();
    LZ_AddFileToRTE(fileId,'inline_body');
}

function LZ_assignFileToSpot (destroy, spot, file,force)
{
    deprecated('Use articleFiles.UI.assignToSpot');
    articleFiles.UI.assignToSpot(file,spot,destroy,force);
}

function LZ_addToRTE (type, id, RTE)
{
    deprecated('Use articleFiles.addToRTE');
    articleFiles.addToRTE(id,RTE);
}

function LZ_AddAudioToArticle (audioId)
{
    deprecated();
    LZ_AddAudioToRTE(audioId,'inline_body');
}

function setCaptionForImage(destroy,caption,fileId)
{
    deprecated('Assign to articleFiles.getFileFromVar(fileId).caption directly');
    destroy();
    articleFiles.getFileFromVar(fileId).caption = caption;
}

function LZ_deleteFileFromArticle (fileId)
{
    deprecated('Use articleFiles.UI.removeFromArticle');
    articleFiles.UI.removeFromArticle(fileId);
}

function buildIconItemFromEntry (entry,filesAssigned,spotlist)
{
    deprecated('Superseeded by articleFiles.getIconItem');
    return articleFiles.getIconItem(entry);
}

function LZ_AddImageToRTE(imageId, RTE)
{
    deprecated('Use articleFiles.addToRTE');
    articleFiles.addToRTE(imageId,RTE);
}
