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
function createLixuzRTE (id)
{
    deprecated('Superseded by RTE.init()');
    return lixuzRTE.init(id);
}

function editorHelper_removeFormat ()
{
    try
    {
        // Clean up, quick and dirty
        var content = this._getDoc().body.innerHTML;
        if(content == null)
        {
            return [ false ];
        }
        content = content.replace(/\n\n/g,'<br /><br />');

        // Remove various formatting/useless/prohibited tags
        var tags = ['h1','h2','h3','h4','h5','b','i','u','big','font','strong','meta','title'];
        for (var i = 0; i < tags.length; i++)
        {
            var tag = tags[i];
            var regex = new RegExp('</?\\s*'+tag+'\\s*[^>]*>','ig');
            content = content.replace(regex,'');
        }

        // Remove various attributes
        var attributes = ['style','class','color','bgcolor'];
        for (var i = 0; i < attributes.length; i++)
        {
            var attrib = attributes[i];
            var regex = new RegExp(attrib+'="[^"]*"','ig');
            content = content.replace(regex,'');
            regex = new RegExp(attrib+"='[^']*'",'ig');
            content = content.replace(regex,'');
        }
        // Remove empty tags
        content = content.replace(/<[^>\/]+>\s*<\/[^>]+>/gi,'');

        // Remove <p> tags, they mess up editor functionality, and we don't
        // really need them.
        var pRegex = new RegExp('\<\/p\>','ig');
        content = content.replace(pRegex,'<br /><br />');
        pRegex = new RegExp('\<p\>','ig');
        content = content.replace(pRegex,'');

        // Finally, clean up excessive whitespace
        content = content.replace(/\s+>/g,'>');
        content = content.replace(/<\s+/g,'<');
        content = content.replace(/\s+/g,' ');
        content = content.replace(/<br\s*\/?>\s*(\s*<br\s*\/?>\s*)+/gi,'<br /><br />');

        // Push it back in
        this._getDoc().body.innerHTML = content;
    }
    catch(e)
    {
        lzException(e);
    }
    return [false];
}

var imageOldValHash;

function insertImage_handler (editorName)
{
    try
    {
        if(imageOldValHash == null)
        {
            imageOldValHash = {};
        }
        // We don't let the user modify the URL themselves, so hide it
        var imagePanel=new YAHOO.util.Element(editorName+'-panel'),
            editor = editors[editorName],
            image = editor.currentElement[0];
        if (!image)
        {
            return;
        }
        var imgInfo = { 'height': image.height, 'width': image.width };
        imageOldValHash[image.getAttribute('imgid')] = imgInfo;
        // If we already have the URL field in the DOM, hide it now to avoid issues later
        var e_element = $('#'+editorName+'_insertimage_url')[0].parentNode
        if(e_element)
        {
            e_element.style.display = 'none';
            e_element.style.visibility = 'hidden';
        }
        // This is when the entire panel is drawn, we listen here as well
        // in case of changes, or if the element wasn't available when we
        // were first run.
        imagePanel.on('contentReady', function() {
                try
                {
                    var element = $('#'+editorName+'_insertimage_url')[0].parentNode;
                    if (element)
                    {
                        element.style.display = 'none';
                        element.style.visibility = 'hidden';
                    }
                    YAHOO.util.Event.on(editorName+'_insertimage_height', 'blur', function() {
                            insertImage_resizeObj(editorName,image,null,$('#'+editorName+'_insertimage_height').val());
                        },$('#'+editorName+'_insertimage_height')[0]);
                    YAHOO.util.Event.on(editorName+'_insertimage_width', 'blur', function() {
                            insertImage_resizeObj(editorName,image,$('#'+editorName+'_insertimage_width').val(),null);
                        },$('#'+editorName+'_insertimage_width')[0]);
                    } catch(innerE) { lzException(innerE); };
                });
    }
    catch(e)
    {
        lzException(e);
    }
}

function insertImage_resizeObj(editorName,obj,width,height)
{
    if (!obj)
    {
        lzError('insertImage_resizeObj() was supplied a null object, request ignored');
        return;
    }
    var old = imageOldValHash[obj.getAttribute('imgid')];
    if(width == null && height == null)
    {
        lzError('insertImage_resizeObj() was supplied null width AND height. Something is wrong. Request ignored. Please report this.');
        return;
    }
    if(width == null)
    {
        width = image_get_new_aspect(old.width, old.height, null, height);
    }
    else
    {
        height = image_get_new_aspect(old.width, old.height, width, null);
    }
    try
    {
        $('#'+editorName+'_insertimage_url').val('/files/get/'+obj.getAttribute('imgid')+'?width='+width+'&height='+height);
        $('#'+editorName+'_insertimage_width').val(width);
        $('#'+editorName+'_insertimage_height').val(height);
        obj.width = width;
        obj.height = height;
        obj.src = '/files/get/'+obj.getAttribute('imgid')+'?width='+width+'&height='+height;
        setTimeout(function () {
            $('#'+editorName+'_insertimage_url').val('/files/get/'+obj.getAttribute('imgid')+'?width='+width+'&height='+height);
            $('#'+editorName+'_insertimage_width').val(width);
            $('#'+editorName+'_insertimage_height').val(height);
            obj.width = width;
            obj.height = height;
            obj.src = '/files/get/'+obj.getAttribute('imgid')+'?width='+width+'&height='+height;
            },900);
        return true;
    }
    catch(e)
    {
        lzException(e);
    }
}

