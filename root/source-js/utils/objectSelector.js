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
 * This is a utility for building selectors.
 * It lets you create both filtering and basic object selectors,
 * and handles most of the magic for you.
 *
 * If you are simply looking to use an existing selector you might be
 * better off grepping for the function you want to use, or if you're
 * looking for the fileSelector, have a look at files/fileSelector.js
 */

/* What to do onDone */
var LZ_OS_onDone,
/* The current URL to request additional data from */
    LZ_OS_currentURL,
/* The current request type (ie. file) */
    LZ_OS_currReqType,
/* The current page, also used as a cache id and to keep track of 'next' pages */
    LZ_OS_currPage = 1,
    LZ_OS_buttons,
    LZ_OS_windowTitle,
/* The dialog itself */
    objectSelectorDialog,
/* Manual filtering string */
    LZ_OS_ManualFilterString = null,
/* True if this is the initial filtering, false otherwise.
 * Used to tell LZ_OS_GetFilteredData if it should display the 'Filtering ...'
 * dialog or not. It is reset to true each time a new object selector
 * is created.*/
    LZ_OS_IsFirstLoad,

    LZ_OBJ_listCreator,

/*
 * This is a hash of key => value pairs where the key matches an id
 * in the DOM, and the value is the variable this should be assigned
 * to in the URL (LZ_OS_currentURL)
 */
    elementToFilterKey,

/*
 * INTERNAL
 *
 * the *Selector functions can be used to build new selectors
 */

// Our data cache, a hash of url => data values
    dataCache;

/*
 * Compatibility wrapper around newFilteringObjectSelector that
 * emulates the old behaviour of newObjectSelector
 */
function newObjectSelector (onDone,defaultFolder,requestURL,type)
{
    deprecated(getCallerName(arguments));
    showPI('Loading folder data ...<br />Note: Using legacy newObjectSelector(),<br />this function is deprecated');
    requestURL = requestURL.replace(/&[^&=]+=$/,'');
    return newFilteringObjectSelector(onDone,requestURL,type,"/admin/services/jsFilter?source=onlyFolders&defaultFolder="+defaultFolder);
}

/*
 * Creates a new object selector. This is a dialog box that provides the user
 * with a list of entries, a means to filter those entries and simple
 * pagination.  It can ie. be used as a OS-like file selector dialog.
 *
 * Parameters:
 * onDone       The function to be called when the user clicks on an object.
 * requestURL   The URL to request the list from. This will recieve an optional
 *              list of filters, as well as a page parameter to specify
 *              where in the pagination we are.
 * type         This is the type of data we're handling, ie. file, article
 * filterURL    This is the URL that the selector will query for a list
 *              of filters.
 * listCreator  The function to use to actually create a list from the
 *              returned data. This can be null, if it is then the usual
 *              files_grid string is used.
 *
 * The data returned by filterURL should be in the filterData key of the
 * returned JSON object.
 *
 * Syntax (mostly corresponds to the same in root/adm/core/searchAndFilter.html):
 * [
 *      {
 *          name => 'Human, localized name to be displayed in the list',
 *          realName => 'the name of the parameter to contain the data in requestURL',
 *          options => [ - array of zero or more of the following hashes:
 *                  {
 *                      value => the value to be supplied in the realName parameter,
 *                      label => the label to be shown to the user,
 *                  },
 *              ],
 *          filterName => 'name',
 *          selected => 'the selected value in the list', if missing the (any) will be selected,
 *          exclusiveLine => bool, if true then this option will be allowed to fill up an entire
 *                  line on its own, useful for instance for folders
 *      },
 * ]
 */
function newFilteringObjectSelector (onDone, requestURL, type, filterURL, buttons, listCreator, windowTitle)
{
    LZ_OS_onDone = onDone;
    LZ_OS_currentURL = requestURL;
    LZ_OS_currReqType = type;
    LZ_OS_IsFirstLoad = true;
    LZ_OS_windowTitle = windowTitle;
    if(buttons)
    {
        LZ_OS_buttons = buttons;
    }
    else
    {
        LZ_OS_buttons = null;
    }
    if(listCreator)
    {
        LZ_OBJ_listCreator = listCreator;
    }
    else
    {
        LZ_OBJ_listCreator = LZ_OS_BasicListEntries;
    }
    dataCache = {};
    showPI(i18n.get('Loading filtering rules...'));
    XHR.GET(filterURL,LZ_OS_FilterReply,null);
}

/*
 * Function to generate the HTML to list filtereing rules on top
 * of the dialog. Returns the html string.
 */
