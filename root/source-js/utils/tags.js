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
var articleTags = {
    $container: null,
    $input: null,
    $entries: null,
    addTerm: null,

    init: function(container)
    {
        this.$container         = $(container);
        this.$input             = this.$container.find('input').first();
        this.$entries           = this.$container.find('.list');
        this.setupInputField();

        var $entry              = this.$entries.find('.tagEntry');

        $entry.live('click', function ()
        {
            var $this = $(this);
            $this.remove();
        });

        $entry.live('mouseover mouseout', function(event)
        {
            var $this = $(this).find('img');
            var src = $this.attr('src');
            if (event.type == 'mouseover')
            {
                src = src.replace(/delete-mono.png/,'delete.png');
            }
            else
            {
                src = src.replace(/delete.png/,'delete-mono.png');
            }
            $this.attr('src',src);
        });
    },

    setupInputField: function()
    {
        // Set up autocomplete on it
        this.$input.autocomplete({
            source: '/admin/tags/complete',
            select: function( event, ui )
            {
                if(ui.item.id)
                {
                    articleTags.addID(ui.item.id,ui.item.label);
                }
            },
            // Functionality provided by the jquery.ui.autocomplete.selectFirst.js plugin
            selectFirst: true,
            minLength: 2
        });
        // Now hook into the enter key
        this.$input.keyup( function (ev)
        {
            if(ev && ev.keyCode == 13)
            {
                articleTags.tryAddString( articleTags.$input.val() )
            }
        });
        this.$container.find('[type=button]').click(function()
        {
            articleTags.tryAddString( articleTags.$input.val() );
        });
    },

    addID: function(id, label)
    {
        // Push emptying it to the end of the call stack
        setTimeout(function()
        {
            articleTags.$input.val('');   
        },1);
        // Don't actually add if it's already added
        if (this.IDexists(id))
            return;
        this.getEntryTag(label,id).appendTo(this.$entries);
    },

    IDexists: function(id)
    {
        var list = this.getList();
        var found = false;
        $.each(list, function (i,value)
        {
            if(value == id)
                found = true;
        });
        return found;
    },

    tryAddString: function(tagName)
    {
        if(tagName.match(/\S/))
        {
            $.getJSON('/admin/tags/exists', { term: tagName }, function(response)
            {
                if(response.exists !== 0)
                {
                    articleTags.addID(response.id, response.name);
                }
                else if(response.can_add == 1)
                {
                    articleTags.addTerm = tagName;
                    AuserQuestion(i18n.get_advanced('The tag "%(TAGNAME)" does not exist. Do you want to create this tag?', { TAGNAME: tagName }), 'articleTags.addNewTag');
                }
                else
                {
                    userMessage(i18n.get_advanced('The tag "%(TAGNAME)" does not exist, and you do not have permission to create new tags', { TAGNAME: tagName }));
                }
            });
        }
        else
        {
            userMessage(i18n.get('Refusing to add empty tag.'));
        }
    },

    addNewTag: function(add)
    {
        if (!add)
            return;
        showPI(i18n.get('Creating tag...'));
        XHR.Form.POST('/admin/tags/create',{
            term: this.addTerm
        }, function (response)
        {
            destroyPI();
            articleTags.addID(response.id, response.name);
        });
    },

    getEntryTag: function(label,id)
    {
        return $('<span />').addClass('tagEntry').html(label+' <img src="/static/images/icons/delete-mono.png" class="remove" />').attr('uid',id);
    },

    getList: function()
    {
        var list = [];
        this.$entries.find('.tagEntry').each(function(element)
        {
            var $this = $(this);
            list.push($this.attr('uid'));
        });
        return list;
    }
};