/*
 * Purpose: Recalculate the aspect ratio of a image
 * Usage: new_XY = get_new_aspect(oldWidth, oldHeight, newWidth, newHeight);
 * Only supply one of newHeight and newWidth (make the other null)
 * Returns the new width or height, keeping the aspect ratio
 *
 * JS equalent to get_new_aspect() from LIXUZ::HelperModules::Files
 *
 * Same syntax, some additional error handling (original die()s),
 * this one returns null on failure.
 */
function image_get_new_aspect (oldWidth, oldHeight, newWidth, newHeight)
{
    try
    {
        var percentage_change, oldVal, newVal, changeVal;

        if(newWidth != null)
        {
            oldVal = oldWidth;
            newVal = newWidth;
            changeVal = oldHeight;
        }
        else
        {
            oldVal = oldHeight;
            newVal = newHeight;
            changeVal = oldWidth;
        }

        if(oldWidth == null && newWidth == null && oldHeight == null && newHeight == null)
        {
            lzError('Programmer says: all of (new|old)(Width|Height) were null. Something went wrong. Please report this');
            return null;
        }

        if(oldVal == 0 || newVal == 0)
        {
            lzError('oldVal or newVal in image_get_new_aspect() is zero, ignoring');
            return null;
        }

        percentage_change = oldVal/newVal;

        if(changeVal == 0 || percentage_change == 0)
        {
            lzError("changeVal or percentage_change is zero, ignoring");
            return null;
        }
        var ret = Math.round(changeVal / percentage_change);
        if(ret == null)
        {
            lzError("Programmer says: Math.round("+changeVal+'/'+percentage_change+') failed. Something went wrong. Please report this.');
        }
        return ret;
    }
    catch(e)
    {
        lzException(e);
        return null;
    }
}

(function($)
{

    window.lixuzRTE = {
        inlineMap: {},

        init: function(id,inline)
        {
            dbglog('Initializing editor '+id);
            var copyPaste = '';
            if(tinymce.isGecko)
            {
                copyPaste = 'cut,copy,paste,';
            }
            var language = i18n.get('TINYMCE_LANGUAGE');
            if(language == 'TINYMCE_LANGUAGE')
            {
                language = 'en';
            }
            tinyMCE.init({
                    // General options
                    mode : "exact",
                    elements : id,
                    language: language,
                    theme : "advanced",
                    plugins : "autolink,lists,pagebreak,style,layer,table,advhr,advlink,iespell,insertdatetime,preview,media,searchreplace,contextmenu,paste,directionality,fullscreen,noneditable,visualchars,nonbreaking,xhtmlxtras,inlinepopups",

                    // Theme options
                    theme_advanced_buttons1 : "bold,italic,underline,strikethrough,|,justifyleft,justifycenter,justifyright,justifyfull,formatselect,fontselect,fontsizeselect,|,forecolor,backcolor",
                    theme_advanced_buttons2 : copyPaste+"pastetext,pasteword,|,search,replace,|,bullist,numlist,|,outdent,indent,blockquote,|,undo,redo,|,link,unlink,anchor,cleanup,|,insertdate,inserttime",
                    theme_advanced_buttons3 : "hr,removeformat,visualaid,|,sub,sup,|,charmap,iespell,media,advhr,|,ltr,rtl,|,fullscreen,cite,abbr,acronym,del,ins,attribs,|,visualchars,nonbreaking,restoredraft",
                    theme_advanced_buttons4 : "tablecontrols",
                    theme_advanced_toolbar_location : "top",
                    theme_advanced_toolbar_align : "left",
                    theme_advanced_statusbar_location : "bottom",
                    theme_advanced_resizing : true,
            });
            if(inline)
            {
                this.inlineMap[inline] = id;
            }
        },

        get: function(RTE)
        {
            try
            {
                return tinyMCE.get(this._resolveName(RTE));
            } catch(e) { }
        },

        _get: function(RTE)
        {
            var editor = this.get(RTE);
            if (!editor)
            {
                lzError('Editor "'+RTE+'" was not found',null,true);
            }
            return editor;
        },

        _resolveName: function(RTE)
        {
            if(this.inlineMap[RTE])
            {
                return this.inlineMap[RTE];
            }
            return RTE;
        },

        getContent: function(RTE)
        {
            return this._get(RTE).getContent();
        },

        exists: function(RTE)
        {
            if(this.get(RTE) != null)
            {
                return true;
            }
            return false;
        },

        pushContent: function(RTE,HTML)
        {
            var editor = this._get(RTE);
            var content = this.getContent(RTE);
            editor.setContent(content+HTML);
            return true;
        }
    };
    window.initRTE = function(id,inline)
    {
        deprecated();
        lixuzRTE.init(id,inline);
    };
})(jQuery);
