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
 * This file contains various javascript table-related helpers for Lixuz.
 *
 * These helpers assist in creating HTML tables and managing them.
 * They can be used to create quick and easy tables from raw JS data.
 */

function applyStyleToTable (id)
{
    var $tbl = id;
    if($.type($tbl) !== 'object')
    {
        $tbl = $('#'+id);
    }
    $tbl.addClass('listView');
    $tbl.find('th').addClass('rowHead');
    $tbl.find('tr').each(function(i)
    {
        var className = 'even';
        if (i %2 == 0)
        {
            className = 'odd';
        }
        $(this).addClass(className);
    });
}

/*
 * Summary: Generate a list-like table from two sets of arrays.
 *
 * headers is a one-level array of table headers with their names
 *
 * data_array is an array of arrays. The second-level arrays are lists of
 * column contents.
 *
 * Ex:
 * table = createTableFromData(['ID', 'Title'], [ [ 20, 'test' ], [ 21, 'test2' ] ]);
 */
function createTableFromData (headers,data_array)
{
    table = '<br /><table cellspacing="0" class="listView"><tr>';
    for (var i = 0; i < headers.length; i++)
    {
        table = table+'<td class="rowHead">'+headers[i]+'</td>';
    }
    table = table+'</tr>';
    for(var i = 0; i < data_array.length; i++)
    {
        var data = data_array[i],
        // Yes, this doesn't make sense, but we're zero-based while the layout
        // is based upon a layout that is 1-based, so it is reversed.
            className = 'even';
        if (i %2 == 0)
        {
            className = 'odd';
        }
        table = table + '<tr class="'+className+'">';
        for (var n = 0; n < data.length; n++)
        {
            table = table+'<td>'+data[n]+'</td>';
        }
        table = table+'</tr>';
    }
    table = table+'</table>';
    return table;
}

/*
 * Summary: Generate a list-like table from one array and one array of hashes.
 *
 * headers is the same as for createTableFromData.
 *
 * data is an array of hashes
 *
 * source is an array of software source names
 *
 * You may optionally also add the fourth option, it will make the first column
 * clickable. See below for the syntax.
 *
 * This is mostly useful to let it parse data directly returned from the server
 * for you.
 *
 * Ex:
 * table = createTableFromHashData(['ID','Title'], [ { "id":20, "title":"test" }, { "id":21, "title":"test2 } ], [ 'id','title' ]);
 *
 * -
 *
 * The syntax for the optional target_links:
 * {
 *  'target_column': { // Target is the column to insert the value into
 *      'source':'the name of the column to fetch the value from',
 *      'action':'the name of the javascript function to call',
 *      }
 *  }
 *  So, extending our example from above:
 * table = createTableFromHashData(['ID','Title'], [ { "id":20, "title":"test" }, { "id":21, "title":"test2 } ], [ 'id','title' ], { 'title': { source:'id', action: 'editTest' } });
 *
 * This will make the title column clickable with the id as the parameter
 * and editTest() as the action.
 */
function createTableFromHashData (headers, data_hash, source_ids, target_links)
{
    var final_data = {};
    if(target_links == null || target_links == undefined)
    {
        target_links = {};
    }

    for(var i = 0; i < data_hash.length; i++)
    {
        var this_array = [],
            this_hash = data_hash[i];
        for(var n = 0; n < source_ids.length; n++)
        {
            var id = source_ids[n],
                content = this_hash[id];
            if(content == null || content == undefined)
            {
                content = '';
            }
            if(target_links[id])
            {
                var action = target_links[id],
                    extra = '<a href="#" onclick="'+action.action+'(\''+this_hash[action.source]+'\'); return false">';
                content = extra+content+'</a>';
            }
            this_array.push(content);
        }
        if(this_array.length > 0)
        {
            final_data.push(this_array);
        }
    }
    return createTableFromData(headers,final_data);
}

/*
 * Summary: Generate a grid-like table from a single array of HTML strings
 */
function createTableGridFromData(grid, itemsPerLine)
{
    if(grid.length > 100)
    {
        lzError('grid length is way too high ('+grid.length+')',null,true);
    }
    if (!itemsPerLine)
    {
        itemsPerLine = 4;
    }
    var html = '<br /><table cellspacing="0"><tr>';
    for(var item = 0; item < grid.length; item++)
    {
        var thisitem = grid[item];
        html = html+'<td valign="middle" style="vertical-align: middle;">'+thisitem+'</td>';
        if((item != 0) && ((item + 1) % itemsPerLine) == 0)
        {
            html = html +'</tr><tr>';
        }
    }
    html = html+'</tr></table>';
    return html;
}

