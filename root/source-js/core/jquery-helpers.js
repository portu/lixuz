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
jQuery.fn.lButton = function (action)
{
    this.button();
    this.click(action);
    return this;
};
// Easy creation of input fields with labels
jQuery.inputFieldWLabel = function (attrs, label)
{
    if(attrs.id == null)
    {
        attrs.id = 'radioIn'+(new Date).getTime()+label.length;
    }
    var o = $('<input/>');
    $.each(attrs, function (attr, val)
    {
        o.attr(attr,val);
    });
    var wrapper = $('<span/>'),
        l = $('<label>'+label+'</label>');
    l.attr('for',attrs.id);
    wrapper.append(o).append(l);
    return wrapper;
};
jQuery.radio = function (attrs, label)
{
    attrs.type = 'radio';
    return this.inputFieldWLabel(attrs,label);
};
jQuery.checkbox = function (attrs, label)
{
    attrs.type = 'checkbox';
    return this.inputFieldWLabel(attrs,label);
};
