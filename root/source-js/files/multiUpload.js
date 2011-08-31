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
 * Multiple-file uploading for Lixuz
 */

var totalFiles = 0;
function addFile ()
{
    var area = $('#fileUploadArea')[0];
    totalFiles++;
    // FIXME: i18n
    var newFileUP = document.createElement("div");
    newFileUP.id = 'fileEntry'+totalFiles;
    newFileUP.innerHTML = i18n.get('File')+': <input id="upload_file_no_'+totalFiles+'"  onchange="conditionalAddFile('+totalFiles+');" name="upload_file_no_'+totalFiles+'" type="file" size="28"> &nbsp;&nbsp;<a href="#" onclick="removeEntry('+totalFiles+'); return false;">'+i18n.get('Remove')+'</a><br />';
    area.appendChild(newFileUP);
}

function conditionalAddFile (file)
{
    if(file != null && file == totalFiles)
    {
        addFile();
    }
}

function removeEntry (ent)
{
    var entry = $('#'+'fileEntry'+ent);
    if (!ent[0])
    {
        userMessage("removeEntry("+ent+") failed, failed to locate the entry");
        return;
    }
    // FIXME
    entry.html('');
}

function prepFormSubmission ()
{
    try
    {
        if (!validate_lixuz_userEdit())
        {
            return false;
        }
    }
    catch(e) {}
    try
    {
        prepHiddenValues();
        var found = false;
        for(var i = 0; i <= totalFiles; i++)
        {
            var currF = $('#upload_file_no_'+i);
            if (! currF.length)
            {
                continue;
            }
            if(currF.val() != null && currF.val() != '')
            {
                found = true;
            }
        }
        if (!found)
        {
            userMessage(i18n.get('You haven\'t selected any file(s) to upload'));
            return false;
        }
        if ($('#file_folder').val() == null || $('#file_folder').val() == '')
        {
            userMessage(i18n.get('You haven\'t selected any folder'));
            return false;
        }
        if ($('#asyncUpload').val() == '1')
        {
            parent.showPI(i18n.get('Uploading...'));
        }
        else
        {
            showPI(i18n.get('Uploading...'));
            progIndicatorDisplayed = false;
        }
        return true;
    }
    catch(e)
    {
        lzException(e);
        return false;
    }
}

function prepHiddenValues ()
{
    $('#totalFileEntries').val(totalFiles);
}
