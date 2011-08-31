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
 * JavaScript for the page that selects additional fields to use for an
 * article.
 *
 * Copyright (C) Portu media & communications
 * All Rights Reserved
 *
 * Needs: asyncHelper.js arrangableList.js
 */

var FieldEdit_Type = null,
    FieldEdit_UID = null;

function LZ_DisplayFieldEditForm (type,uid)
{
    showPI(i18n.get('Loading field list...'));
    FieldEdit_Type = type;
    FieldEdit_UID = uid;
    var URL = '/admin/settings/admin/additionalfields/fieldeditor/'+type;
    if($('#lixuzArticleEdit_uid').val() != null)
    {
        URL = URL+'/'+$('#lixuzArticleEdit_uid').val()+'/'+$('#lz_revision_value').text();
    }
    else if(type == 'files')
    {
        URL = URL + '?object_id=' + FieldEdit_UID;
    }
    JSON_Request(URL,LZ_FieldEditFormReply,LZ_FieldEditFormError);
}

function LZ_FieldEditFormReply (data)
{
    destroyPI();
    try
    {
        newArrangableListWindow({
            'title': i18n.get('Add/remove additional fields'),
            'saveFunction': LZ_SubmitADFields,
            'headers': ['ID','Field'],
            'checkButtonMode':true,
            'checkButtonName':i18n.get('Show'),
            'data': data.entries,
            'defaultOrder': data.order,
            'defaultChecked': data.checked
            });
    }
    catch(e)
    {
        lzException(e, i18n.get('A fatal error occurred when creating the edit dialog. Unable to continue.'));
    }
}

function LZ_FieldEditFormError (reply)
{
    var error = LZ_JSON_GetErrorInfo(reply,null);
    if(error == 'FOLDER_NOT_FOUND')
    {
        userMessage(i18n.get('The folder associated with this article was not found, you need to set a new folder'));
    }
    else if(error == 'NOFOLDERID')
    {
        userMessage(i18n.get('This article does not have an associated folder, you need to place the article into a folder before you can add additional fields'));
    }
    else if(error == 'UIDMISSING')
    {
        userMessage(i18n.get('The article must be saved and added to a folder before you can edit additional fields'));
    }
    else
    {
    }
    destroyPI();
}

function LZ_SubmitADFields (data)
{
    showPI(i18n.get('Saving...'));
    var reqData = '/admin/settings/admin/additionalfields/fieldModuleUpdate?';
    reqData = reqData+'module_name='+FieldEdit_Type;
    if(FieldEdit_UID != null)
    {
        reqData = reqData+'&module_id='+FieldEdit_UID;
        if($('#lz_revision_value').length)
        {
            reqData = reqData+'&revision='+$('#lz_revision_value').text();
        }
    }
    reqData = reqData+'&fields='+data.join(',');
    JSON_Request(reqData,LZ_ADFieldSuccess, LZ_ADFieldFailure);
    FieldEdit_Type = null;
    FieldEdit_UID = null;
}

function LZ_ADFieldSuccess (data)
{
    destroyPI();
}

function LZ_ADFieldFailure (data)
{
    destroyPI();
    return LZ_SaveFailure(data, 'Failed to submit field data: ');
}
