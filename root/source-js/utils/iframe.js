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
function LZ_iFrame_getDoc ()
{
    try
    {
        var doc = this.iframeObj.contentDocument;
        if (doc == undefined || doc == null)
        {
            doc = this.iframeObj.contentWindow.document;
        }
        return doc;
    }
    catch(e)
    {
        lzException(e);
    }
}
function LZ_iFrame_setContentManual (content)
{
    try
    {
        var doc = this.getDoc();
        // FIXME: doc.write
        doc.open();
        doc.write('<head><script>function $ (id) { return document.getElementById(id) }</script><link rel="stylesheet" type="text/css" href="/css/lixuz.css" /></head><body>'+content+'</body>');
        doc.close();
    }
    catch(e)
    {
        lzException(e);
    }
}
function LZ_iFrame_setContent (content)
{
    try
    {
        var doc = this.getDoc();
        if(doc == null || doc == undefined)
        {
            throw('setContent() failed to retrieve any document. iFrame object broken?');
        }
        var body = doc.body;
        if(body == undefined || body == null)
        {
            body = doc.getElementsByTagName('body');
            if(body == null || body.length < 1)
            {
                return this._setContentManual(content);
            }
            body = body[0];
        }
        body.innerHTML = content;
    }
    catch(e)
    {
        lzException(e);
    }
}
function LZ_iFrame_setParent (parentObj)
{
    parentObj.appendChild(this.iframeObj);
}
/*
 * Our iFrame object
 *
 * API:
 * var iframe = new LZ_iFrame(SOME_ID);
 * var innerDocument = iframe.getDoc();
 * iframe.setContent('some html string');
 * iframe.setParent(some dom obj);
 */
function LZ_iFrame (id)
{
    try
    {
        var obj = document.getElementById(id);
        if (!obj)
        {
            obj = document.createElement('iframe');
            obj.id = id;
        }
        try { obj.innerHTML = '<center><b>iFrame broken</b></center>'; } catch(e) {}
        this.iframeObj = obj;

        this.getDoc = LZ_iFrame_getDoc;
        this.setContent = LZ_iFrame_setContent;
        this._setContentManual = LZ_iFrame_setContentManual;

        // Initialize
        this._setContentManual('&nbsp;');
    }
    catch(e) { lzException(e) }
}