function LZ_OS_GenerateFilterHTML(form)
{
    var data = form.filterData,
        html = '<form id="jsfilterTempForm" onsubmit="LZ_OS_FilterHasChanged(null); return false">';
    elementToFilterKey = {};
    try
    {
        for(var i = 0; i < data.length; i++)
        {
            var filter = data[i];
            html = html + '<span id="jsfilter'+filter.realname+'_container"><b>'+filter.name+': </b>';
            elementToFilterKey['jsfilter_'+filter.realname+'_select'] = filter.realname;
            html = html + '<select onchange="LZ_OS_FilterHasChanged(null); return true;" name="jsfilter_'+filter.realname+'_select" id="jsfilter_'+filter.realname+'_select">';
            html = html + '<option value="" ';
            if (! filter.selected)
            {
                html = html + 'selected="selected"';
            }
            html = html + '>';
            if(filter.anyString)
            {
                html = html + filter.anyString;
            }
            else
            {
                html = html + i18n.get('(any)');
            }
            html = html + '</option>';
            for(var n = 0; n < filter.options.length; n++)
            {
                var option = filter.options[n];
                html = html + '<option value="'+option.value+'" ';
                if(filter.selected && filter.selected == option.value)
                {
                    html = html + 'selected="selected"';
                }
                html = html + '>'+option.label+'</option>';
            }
            html = html + '</select>';
            if(filter.exclusiveLine)
            {
                html = html +'<br />';
            }
            else
            {
                html = html + '&nbsp;&nbsp;';
            }
            html = html + '</span>';
        }
    }
    catch(e)
    {
        lzException(e);
    }
    if(form.includeSearchBox)
    {
        if (! data.length || data.length < 1)
        {
            html = html +'<br /> <br />';
        }
        html = html + '<span style="width:100%"><input id="jsFilterSearch" type="text" value="" style="width:75%" onkeypress="alert(\"keypress\");if(window.event && window.event.keyCode == 13) { LZ_OS_FilterHasChanged(null);}" /> <input type="button" onclick="LZ_OS_FilterHasChanged(null); return false;" style="width:20%" value="'+i18n.get('Search')+'" /></span>';
    }
    html = html +'</form>';
    return html;
}

/*
 * Creates the main dialog and kicks off loading of the initial data
 */
function LZ_OS_FilterReply(form)
{
    try
    {
        var html = LZ_OS_GenerateFilterHTML(form);
        html = html+'<br /><br />';
        html = html+'<div id="objectSelectorPager" style="overflow: hide;">&nbsp;</div><br />';
        html = html+'<div id="objectSelectorContent" style="overflow:auto; height:60%;">';
        html = html+'<br /> <br /><br /><br /><center>'+i18n.get('Loading data...')+'</center>';
        html = html+'</div>';

        var dialogSettings = {
            'width': 600,
            buttons: LZ_OS_buttons,
            title: LZ_OS_windowTitle,
            'height': 500
        };

        objectSelectorDialog = new dialogBox(html,dialogSettings);
        destroyPI();
        LZ_OS_FilterHasChanged();
    }
    catch(e)
    {
        lzException(e);
    }
}

/*
 * Handles recieved, filtered and paginated data from the server
 */
function LZ_OS_RecievedFilteredData (data)
{
    var entries = LZ_OS_GetListEntries(data);
    if(entries == null || entries == undefined)
    {
        lzError('LZ_OS_GetListEntries returned undefined! Stringified: '+getFuncNameFromOutput(LZ_OS_GetListEntries.toString()));
    }
    $('#objectSelectorContent').html(entries);
    if(data.URL)
    {
        dataCache[data.URL] = data;
    }
    LZ_OS_ObjectPager(data);
    destroyPI();
}

function destroyObjectSelector ()
{
    try
    {
        objectSelectorDialog.hide();
        objectSelectorDialog.destroy();
    }
    catch(e){}
    objectSelectorDialog = null;
}

/*
 * Called whenever a filter changes. Resets LZ_OS_ManualFilterString and
 * then calls LZ_OS_GetFilteredData(null);
 */
function LZ_OS_FilterHasChanged ()
{
    LZ_OS_ManualFilterString = null;
    LZ_OS_GetFilteredData(null);
}

function currObjSelectorAddFilter (filterString)
{
    LZ_OS_ManualFilterString = filterString;
    LZ_OS_GetFilteredData(null);
}

function currObjSelectorAddDestructiveFilter (filterString)
{
    $('#jsFilterSearch').val('');
    $.each(elementToFilterKey, function(key,value)
    {
        var obj = $('#'+key).val(null);
    });
    currObjSelectorAddFilter(filterString);
}

/*
 * Recieve filtered data, optionally page N of that data.
 * This will fetch from the cache if there is any, otherwise
 * it'll query the server for the data.
 */
