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
var objPermEditor = jClass({
    mode: null,
    thing_id: null,
    thing_name: null,
    DOM: null,
    win: null,
    roleAndUserList: null,
    permList: null,
    $userSelect: null,
    $roleSelect: null,
    
    _constructor: function (params)
    {
        if(params.mode == null)
        {
            throw('Required parameter "mode" missing')
        }
        if(params.id == null)
        {
            throw('Required parameter "id" missing');
        }
        this.thing_id = params.id;
        this.mode = params.mode;
        if(params.name)
            this.thing_name = params.name;

        this.retrieveData();
    },

    _destructor: function ()
    {
        if(this.win)
            this.win.destroy();
    },

    thingName: function ()
    {
        if(this.thing_name && this.thing_id)
        {
            return this.thing_name+' ('+this.thing_id+')';
        }
        else if(this.thing_name)
        {
            return this.thing_name;
        }
        else if(this.thing_id != null)
        {
            return this.thing_id;
        }
        else
        {
            return '(unknown)';
        }
    },

    html: function ()
    {
        if(this.DOM)
            return this.DOM;
        return this.buildHTML();
    },

    buildHTML: function ()
    {
        var editorObj = this,
            $infoString = $('<div/>').html(i18n.get('Editing permissions for '));

        if (this.mode == 'folder')
        {
            $infoString.append(i18n.get('the folder '));
        }
        else
        {
            $infoString.append('the entity ');
        }
        $infoString.append(this.thingName()+'<br /><br />');

        this.$userSelect = this.buildHTML_userSelect();
        this.$roleSelect = this.buildHTML_roleSelect();

        var $typeSelect = $('<select id="typeSelector"><option value="user">'+i18n.get('user')+'</option><option value="role">'+i18n.get('role')+'</option></select>')
            .change( function () {
                if($(this).val() == 'user')
                {
                    $('.objPermIdSelector').replaceWith(editorObj.$userSelect.clone());
                }
                else
                {
                    $('.objPermIdSelector').replaceWith(editorObj.$roleSelect.clone());
                }
                editorObj.setCurrentPerms();
            });

        var $forInput = $('<div/>').html('Set permissions for the ')
            .append( $typeSelect ).append(' ')
            .append( this.$userSelect.clone() ),

            $permission = $('<div/>').html('Permission: ')
            .append( $.radio({ name: 'perm', value: '0' },'None') )
            .append( $.radio({ name: 'perm', value: '2' },'Read-only') )
            .append( $.radio({ name: 'perm', value: '6' },'Read+write') )
            .append(),

            $root = $('<div/>')
            .append($infoString)
            .append($forInput)
            .append($permission);

        if(this.mode == 'folder')
        {
            $root.append('<br />')
                .append( $.checkbox({ id: 'overrideChildFolders' }, i18n.get('Override existing permissions on subfolders')));
        }
        this.DOM = $root;
        return $root;
    },

    buildHTML_userSelect: function ()
    {
        var userSel = $('<select class="objPermIdSelector"</select>');
        $.each(this.roleAndUserList.users, function (id,name)
        {
            userSel.append('<option value="'+id+'">'+name+'</option>');
        });
        return userSel;
    },

    buildHTML_roleSelect: function ()
    {
        var roleSel = $('<select class="objPermIdSelector"</select>');
        $.each(this.roleAndUserList.roles, function (id,name)
        {
            roleSel.append('<option value="'+id+'">'+name+'</option>');
        });
        return roleSel;
    },

    setCurrentPerms: function ()
    {
        var editorObj = this,
            currType = $('#typeSelector').val();
        currType = currType == 'user' ? 'users' : 'roles';
        var currId = $('.objPermIdSelector').val();
        $('input[name=perm]:checked').removeAttr('checked');
        var currP = this.permList[currType][currId];
        if(currP != null)
        {
            $('input[name=perm][value='+currP+']').attr('checked','checked');
        }
        $('.objPermIdSelector').change(function() { editorObj.setCurrentPerms() });
    },

    show: function ()
    {
        var buttons = {},
            self = this;
        buttons[i18n.get('Cancel')] = function () { self.destroy() };
        buttons[i18n.get('Save and close')] = function () { self.submitData() };
        this.win = new dialogBox(this.html(), {
            title: i18n.get('Permissions editor'),
            buttons: buttons
        });
        this.setCurrentPerms();
    },

    retrieveData: function ()
    {
        showPI(i18n.get('Retrieving permissions data...'));
        var self = this;
        JSON_multiRequest([
            '/admin/services/roleAndUserList',
            '/admin/services/permList',
        ], {
            permObjType: this.mode,
            permObjId: this.thing_id
        }, function (reply) { self.retrievedData(reply); });
    },

    retrievedData: function (reply)
    {
        this.roleAndUserList = reply['/admin/services/roleAndUserList'];
        this.permList        = reply['/admin/services/permList'];
        this.show();
        destroyPI();
    },

    submitData: function (reply)
    {
        showPI(i18n.get('Applying permissions...'));
        var submit = {};
        submit.perm = $('input[name=perm]:checked').val();
        if(submit.perm == null || submit.perm == '')
        {
            destroyPI();
            userMessage(i18n.get('You have to select which permission you want to grant.'));
            return;
        }
        submit.type = $('#typeSelector').val();
        submit.id   = $('.objPermIdSelector').val();
        submit.object = this.mode;
        submit.objectID = this.thing_id;
        if(submit.object == 'folder')
            submit.applyRecursive = $('#overrideChildFolders').val() == 'on' ? 1 : 0;
        var self = this;
        JSON_HashPostRequest('/admin/services/setPerm',submit, function(reply)
        {
            self.submittedData(reply);
        });
    },

    submittedData: function (reply)
    {
        destroyPI();
        this.destroy();
    }
});

/*
 * Folder permissions editor, for use until after the folder list rewrite
 */
var folderPermEditor = jClass({
    _constructor: function ()
    {
        this.fetchFolderList();
    },

    fetchFolderList: function ()
    {
        showPI(i18n.get('Loading folder data ...'));
        var self = this;
        JSON_Request('/admin/services/folderList',function (reply) {
            self.folderListFetched(reply);
        });
    },

    folderListFetched: function (form)
    {
        var folderList = form.tree,
            html = i18n.get('Select the folder that you want to edit permissions for.')+'<br />';
        html = html+'<select id="folderPerm_folder" name="folderPerm_folder" style="width:100%;">';
        html = html+folderList;
        html = html+'</select>';
        var buttons = {},
            self = this;
        buttons[i18n.get('Select')] = function () {
            self.createPermEditor();
            $(this).dialog('close');
            self.destroy();
        };
        var LZ_newArticleDialog = new dialogBox(html,
        {
            title: i18n.get('Select folder'),
            buttons: buttons,
            width: 550
        },
        {
            closeButton: i18n.get('Cancel')
        });
        destroyPI();
    },

    createPermEditor: function ()
    {
        var editor = new objPermEditor({
            mode: 'folder',
            id: $('#folderPerm_folder').val(),
            name: $('#folderPerm_folder>option:selected').text()
        });
    }
});
