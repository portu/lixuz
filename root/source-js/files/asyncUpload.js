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
 * Asynchronous file uploading for Lixuz
 *
 * Needs: iframe.js asyncHelper.js
 *
 * XXX: Currently only works from the article form.
 */
var lz_upload_iframe,
    LZ_uploadFileDialog;

function LZ_AsyncUploadFiles ()
{
    //showPI('Loading form...');
    try
    {
        var folder_id = $('#folder').val(),
            buttons = {};
        buttons[i18n.get('Close')] = LZ_AsyncUploadClose;
        LZ_uploadFileDialog = new dialogBox('<iframe style="width:650px; height:360px; border:0;" id="uploadFileForm"></iframe>',{
            title: i18n.get('Upload file'),
            buttons: buttons,
            width: 680,
            height: 500
        }, { close: false });
        lz_upload_iframe = new LZ_iFrame('uploadFileForm');
        var html ='<br /><br /><br /><br /><br /><br /><br /><center><b>'+i18n.get('Loading form...')+'</b></center>',
            folder = '';
        lz_upload_iframe.setContent(html);
        if(folder_id != null)
        {
            folder = '&default_folder='+folder_id;
        }
        $('#uploadFileForm')[0].src = '/admin/files/upload?asyncUpload=true&artid='+$('#artid').val()+folder;
    }
    catch(e) { lzException(e); }
}

function LZ_AsyncUploadClose ()
{
    LZ_uploadFileDialog.destroy();
    LZ_uploadFileDialog = null;
    if(is_ie() && ie_majVer() <= 7)
    {
        // This is a workaround for yet another IE bug.
        //
        // After using file input fields IE7 and older disables all
        // input fields on the page for no good reason. They're not
        // disabled in any normal (JS/DOM) way, so we need to focus an
        // input element to convince it to accept input again.
        try { $('#title').focus() } catch (e) { }
    }
}