var managedChecklistData = null;

/*
 * Summary: Create a checklist-like table from two sets of arrays
 *
 * If type == 'table' (default if not supplied) then
 * this table has a checklist in the first column, whose values will
 * be based on the second column (the first column in data_array).
 *
 * If type == 'grid' then it will be a file-like grid with a checkbox
 * beside each item. In type == grid, the headers param is ignored, and
 * the data_array param is assumed to be an array of HTML strings, rather
 * than array of arrays.
 *
 * When you are done with the table you can do
 *  getdataFromChecklistTable(id);
 * to get an array if ids that are checked.
 *
 * Ex:
 * table = createManagedChecklistTable ('mychecklist',['ID','Title'], [ [ 20, 'test' ], [ 21, 'test2' ] ]);
 *      Gives you the table (with the first column being named &nbsp; and containing checkbuttons).
 * When you are done you do:
 * data = getdataFromChecklistTable(id);
 *      Gives you the previously mentioned array.
 *
 * You can also do
 * data = destroyChecklistTable(id);
 *      This first gets the data from the checklist, saves it temporarily, deletes
 *      the primary source and then returns the data. Use this when you are done with
 *      the table (not before, if you keep using a table with this id, without doing a
 *          createManagedChecklistTable, then what the user sees will differ
 *          from the internal data).
 */
function createManagedChecklistTable (id,headers,data_array,type)
{
    try
    {
        if(type != 'grid')
        {
            type = 'table';
        }
        else
        {
            headers = [];
        }
        var myGrid = [];
        if(managedChecklistData === null)
        {
            managedChecklistData = {};
        }
        var dataEntry = managedChecklistData[id];
        if (!dataEntry)
        {
            dataEntry = {};
            managedChecklistData[id] = dataEntry;
        }
        headers.unshift('&nbsp;');
        for(var i = 0; i < data_array.length; i++)
        {
            var inst = data_array[i],
                myid = inst[0],
                checked = '';
            if(dataEntry[myid] === true)
            {
                checked = 'checked="checked" ';
            }
            var checkListAction = 'checklistTableToggleChecked(\''+id+'\',\''+myid+'\');',
                checkListHTML = '<input type="checkbox" onchange="'+checkListAction+'" id="ckl_'+id+'_'+myid+'" '+checked+'/>';
            if(type == 'grid')
            {
                myGrid.push(checkListHTML);
                myGrid.push('<a href="#" onclick="$(\'#ckl_'+id+'_'+myid+'\').click(); return false;">'+inst[1]+'</a>');
            }
            else
            {
                inst.unshift(checkListHTML);
            }
        }
        if(type == 'grid')
        {
            return createTableGridFromData(myGrid,6);
        }
        else
        {
            return createTableFromData(headers,data_array);
        }
    }
    catch(e)
    {
        lzException(e);
    }
}

/*
 * Summary: Get data from a previously created checklist table.
 *
 * Returns an array if ids that are checked.
 */
function getdataFromChecklistTable (id)
{
    var data = managedChecklistData[id],
        myArr = [];
    if(data)
    {
        $.each(data, function (key,value)
        {
            if(value === true)
            {
                myArr.push(key);
            }
        });
    }
    return myArr;
}

/*
 * Summary: Get data from and destroy a checklist table
 *
 * Returns an array if ids that are checked.
 */
function destroyChecklistTable (id)
{
    var data = getdataFromChecklistTable(id);
    delete managedChecklistData[id];
    return data;
}

function checklistTableSetChecked(table_id, id, value)
{
    var entryID = 'ckl_'+table_id+'_'+id;
    var entry = $('#'+entryID)[0],
        dataEntry = managedChecklistData[table_id];
    if (!dataEntry)
    {
        dataEntry = {};
        managedChecklistData[table_id,dataEntry];
    }
    if (!entry)
    {
        lzError('Failed to locate entry '+entryID,null,true);
    }

    entry.checked = value;
    checklistTableToggleChecked(table_id,id);
}

/*
 * Checklist onchange event handler
 */
function checklistTableToggleChecked(table_id,id)
{
    var entryID = 'ckl_'+table_id+'_'+id;
    var entry = $('#'+entryID)[0],
        dataEntry = managedChecklistData[table_id];
    if (!dataEntry)
    {
        dataEntry = {};
        managedChecklistData[table_id] = dataEntry;
    }
    if (!entry)
    {
        lzError('Failed to locate entry '+entryID,null,true);
    }
    if(entry.checked)
    {
        dataEntry[id] = true;
    }
    else
    {
        dataEntry[id] = false;
    }
    return true;
}
