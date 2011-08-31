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
var additionalElements = {
    /*
     * Retrieve a map containing information about the elements. This can
     * then be submitted to the server to be saved
     */
    getList: function ()
    {
        var list ={};
        $('#article_elements_list').find('.dataRow').each(function ()
        {
            var uid = $(this).find('.uid').text();
            if(uid == '')
                return;
            list[uid] = {
                key: $(this).find('.key').text(),
                value: $(this).find('.value').text(),
                type: $(this).find('.type').text()
            };
        });
        return list;
    },

    /*
     * Check if an element already exists, this is done by checking if there is
     * an entry in getList()'s return value with its id
     */
    elementExists: function(id)
    {
        if(additionalElements.getList()[id])
            return true;
        return false;
    },

    /*
     * Show the additional elements selector
     */
    showSelector: function(type)
    {
        type = 'dictionary'; // FIXME: At some point when support for others
                             // has been implemented, don't hardcode it.
        showPI(i18n.get('Loading list of additional elements...'));
        var buttons = {};
        buttons[i18n.get('Add selected elements')] = additionalElements.handleElementSelectorClick;
        newFilteringObjectSelector(null,'/admin/services/elements?action=htmllist&type='+type,'element','/admin/services/jsFilter?source=onlySearch',buttons,null,i18n.get('Add additional elements'));
    },

    /*
     * Handle clicking the ok button in the selector
     */
    handleElementSelectorClick: function ()
    {
        var list = [];
        $('#listView :checked').each(function ()
        {
            var row = $(this).parent().parent().find('td').next('td').first();
            var uid = row.text();
            if(additionalElements.elementExists(uid))
                return;
            row = row.next('td').first();
            var key = row.text();
            row = row.next('td').first();
            var value = row.text();

            list.push({
                uid: uid,
                key: key,
                value: value
            });
        });

        additionalElements.addElements(list);
        objectSelectorDialog.destroy();
    },

    /*
     * Add a list of elements to the html on the page
     */
    addElements: function (list)
    {
        var $base = $('#article_elements_list').find('.dataRow').first();
        var $table = $('#article_elements_list').find('table');

        $.each(list,function (index, value)
        {
            var $row = $base.clone(true);
            $row.attr('style','');
            $row.find('.uid').html(value.uid);
            $row.find('.key').html(value.key);
            $row.find('.value').html(value.value);
            $row.find('.type').html('dictionary');

            $row.appendTo($table);
        });

        additionalElements.updateCount(list.length);
    },

    /*
     * Update the count
     */
    updateCount: function (change)
    {
        var rels;
        if(change != null)
        {
            rels = parseInt($('#AdditionalElementsForArticle').text()) + change;
        }
        else
        {
            rels = $('#article_elements_list').find('.dataRow').length - 1;
        }
        $('#AdditionalElementsForArticle').text(rels);
    },

    /*
     * Add a newly created element
     */
    addCreatedElement: function (element)
    {
        additionalElements.addElements([{
            uid: element.elementId,
            key: element.key,
            value: element.value,
            type: 'dictionary'
        }]);
        destroyPI();
    },

    /*
     * Add handlers for the "remove" links
     */
    addRemoveHandlers: function ()
    {
        $('.removeAdditionalElement').click(function ()
        {
            $(this).parent().parent().remove();
            relationships.updateRelCount(-1);
            return false;
        });
    },

    /*
     * Slider toggler
     */
    toggle: function ()
    {
        $('#additionalElements_slider_inner').slideToggle();
    }
};
$(additionalElements.addRemoveHandlers);
