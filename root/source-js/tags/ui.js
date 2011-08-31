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
var tagsUI = {
    add: function()
    {
        XuserPrompt(i18n.get('Enter the name of the tag you wish to add'), tagsUI.addThisTag, i18n.get('Add'));
    },

    addThisTag: function(tag)
    {
        if(tag == null || tag.length < 1 || !tag.match(/\S/))
            return;
        showPI(i18n.get('Adding...'));
        tagsUI.ifNotExists(tag,function()
        {
            XHR.Form.POST('/admin/tags/create', {
                term: tag
            },tagsUI.onDone);

        });
    },

    ifNotExists: function(tag,cb)
    {
        if(tag == null)
            return;
        if(tag.match(/,/))
        {
            destroyPI();
            userMessage(i18n.get('Tags may not contain commas'));
            return;
        }
        $.getJSON('/admin/tags/exists', { term: tag }, function(response)
        {
            if(response.exists !== 1)
            {   
                cb();
            }
            else
            {
                destroyPI();
                userMessage(i18n.get('That tag already exists.'));
            }
        });
    },

    getNameFromID: function(tagID)
    {
        return $('#tag_name_'+tagID).text();
    },

    edit: function(tagID)
    {
        XuserPrompt(i18n.get('Enter the new name for this tag'), function(r)
        {
            tagsUI.changeThisTag(r,tagID);
            
        },i18n.get('Change'), this.getNameFromID(tagID));
    },

    changeThisTag: function(tag,tagID)
    {
        if(tag == null || tag.length < 1 || !tag.match(/\S/) || tag == tagsUI.getNameFromID(tagID))
            return;
        showPI(i18n.get('Changing...'));
        tagsUI.ifNotExists(tag,function()
        {
            XHR.Form.POST('/admin/tags/edit', {
                tag_id: tagID,
                name: tag
            },tagsUI.onDone);

        });
    },

    'delete': function(tagID)
    {
        XuserQuestion(i18n.get_advanced('Are you sure you want to delete the tag "%(TAGNAME)" (%(TAGID))?',{ TAGID: tagID, TAGNAME: this.getNameFromID(tagID)}), null,
        function()
        {
            showPI(i18n.get('Deleting...'));
            XHR.GET('/admin/tags/delete?tag_id='+tagID, tagsUI.onDone);
        });
    },

    onDone: function()
    {
        window.location.reload();
    }
};
