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
 * Backup handler
 *
 * This can currently only handle one backup per instance, but can
 * probably easily be extended if it should become required at
 * some point.
 *
 * Requires: utils/serverPolling.js utils/contentTracker.js
 */

var backup_lastSubmittedPayloadData = '',
    backup_dataFunction,
    backup_sourceType;

/*
 * *************
 * Saving backups
 * *************
 */

/*
 * Backup initialization function.
 *
 * Takes two parameters:
 * dataFunction is the function that it should use to retrieve data.
 * type is the name of the module that is requesting backups (ie. 'article').
 */
function backup_init (dataFunction,type)
{
    backup_dataFunction = dataFunction;
    dataTrackingFunction = backup_getBackupData;
    backup_sourceType = type;
    /*
     * We put this on a timer, so that the initial payload is correct.
     * It might take the page a few seconds to initialize properly,
     * so the data can change without that actually meaning anything.
     *
     * If we don't do this, then we'll send in empty backup data,
     * which isn't useful at all.
     */
    setTimeout('backup_setInitialPayload()',3000);
    pollServer_payloadFunction = backup_pollHandler;
    return true;
}

/*
 * Set our initial payload data, used for checking if
 * the data has changed since the page was loaded
 */
function backup_setInitialPayload ()
{
    updateTrackPoint('backup',false);
    updateTrackPoint('save',false);
}

/*
 * Handles requests from the polling handler
 */
function backup_pollHandler (response)
{
    if(response == POLLSERVER_PAYLOAD_GET)
    {
        var data = backup_getBackupData(),
            artid = $('#lixuzArticleEdit_uid').val();
        if(changedSince('backup'))
        {
            backup_lastSubmittedPayloadData = data;
            return data+'&article_id='+artid;
        }
        else
        {
            return 'article_id='+artid;
        }
    }
    else if(response == POLLSERVER_PAYLOAD_SUCCESS)
    {
        if(backup_lastSubmittedPayloadData != '')
        {
            updateTrackPoint('backup',false,backup_lastSubmittedPayloadData);
            backup_lastSubmittedPayloadData = '';
            if($('#lastBackedUpAt').val() != null)
            {
                try
                {
                    var dt = new Date();
                    $('#lastBackedUpAt').html('<i>'+i18n.get_advanced('Last backed up at %(date)',  { 'date': dt.toLocaleString() })+'</i>');
                }
                catch(e) {}
            }
        }
        if(arguments[1] != null)
        {
            var reply = arguments[1];
            if(reply.keepLock)
            {
                articleKeepLockStatus(reply.keepLock,reply);
            }
        }
        return true;
    }
    else if(response == POLLSERVER_PAYLOAD_FAILURE)
    {
        return backup_handleError(arguments[1]);
    }
    else
    {
        lzError('Unknown parameter to backup_pollHandler(): '+response+' - returning null');
        return null;
    }
}

/*
 * Polling error handler
 */
function backup_handleError (reply)
{
    backup_lastSubmitttedPayloadData = '';
    var error = LZ_JSON_GetErrorInfo(reply,null);
}

/*
 * Function that returns the ready-made JSON+URI-stringified version of the
 * current data
 */
function backup_getBackupData ()
{
    var data,
        returnData = 'backupSource='+backup_sourceType+'&backupData=';
    try
    {
        data = backup_dataFunction();
        returnData = returnData+encodeURIComponent($.toJSON(data));
        returnData = returnData+'&backupMainUID='+encodeURIComponent(data['primaryID']);
    }
    catch(e)
    {
        returnData = '';
        lzException(e,'Error while constructing backup payload data.');
    }
    return returnData;
}

/*
 * *************
 * Restoring backups
 * *************
 */
var backup_restore_layout;

/*
 * Restore a backup. Takes three parameters.
 *
 * layout is a hash in the following form:
 * { // backup_restore
 *   subcomponent: {
 *      name : realname
 *      },
 * }
 * The hash in subcomponent can be null, but subcomponent
 * is required. subcomponent is the name of a data source in the backup data,
 * and the name : realname mapping is the map of field values in the backup data
 * to field values on the page. Ie.:
 * {
 *      article: {
 *          uid: 'lixuzArticleEdit_uid'
 *          }
 * }
 * It is the reverse of the convertNames hash supplied to getFieldItems().
 *
 * type is the type name, same as supplied to backup_init()
 *
 * uid is the uid of the item you want to restore, this can be null.
 */
