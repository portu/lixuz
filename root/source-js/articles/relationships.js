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
var relationships = {
    currentSelections: null,
    existingList: null,

    /*
     * Retrieve a map containing information about the relationships. This can
     * then be submitted to the server to be saved
     */
    getMap: function ()
    {
        var map ={};
        $('#article_relationship_list').find('.dataRow').each(function ()
        {
            var uid = $(this).find('.uid').text();
            if(uid == '')
                return;
            var type = $(this).find('.type').text();
            map[uid] = type;
        });
        return map;
    },

    /*
     * Get a list of relationship UIDs
     */
    getExistingList: function ()
    {
        var ret = [];
        $('#article_relationship_list').find('.uid').each(function ()
        {
            ret.push($(this).text());
        });
        return ret;
    },

    /*
     * Show the dialog for adding a new relationship
     */
    showSelector: function ()
    {
        var folder = $('#folder').val();;
        buttons = {};
        buttons[i18n.get('Add relationships')] = relationships.ok;
        relationships.existingList = null;
        return newFilteringObjectSelector($.noop,'/admin/articles?list_type=pure&','article',"/admin/services/jsFilter?source=articles&defaultFolder="+folder,buttons,relationships.createListFromData,i18n.get('Add article relationships'));
    },

    /*
     * Generates a list from data received from the server
     */
    createListFromData: function(data)
    {
        var myDataList = [];
        for(var i = 0; i < data.contents.length; i++)
        {
            var entry = data.contents[i];
            myDataList.push([ entry.article_id, entry.title, entry.status ]);
        }
        return createManagedChecklistTable('relationshipList',[ i18n.get('Article ID'),i18n.get('Title'),i18n.get('Status') ],myDataList);
    },

    /*
     * Check if a relationship already exists
     */
    exists: function (rel)
    {
        if (! relationships.existingList)
            relationships.existingList = relationships.getExistingList();
        if ($.inArray(rel,relationships.existingList) !== -1)
            return true;
        return false;
    },

    /*
     * Add a relationship to the HTML list
     */
    addToList: function (elements,type)
    {
        var $base = $('#article_relationship_list').find('.dataRow').first();
        var $table = $('#article_relationship_list').find('table');

        $.each(elements,function (index, value)
        {
            var $row = $base.clone(true);
            $row.attr('style','');
            $row.find('.uid').html(value.uid);
            $row.find('.title').html(value.title);
            $row.find('.status').html(value.status);
            $row.find('.type').html(type);

            var preview = $row.find('.url').html().replace(/\d+/,value.uid);;
            $row.find('.url').html(preview);

            $row.appendTo($table);
        });
        relationships.updateRelCount();
    },

    /*
     * Handle the user clicking 'ok' in the add relationship dialog
     */
    ok: function ()
    {
        try
        {
            var elements = [];
            var existing = [];
            var $entries = $('#objectSelectorContent').find('table').find(':checked').parents('tr');
            $entries.each(function ()
            {
                var $me = $(this).find('td').next();
                // Second table elemnt is UID
                var UID = $me.html();
                // Third is the title
                $me = $me.next('td');
                var title = $me.html();
                // Last is the status
                $me = $me.next('td');
                var status = $me.html();

                if (relationships.exists(UID))
                {
                    existing.push(UID);
                }
                else
                {
                    elements.push({
                        uid: UID,
                        title: title,
                        status: status,
                    });
                }
            });
            destroyObjectSelector();
            destroyChecklistTable('relationshipList');


            var message;
            if(existing.length > 0)
            {
                var message = i18n.get_advanced("The following articles already has relationships with this article: %(ARTICLES)\n\nYou will have to remove the existing relationship(s) first.", { 'ARTICLES': existing.join(',') });
            }

            if(elements.length == 0)
            {
                if(message)
                    userMessage(message);
                return;
            }
            if(message)
                message = message+"\n\n";
            else
                message = ''

            if(elements.length == 1)
            {
                message = message+i18n.get_advanced('Which type of relationship does the article "%(ARTICLE_TITLE)" have with this article?',{ 'ARTICLE_TITLE': elements[0].title});
            }
            else
            {
                message = message+i18n.get('Which type of relationship does these articles have with this article?');
            }

            message = message.replace(/\n/g,'<br />');

            var dialog = '<br />'+message+'<br /><br />';
            dialog = dialog+htmlCheckbox('art_relationship_related',i18n.get('Related'),'related','radio',true,'relationship_type')+'<br />';
            dialog = dialog+htmlCheckbox('art_relationship_previous',i18n.get('Previous article'),'previous','radio',false,'relationship_type')+'<br />';
            var buttons = {};
            buttons[i18n.get('Add relationships')] = function () {
                var type = $('[name=relationship_type]:checked').val();
                destroyMessageBox();
                relationships.addToList(elements,type);
            };
            buttons[i18n.get('Cancel')] = destroyMessageBox;
            showOrQueueMessage(dialog, i18n.get('Select relationship type'),buttons);
        }
        catch(e) { lzException(e); }
    },

    /*
     * Update the relations count, as displayed on the page
     */
    updateRelCount: function (change)
    {
        var rels;
        if(change != null)
        {
            rels = parseInt($('#relationshipsWithArticle').text()) + change;
        }
        else
        {
            rels = $('#articleRelationshipList').find('.dataRow').length - 1;
        }
        $('#relationshipsWithArticle').text(rels);
    },

    addRemoveHandlers: function ()
    {
        $('.removeRelationship').click(function ()
        {
            $(this).parent().parent().remove();
            relationships.updateRelCount(-1);
            return false;
        });
    }
};

// Attach a click handler to the 'remove' link on load
$(relationships.addRemoveHandlers);
