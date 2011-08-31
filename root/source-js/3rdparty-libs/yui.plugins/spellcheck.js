function editor_enableSpellCheckOn(Editor)
{
    var spellcheckBody = document.createElement('div');
    var Dom = YAHOO.util.Dom,
        Event = YAHOO.util.Event,
        Lang = YAHOO.lang;

    var _handleWindowClose = function() {
    };

    var _handleWindow = function() {
        this.nodeChange();
        var el = this.currentElement[0],
        win = new YAHOO.widget.EditorWindow('spellcheck', {
            width: '170px'
        });
        spellcheckBody.id = 'spellcheck_body';

        spellcheckBody.innerHTML = '<strong>Suggestions:</strong><br>';
        var ul = document.createElement('ul');
        ul.className = 'yui-spellcheck-list';
        spellcheckBody.appendChild(ul);

        var list = '';
        for (var i = 0; i < this._spellData.length; i++) {
            if (el.innerHTML == this._spellData[i].word) {
                for (var s = 0; s < this._spellData[i].suggestions.length; s++) {
                    list = list + '<li title="Replace (' + this._spellData[i].word + ') with (' + this._spellData[i].suggestions[s] + ')">' + this._spellData[i].suggestions[s] + '</li>';
                }
            }
        }

        ul.innerHTML = list;
        
        Event.on(ul, 'click', function(ev) {
            var tar = Event.getTarget(ev);
            Event.stopEvent(ev);
            if (this._isElement(tar, 'li')) {
                el.innerHTML = tar.innerHTML;
                Dom.removeClass(el, 'yui-spellcheck');
                Dom.addClass(el, 'yui-non');

                var next = Dom.getElementsByClassName('yui-spellcheck', 'span', this._getDoc().body)[0];
                if (next) {
                    this.STOP_NODE_CHANGE = true;
                    this.currentElement = [next];
                    _handleWindow.call(this);
                } else {
                    this.checking = false;
                    this.toolbar.set('disabled', false);
                    this.closeWindow();
                }
                this.nodeChange();
            }
        }, this, true);

        this.on('afterOpenWindow', function() {            
            this.get('panel').syncIframe();
            var l = parseInt(this.currentWindow._knob.style.left, 10);
            if (l === 40) {
               this.currentWindow._knob.style.left = '1px';
            }
        }, this, true);

        win.setHeader('Spelling Suggestions');
        try
        {
            this.openWindow(win);
        }
        catch(e)
        {
            alert('err: '+e);
        }

        
    };
            Editor.on('windowRender', function() { 
                    Editor._windows.spellcheck = {};
                    Editor._windows.spellcheck.body = spellcheckBody; //This is a DOM reference to the HTML in the new window.
                    spellcheckBody.style.display = 'none'; //This hides the body until the window is opened.
                    }, Editor, true);

    /* {{{ Override _handleClick method to keep the window open on click */
    Editor._handleClick = function(ev) {
        if (this._isNonEditable(ev)) {
            return false;
        }
        this._setCurrentEvent(ev);
        var tar =Event.getTarget(ev);
        if (this.currentWindow) {
            if (!Dom.hasClass(tar, 'yui-spellcheck')) {
                this.closeWindow();
            }
        }
        if (!Dom.hasClass(tar, 'yui-spellcheck')) {
            if (YAHOO.widget.EditorInfo.window.win && YAHOO.widget.EditorInfo.window.scope) {
                YAHOO.widget.EditorInfo.window.scope.closeWindow.call(YAHOO.widget.EditorInfo.window.scope);
            }
        }
        if (this.browser.webkit) {
            var tar =Event.getTarget(ev);
            if (this._isElement(tar, 'a') || this._isElement(tar.parentNode, 'a')) {
                Event.stopEvent(ev);
                this.nodeChange();
            }
        } else {
            this.nodeChange();
        }
    };
    /* }}} */
    
    Editor.checking = false;
        Editor.on('toolbarLoaded', function() {
        this.toolbar.addButtonToGroup( { type: 'push', label: 'Check Spelling', value: 'spellcheck' },'insertitem');
    }, Editor, true);

    Editor._checkSpelling = function(data) {
        destroyPI();
        var html = this._getDoc().body.innerHTML;
        for (var i = 0; i < data.data.length; i++) {
            html = html.replace(data.data[i].word, '<span class="yui-spellcheck">' + data.data[i].word + '</span>');
        }
        this.setEditorHTML(html);
        this._spellData = data.data;
    };

    Editor.on('windowspellcheckClose', function() {
        _handleWindowClose.call(this);
    }, Editor, true);
    
    Editor.on('editorMouseDown', function() {
        var el = this._getSelectedElement();
        if (Dom.hasClass(el, 'yui-spellcheck')) {
            this.currentElement = [el];
            _handleWindow.call(this);
            return false;
        }
    }, Editor, true);
    Editor.on('editorKeyDown', function(ev) {
        if (this.checking) {
            //We are spell checking, stop the event
            Event.stopEvent(ev.ev);
        }
    }, Editor, true);
    Editor.on('afterNodeChange', function() {
        this.toolbar.enableButton('spellcheck');
        if (this.checking) {
            this.toolbar.set('disabled', true);
            this.toolbar.getButtonByValue('spellcheck').set('disabled', false);
            this.toolbar.selectButton('spellcheck');
        }
    }, Editor, true);
    Editor.on('editorContentLoaded', function() {
        this._getDoc().body.spellcheck = false; //Turn off native spell check
    }, Editor, true);
    Editor.on('toolbarLoaded', function() {
        this.toolbar.on('spellcheckClick', function() {
            if (!this.checking) {
                this.checking = true;
                var postThis = 'spellCheckData='+encodeURIComponent(Editor._getDoc().body.innerHTML);
                showPI(i18n.get('Spellchecking...<br />Please wait'));
                JSON_Request_WithObj('/admin/services/spellcheck',this,'_checkSpelling',postThis);
            } else {
                this.checking = false;
                var el = Dom.getElementsByClassName('yui-spellcheck', 'span', this._getDoc().body);
                //More work needed here for cleanup..
                Dom.removeClass(el, 'yui-spellcheck');
                Dom.addClass(el, 'yui-none');
                this.toolbar.set('disabled', false);
                this.nodeChange();
            }
            return false;
        }, this, true);
    }, Editor, true);
}