function backup_restore (layout,type,uid)
{
    showPI(i18n.get('Restoring backup...'));
    backup_restore_layout = layout;
    var requestURI = '/admin/services/backup?type='+encodeURIComponent(type)+'&uid='+encodeURIComponent(uid);
    JSON_Request(requestURI,backup_restore_reply,backup_restore_replyError);
}

/*
 * Handles the reply from the server, performs the
 * actual restoration
 */
function backup_restore_reply (reply)
{
    reply = reply;
    $.each(backup_restore_layout, function (l_key, l_value)
    {
        var inBackup = reply[l_key];
        if (!inBackup)
        {
            lzError(l_key+' was missing from the backup! That\'s not good, attempting to restore what I got');
            return;
        }
        inBackup = inBackup;
        l_value = l_value;
        $.each(inBackup, function (e_key, e_value)
        {
            var obj;
            if (l_value && l_value[e_key])
            {
                // If the value is the boolean 'false', then we ignore this one
                var val = l_value[e_key];
                if(val == false)
                {
                    return;
                }
                obj = $('#'+val).first();
            }
            else
            {
                obj = $('#'+e_key).first();
            }
            if (!obj)
            {
                var valstring = new String(e_value);
                // Ignore the error if the field was empty
                if(valstring.length > 0 || e_value)
                {
                    var ts = new String(e_key);
                    // TODO: i18n
                    if(e_key.match(/^adfield/i))
                    {
                        userMessage('An additional field ('+e_key+') was not found. It might have been removed from the page since this backup was created. The fields value will not be restored. <br/><br/><br /> (its value was: "'+e_value+'")');
                    }
                    else
                    {
                        lzError('Failed to locate form entry: '+e_key);
                    }
                }
                return;
            }
            backup_restore_valueToObj(e_value,obj);
        });
    });
    // Reset the initial payload data to the recently restored one, but only
    // if we already have some payload data set.
    if(trackPointExists('backup') && backup_dataFunction != null)
    {
        backup_setInitialPayload();
    }
    // We have done stuff to the page, so kill saved state
    updateTrackPoint('save',false,'');

    // Display final information message to the user
    userMessage(i18n.get('The backup has been fully restored. Note that any changes made by other users since this backup was created (other than comments) will be lost if you save it.'));
    destroyPI();
}

/*
 * Handles restoring a single value to a single object
 */
function backup_restore_valueToObj (value, obj)
{
    try
    {
        if(obj.tagName.match(/^textarea$/i))
        {
            var editor;
            // Fetch the editor, this will work even if this page has no editors at all
            // (and thus no editors hash).
            try { editor = editors[obj.id]; } catch(e){}

            // Perform editor processing
            if (editor != null)
            {
                var doc = editor._getDoc();
                if (!doc)
                {
                    throw('Document inside editor is missing');
                }
                var body = doc.body;
                if (!body)
                {
                    // No body? Create it
                    body = doc.createElement('body');
                }
                body.innerHTML = value;
            }
            obj.value = value;
        }
        // Handle checkboxes
        else if(obj.type == 'checkbox')
        {
            if(value)
            {
                obj.checked = true;
            }
            else
            {
                obj.checked = false;
            }
        }
        // 'catch all' for all other objs
        else
        {
            try
            {
                obj.value = value;
            }
            catch(e)
            {
                var type = 'unknown';
                try{type = obj.type;} catch(e) {}
                userMessage('Error while setting data to obj "'+fname+'" (this is a bug): '+e.message+"\n\nDumping some info:\n tagName="+obj.tagName+"\n.type:"+type);
            }
        }
    }
    catch(e)
    {
        var field = '(unknown)';
        try { field = obj.id; } catch(e) { try { field = obj.name; } catch(ee) { } }
        value = value.replace(/&/g,'&amp;');
        value = value.replace(/</g,'&lt;');
        value = value.replace(/>/g,'&gt;');
        lzException(e,'Restoration of the field '+field+' failed. Attempted to set to the following value: '+value);
    }
}

/*
 * Error handler
 */
function backup_restore_replyError (reply)
{
    var error = LZ_JSON_GetErrorInfo(reply,null);
    if(error == 'NODATA')
    {
        userMessage(i18n.get('No backup data was found on the server that matched this dataset.'));
    }
    else
    {
        LZ_SaveFailure(reply,i18n.get('Failed to retrieve backup data: '));
    }
    destroyPI();
}