function LZ_OS_GetFilteredData (page)
{
    if(page == null)
    {
        page = 1;
    }

    var URL = LZ_OS_currentURL;
    $.each(elementToFilterKey, function(key,value)
    {
        var obj = $('#'+key);
        if(!obj[0])
        {
            lzError('Failed to locate "#'+key+'" using $() in LS_OS_GetFilteredData');
            return;
        }
        if(obj.val() && obj.val().length > 0)
        {
            URL = URL +'&filter_'+encodeURIComponent(value)+'='+encodeURIComponent(obj.val());
        }
    });
    var search = $('#jsFilterSearch').first();
    if(search && search.val().length)
    {
        URL = URL + '&query='+encodeURIComponent(search.val());
    }
    else
    {
        URL = URL + '&query=';
    }
    if(LZ_OS_ManualFilterString != null)
    {
        URL = URL + '&'+LZ_OS_ManualFilterString;
    }
    URL = URL +'&page='+page+'&_submitted_list_search=1';

    if (!dataCache[URL])
    {
        if(LZ_OS_IsFirstLoad)
        {
            LZ_OS_IsFirstLoad = false;
        }
        else
        {
            showPI(i18n.get('Filtering...'));
        }
        XHR.GET(URL,LZ_OS_RecievedFilteredData,null);
    }
    else
    {
        LZ_OS_RecievedFilteredData(dataCache[URL]);
    }
}

/*
 * Handler for data recieved for newBasicObjectSelector
 */
function displayBasicData (reply)
{
    destroyPI();
    $('#objectSelectorContent').html(LZ_OS_GetListEntries(reply));
}

/*
 * Gets the entry for a list, properly formatted even if there isn't
 * any data.
 */
function LZ_OS_GetListEntries (data)
{
    var entry;
    if(data == null || ( data.files_grid == null && data.contents == null))
    {
        var myString;
        if (LZ_OS_currReqType == 'file')
        {
            myString = i18n.get('No files found matching the current filters');
        }
        else if(LZ_OS_currReqType == 'article')
        {
            myString = i18n.get('No articles found matching the current filters');
        }
        else
        {
            myString = i18n.get('No entries found matching the current filters');
        }
        entry = '<br /><br /><br /><br /><center>'+myString+'</center><br /><br /><br /><br />';
    }
    else
    {
        if (! LZ_OBJ_listCreator)
        {
            lzError('LZ_OBJ_listCreator missing/undefined',null,true);
        }
        entry = LZ_OBJ_listCreator(data);
    }
    return entry;
}

/*
 * The basic list entry fetching function
 */
function LZ_OS_BasicListEntries(data)
{
    if(data.files_grid == null || data.files_grid == undefined)
    {
        return LZ_OS_GenericGenerator(data);
    }
    return '<table width="100%" cellspacing="0" id="fileGrid"><tr>'+data.files_grid+'</tr></table>';
}

/*
 * Generic development list generator
 */
function LZ_OS_GenericGenerator(data)
{
    var headers = [],
        contents = data.contents[0];
    $.each(data.contents[0], function(key,value)
    {
        headers.push(key);
    });
    var myData = [];
    for(var i = 0; i < data.contents.length; i++)
    {
        var entry = data.contents[i],
            fullEntry = [];
        for(var n = 0; n < headers.length; n++)
        {
            fullEntry.push(entry[headers[n]]);
        }
        myData.push(fullEntry);
    }
    return createManagedChecklistTable('genericList',headers,myData);
}

/*
 * Action that gets called when the user clicks on an object 
 */
function LZ_OS_ObjectClicked (object_id)
{
    try
    {
        objectSelectorDialog.hide();
        objectSelectorDialog.destroy();
    }
    catch(e){}
    if(LZ_OS_onDone)
    {
        try
        {
            LZ_OS_onDone(object_id);
        }
        catch(e)
        {
            lzException(e);
        }
    }
    else
    {
        lzError('LZ_OS_onDone is missing, I have no idea what to do with this object_id');
    }
    return false;
}

/*
 * Function that creates the pager section
 */
function LZ_OS_ObjectPager (data)
{
    var page = 1,
        pages = 1;
    if(data.pager != null && data.pager.page != null)
    {
        page = parseInt(data.pager.page);
        pages = parseInt(data.pager.pageTotal);
    }

    LZ_OS_currPage = page;

    var content = '<div style="float: right" id="innerObjectSelectorPagerDiv">';
    if(page > 1)
    {
        var prev = page - 1;
        content = content + '<a href="#" onclick="LZ_OS_SwitchToPage('+prev+'); return false;">';
    }
    content = content + i18n.get('Previous');
    if(page > 1)
    {
        content = content + '</a>';
    }
    content = content + '&nbsp;&nbsp;[ '+page+' '+i18n.get('of')+' '+pages+' ]&nbsp;&nbsp;';
    if(pages > 1 && page < pages)
    {
        var next = page + 1;
        content = content + '<a href="#" onclick="LZ_OS_SwitchToPage('+next+'); return false;">';
    }
    content = content + i18n.get('Next');
    if(pages > 1 && page < pages)
    {
        content = content + '</a>';
    }
    content = content + '&nbsp;&nbsp;';
    $('#objectSelectorPager').html(content);
}

/*
 * Switch to the page supplied
 */
function LZ_OS_SwitchToPage (page)
{
    LZ_OS_GetFilteredData(page);
}
