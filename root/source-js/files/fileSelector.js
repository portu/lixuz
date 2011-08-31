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
 * OS-like file-selector
 *
 * Needs: objectSelector.js asyncHelper.js tables.js (if you want multi support)
 */

var fileSelector_OnDoneAction;

/*
 * Creates a new file selector. onDone is the function you want to have
 * called when the user clicks on a file in the file selector. The function
 * will be called with the file_id
 */
function newFileSelector (onDone,defaultFolder)
{
    return newFilteringObjectSelector(onDone,"/admin/files?",'file',"/admin/services/jsFilter?source=files&defaultFolder="+defaultFolder,null,null,i18n.get('File selector'));
}

/*
 * Creates a new multi-file selector. The only difference from newFileSelector
 * is that this will supply onDone with an array of file_id's instead of
 * a single ID (and it needs tables.js to handle this).
 */
function newMultiFileSelector (onDone, defaultFolder)
{
    fileSelector_OnDoneAction = onDone;
    var buttons = {};
    buttons[i18n.get('Add files')] = LZ_multiFileOK;
    return newFilteringObjectSelector(onDone,'/admin/files?list_type=pure&','file',"/admin/services/jsFilter?source=files&defaultFolder="+defaultFolder,buttons,LZ_multiFileListCreator,i18n.get('File selector'));
}

function LZ_multiFileOK ()
{
    try
    {
        destroyObjectSelector();
        var elements = destroyChecklistTable('fileSelectorList');
        fileSelector_OnDoneAction(elements);
        fileSelector_OnDoneAction = null;
    }
    catch(e) { lzException(e); }
}

function LZ_multiFileListCreator (data)
{
    return createManagedChecklistTable('fileSelectorList',null,data.contents,'grid');
}
