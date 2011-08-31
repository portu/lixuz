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
 * Lixuz javascript image cropping helpers.
 * Uses the YUI ImageCropper module.
 */
var cropObj;

function initCrop ()
{
    try
    {
        cropObj = new YAHOO.widget.ImageCropper('cropTarget');
        //cropObj.addEvent('onDblClk', updateCropPreview);
    }
    catch(err)
    {
        lzException(err,'Failed to initialize MooCrop object. Cropping will not work.');
    }
    try
    {
        $('#saveCrop').attr('disabled',true);
        $('#hideOrig').attr('disabled',true);
    } catch(e) { lzException(e); }
}

function updateCropPreview ()
{
    try
    {
        var src = "/admin/files/imgedit/resizer/"+$('#file_id').val()+"?"+getCropArgs();
        $('#image_preview').html('<img src="'+src+'" />');
        $('#saveCrop').attr('disabled',false);
        $('#hideOrig').attr('disabled',false);
    }
    catch(e) { lzException(e); }
}

function getCropArgs ()
{
    var crop = cropObj.getCropCoords();
    var src = "width="+crop.width+"&height="+crop.height+ "&left="+crop.left+"&top="+crop.top;
    return src;
}

function saveCrop ()
{
    try
    {
        showPI(i18n.get('Saving cropped image...'));
        JSON_Request('/admin/files/imgedit/saveCrop/'+$('#file_id').val()+"?"+getCropArgs(),cropSaved);
    }
    catch(e) { lzException(e); }
}

function cropSaved (reply)
{
    location.href = '/admin/files/edit/'+reply.newFile;
}

/*
 * Various toggle functions in the UI
 */

function hideOriginalToggle ()
{
    if ($('#cropTargetContainer')[0].style.display == 'none')
    {
        $('#hideOrig').val(i18n.get('Hide original'));
        $('#cropTargetContainer')[0].style.display = 'block';
    }
    else
    {
        $('#hideOrig').val(i18n.get('Show original'));
        $('#cropTargetContainer')[0].style.display = 'none';
    }
}
