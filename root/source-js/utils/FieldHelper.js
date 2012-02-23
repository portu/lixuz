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
 * JavaScript that can assist in various tasks related to
 * fields.
 *
 * Copyright (C) Portu media & communications
 * All Rights Reserved
 */

/*
 * Validates the supplied field. Used both by the fields
 * themselves to do on-the-fly validation, but also during submission
 * to check that they are valid.
 */
function LZ_Validate_ADField (field)
{
    if (!field)
    {
        return true;
    }
    if(field.getAttribute('obligatory') == 'true')
    {
        if (! LZ_ADF_valueRequired(field))
        {
            return false;
        }
    }
    var adtype = field.getAttribute('adtype');
    if (!adtype)
    {
        return true;
    }
    if (adtype == 'range')
    {
        return LZ_ADF_validate_range(field);
    }
    else if(adtype == 'datetime')
    {
        return LZ_ADF_validate_datetime(field);
    }
    else
    {
        return true;
    }
}

/*
 * Gets a list of fields and their values on the page.
 * The single parameter noValidation decides if it validates or not.
 * If it is not true then it will run values through LZ_Validate_ADField(),
 * and if the value does not validate, a message will be displayed to the
 * user, and this function will return false, rather than the normal
 * hash of values it usually returns.
 */
function LZ_ADField_GetFields (noValidation)
{
    var fieldList = LZ_ADF_getFieldList(),
        realFieldList = [],
        validationFailure = false;
    $.each(fieldList, function(index,item)
    {
        if(!noValidation && LZ_Validate_ADField($('#adfield_'+item)[0]) == false)
        {
            validationFailure = true;
            return false;
        }
        realFieldList.push('adfield_'+item);
    });
    if(validationFailure)
    {
        return false;
    }
    var fields = getFieldItems(realFieldList);
    if (!fields)
    {
        var empty = {};
        return empty;
    }
    else
    {
        return fields;
    }
}

function LZ_ADF_fieldName (field)
{
    try
    {
        var id = field.id,
            name,
            element = $('#'+id+'_label');
        if (element.length)
        {
            name = element.val();
            name.replace(/<[^>]+>/g,'');
        }
        if (!name)
        {
            name = id;
        }
        return name;
    }
    catch(e)
    {
        return '(unknown - exception occurred in LZ_ADF_fieldName)';
    }
}

/*
 * Converts a inline field name to an DOM object
 */
function LZ_ADF_getInlineField (field)
{
    // FIXME: This does a lot more than it needs to, jQuery can already query by attribute value.
    var fieldList = LZ_ADF_getFieldList(),
        ret;
    try
    {
        $.each(fieldList, function (index,item)
        {
            if(ret == null)
            {
                var obj = $('#adfield_'+item)[0];
                if ( (obj != null) && (obj.getAttribute('adinline') == field))
                {
                    ret = obj;
                }
            }
        });
    }
    catch(e)
    {
        lzException(e);
    }
    if(ret)
    {
        return ret;
    }
    else
    {
        return undefined;
    }
}

/*
 * Lixuz version of $('#SOMEOBJ')[0]. This one will first try to locate an object
 * with that ID, then it will attempt to look up an additional field.
 * If both fails, it will return undefined.
 */
function $L (id)
{
    var o = $('#'+id)[0];
    if (o)
    {
        return o;
    }
    else
    {
        return LZ_ADF_getInlineField(id);
    }
}


function LZ_ADF_getFieldList ()
{
    var fieldList;
    try
    {
        fieldList = additionalFields;
    }
    catch(e)
    {
        lzError('ERROR: additionalFields array missing!');
        return null;
    }
    return fieldList;
}

/*
 * **************************
 * Field validation functions
 * **************************
 */

function LZ_ADF_valueRequired (field)
{
    var value = getFieldData(field.id);
    if(value == '' || value == null)
    {
        var name = LZ_ADF_fieldName(field);
        userMessage(i18n.get_advanced('The field "%(field)" must be filled in.', { 'field': name }));
        return false;
    }
    return true;
}

function LZ_ADF_validate_datetime (field)
{
    if (!field.value || field.value.length < 1)
    {
        return true;
    }
    if (/\d?\d\.\d?\d\.\d\d\d\d\s+\d?\d:\d?\d/.test(field.value))
    {
        return true;
    }
    var name = LZ_ADF_fieldName(field);
    userMessage(i18n.get_advanced('The field "%(field)" contains an invalid date.', { 'field': name }));
    return false;
}

/*
 * Validate a range
 */
function LZ_ADF_validate_range (field)
{
    var rangeAllowed = field.getAttribute('rangeAllowed');
    if (!rangeAllowed || rangeAllowed.length <= 3)
    {
        return true;
    }
    var rangeMin = rangeAllowed.replace(/\D.*$/,''),
        rangeMax = rangeAllowed.replace(/^\d+\D/,'');
    if (!rangeMin)
    {
        lzError('LZ_Validate_ADField: Failed to fetch rangeMin from rangeAllowed='+rangeAllowed+' - validation of field impossible');
        return true;
    }
    if (!rangeMax)
    {
        lzError('LZ_Validate_ADField: Failed to fetch rangeMax from rangeAllowed='+rangeAllowed+' - validation of field impossible');
        return true;
    }
    if(rangeMax < rangeMin)
    {
        lzError('LZ_Validete_ADField: Got strange range that doesn\'t make sense (rangeAllowed='+rangeAllowed+') - validation of field impossible');
        return true;
    }
    if (!field.value || field.value.length < 1)
    {
        return true;
    }
    var splitRanges = field.value.split(/(\s+|,|-)/),
        userRanges = [];
    for(var i = 0; i < splitRanges.length; i++)
    {
        var value = splitRanges[i];
        value = value.replace(/(\s+|,|-)*/,'');
        if(value.match(/\D/))
        {
            userMessage(
                    i18n.get_advanced(
                        'The field "%(FIELD)" does not validate. You can enter ranges (like 0-10) or numbers separated by commas (like 1, 2, 3)',
                        { 
                            'FIELD': field.name
                        }));
            return false;
        }
        if(value.length < 1)
        {
            continue;
        }

        userRanges.push(value);
    }
    if (!userRanges.length > 0)
    {
        return false;
    }
    for(var i = 0; i < userRanges.length; i++)
    {
        var value = userRanges[i];
        if(value > rangeMax || value < rangeMin)
        {
            userMessage(i18n.get_advanced('The value for the field "%(FIELD)" must be within the range %(MIN)-%(MAX)', { 
                    'FIELD': field.name,
                    'MIN'  : rangeMin,
                    'MAX'  : rangeMax}));
            return false;
        }
    }
    return true;
}
