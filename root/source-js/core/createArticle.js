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
 * *************
 * New article, needs to be available on all pages
 * *************
 */
function LZ_NewArticle ()
{
    try
    {
        showPI(i18n.get('Loading folder and template data ...'));
        JSON_multiRequest(['/admin/services/folderList','/admin/services/templateList'], { 
            'template_type':'article',
            'require':'write'
                },LZ_DisplayNewArticleForm,null);
    }
    catch(e)
    {
        destroyPI();
        lzException(e);
    }
    return false;
}
function LZ_DisplayNewArticleForm(form)
{
    try
    {
        destroyPI();
        var folderList = form['/admin/services/folderList'],
            templateList = form['/admin/services/templateList'].list,
            html = '<table skipStyle="true"><tr><td colspan="2">';
        html = html+i18n.get('Select the folder you wish to create the article in, and optionally a template, then click on create')+'<br/>';
        html = html+'</td></tr><tr><td>'+i18n.get('Folder:')+'</td><td>';
        html = html+'<select id="newArticle_folder" name="newArticle_folder" style="width:100%;">';
        html = html+folderList.tree;
        html = html+'</select></td></tr><tr><td>'+i18n.get('Template:')+'</td><td>';
        html = html+ '<select id="newArticle_template" name="newArticle_template" style="width:100%;">';
        html = html+ '<option value="">'+i18n.get('(use default)')+'</option>';
        if(templateList && templateList.length)
        {
            for(var i = 0; i < templateList.length; i++)
            {
                var e = templateList[i];
                html = html + '<option value="'+e.template_id+'">'+e.name+'</option>';
            }
        }
        html = html+'</select></td></tr></table>';
        var buttons = {};
        buttons[i18n.get('Create')] = function () {
            LZ_CreateNewArticle();
            $(this).dialog('close');
        };
        var LZ_newArticleDialog = new dialogBox(html,
        {
            title: i18n.get('New article'),
            buttons: buttons,
            width: 550
        },
        {
            closeButton: i18n.get('Cancel')
        });
        progressDialog = null;
    }
    catch(e)
    {
        lzException(e);
    }
}

function LZ_CreateNewArticle()
{
    progressDialog = null;
    showPI(i18n.get('Creating article ...'));
    try
    {
        var folder_id = $('#newArticle_folder').val(),
            template_id = $('#newArticle_template').val(),
            url = '/admin/articles/add/?folder_id='+folder_id;
        if(template_id != null && template_id != '')
        {
            url = url+'&template_id='+template_id;
        }
        location.href = url;
    }
    catch(e)
    {
        lzException(e);
    }
}
