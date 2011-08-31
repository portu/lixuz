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
var UIHelper = {
    update: function (r)
    {
        try
        {
            this.applyInputStyles(r);
            this.applyTableStyles(r);
        } catch(e) {
            lzelog(e);
        }
    },

    applyInputStyles: function (r)
    {
        r = this.root(r);
        var type = this.pageType();
        var i = r.find('input');
        i.find('[type=text]').addClass('text').addClass(type).addClass('field');
        i.find('[adtype=datetime]').addClass('jsCalendar');
        r.find('select').addClass('select').addClass(type).addClass('field');
        r.find('textarea').addClass('textarea').addClass(type).addClass('field');
    },

    applyTableStyles: function (r)
    {
        this.root(r).find('table').each(function (i,t)
        {
            var t = $(this);
            if(t.attr('skipStyle') !== "true" && t.attr('id') !== 'fileGrid')
            {
                applyStyleToTable($(this));
            }
        });
    },

    pageType: function ()
    {
        var loc = document.location.toString().replace(/^http:\/\/[^\/]+/,'');
        var test = [ 'articles','files'];
        var ret = '';
        $.each(test, function(i,e)
        {
            if(loc.indexOf(e) !== -1 && e === '')
            {
                ret = e;
            }
        });
        return ret;
    },

    root: function (r)
    {
        if(r == null)
        {
            return $;
        }
        else if($.type(r) == 'object' && r.each)
        {
            return r;
        }
        else
        {
            return $(r);
        }
    }
};
