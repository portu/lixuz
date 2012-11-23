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
 * JavaScript for the edit additional fields page
 *
 * Copyright (C) Portu media & communications
 * All Rights Reserved
 *
 * Needs: asyncHelper.js
 */

var LZ_FieldForward;

function LZ_ValidateRange ()
{
    var $sel = $('#rangeselection');
    if ($sel.length < 0 || $sel.css('display') == 'none')
        return true;
    var range = $('#range').val();
    if (! range.match(/^\s*\d+\s*-\s*\d+\s*$/))
    {
        userMessage(i18n.get('The range is invalid. It must be in the form: FROM-TO (ie. 20-40)'));
        return false;
    }
    var rangeMin = range.replace(/\D.*$/,'');
    var rangeMax = range.replace(/^\d+\D/,'');
    if(rangeMin > rangeMax)
    {
        userMessage(i18n.get('The minimum range can not be higher than the maximum range'));
        return false;
    }
    return true;
}

function LZ_FieldTypeChanged ()
{
    $('#heightselection').css('display','none');
    $('#rangeselection').css('display','none');
    $('#rteselection').css('display','none');
    $('#valuesselection').css('display','none');
    if ($('#type').val() == 'multiline')
    {
        $('#heightselection').css('display','block');
        $('#rteselection').css('display','block');
    }
    else if ($('#type').val().match(/^range/))
    {
        $('#rangeselection').css('display','block');
    }
    else if ($('#type').val() == 'user-pulldown' || $('#type').val() == 'multi-select')
    {
        $('#valuesselection').css('display','block');
    }
}

function LZ_FieldSaveAndClose ()
{
    LZ_FieldForward = '/admin/settings/admin/additionalfields';
    return LZ_FieldSave();
}

function LZ_FieldSave ()
{
    var fields = ['name','type','uid'];
    var reqData = '_submit=JSON';

    showPI(i18n.get('Saving...')); // Show progress indicator

    if ($('#type').val().match(/^range/))
    {
        fields.push('range');
        if (!LZ_ValidateRange())
        {
            destroyPI();
            return;
        }
    }
    else if ($('#type').val() == 'multiline')
    {
        fields.push('height');
        fields.push('rte');
    }
    else if ($('#type').val() == 'user-pulldown' || $('#type').val() == 'multi-select')
    {
        fields.push('values');
    }

    for(var i = 0; i < fields.length; i++)
    {
        var field = $('#'+fields[i])[0];
        if (!field)
        {
            continue;
        }
        if (!field.value.length && fields[i] != 'uid')
        {
            destroyPI();
            userMessage(i18n.get('All fields must be filled in.'));
            return;
        }
        var value;
        if(field.type == 'checkbox')
        {
            value = field.checked ? 'true' : 'false';
        }
        else
        {
            value = field.value;
        }
        reqData = reqData+'&'+field.name+'='+encodeURIComponent(value);
    }
    XHR.Form.POST('/admin/settings/admin/additionalfields/submit', reqData, LZ_FieldSaveSuccess, LZ_FieldSaveFailure);
}

function LZ_FieldSaveSuccess (data)
{
    $('#uid').val(data.uid);
    if(LZ_FieldForward)
    {
        location.href = LZ_FieldForward;
    }
    else
    {
        $('#typeselection').css({'display':'none', 'visibility':'hidden'});
    }
    destroyPI(); // Destroy progress indicator
}

function LZ_FieldSaveFailure (data)
{
    LZ_FieldForward = null;
    // LZ_SaveFailure will destroy the progress indicator for us
    return LZ_SaveFailure(data, i18n.get('Failed to submit field data: '));
}
