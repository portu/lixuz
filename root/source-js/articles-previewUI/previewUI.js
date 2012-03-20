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
(function($)
{
    var lzArtPreviewUI = jClass({
        $menu: null,
        $menuStr: null,
        $sideBar: null,
        $status: null,
        visible: false,
        menuSize: null,

        _constructor: function ()
        {
            this.buildMenu();
        },

        buildMenu: function ()
        {
            var self = this;
            var $m = this.$menu = $('<div id="lzArtPreviewUIMenu" />');
            var $s = this.$menuStr = $('<div/>');
            $m.css({ 
                'background-color':'#FFFFFF',
                right:0,
                top:0,
                padding: '4px',
                position: 'absolute',
                'z-index': 999,
                'border-left': 'solid 2px',
                'border-bottom': 'solid 2px',
                '-webkit-border-bottom-left-radius': 5,
                '-moz-border-radius-bottomleft': 5,
                'border-radius-bottomleft': 5
            });
            $('head').append(this.getCSS());
            $s.html('<b>&darr; '+i18n.get('Show Lixuz sidebar')+' &darr;</b>');
            $s.css({ 'text-align': 'right', cursor: 'pointer' });
            this.$status = $('<div id="ajaxStatus" />').html(i18n.get('Working...')+' <img src="/static/images/progind.gif" width="24" height="25" />').hide()
            .css({ 'background-color':'#FFF' }).appendTo($m);
            $s.appendTo($m);
            $m.appendTo('body');
            $(window).scroll(function(){            
                $m
                .css({"marginTop": $(window).scrollTop() + "px"})
            });
            $s.click(function ()
            {
                self.toggleSidebar();
            });
            // Animate it to draw attention to it
            for(var i = 0; i < 4; i++)
            {
                $m.animate({ 'background-color':'#000', color:'#FFF'}, 'slow').animate({ 'background-color':'#FFF',color:'#000' },'slow');
            }

            if(LZ_PREVIEW_IS_LOCKED)
            {
                if(LZ_PREVIEW_CAN_BREAK_LOCK)
                {
                    $('<div/>').html(i18n.get_advanced('This article is currently locked for editing by <i>%(USER)</i>.',{ USER: LZ_PREVIEW_LOCKEDBY })+
                    i18n.get('<br /><br />This is a read-only preview of the article. You can steal this lock from the user by pressing the "Steal lock" button below. Use this function with care, if you steal a lock from a user that is currently working on this article, that user may not be able to save their changes')).
                    dialog({
                        width: 400,
                        title: 'Locked',
                        buttons: {
                            'Steal lock': function ()
                            {
                                location.href = '/admin/articles/edit/'+LZ_PREVIEW_ARTICLE_ID+'?stealLock=true';
                                $(this).dialog('close');
                            },
                            'Continue with preview': function ()
                            {
                                $(this).dialog('close');
                            }
                        }
                    });
                }
                else
                {
                    this.message(i18n.get('Locked'), '<center>'+i18n.get_advanced('This article is currently locked for editing by <i>%(USER)</i>. <br /><br />You have been forwarded to a read-only preview of the article instead.',{USER: LZ_PREVIEW_LOCKEDBY})+'</center>');
                }
            }
        },

        toggleSidebar: function ()
        {
            if (!this.$sideBar)
            {
                this.generateSidebar();
                return;
            }
            this.$menu.css({ 'background-color':'#FFF',color:'#000' });
            if (this.visible)
            {
                this.visible = false;
                this.$menuStr.html('<b>&darr; '+i18n.get('Show Lixuz sidebar')+' &darr;</b>');
                this.$menu.animate({ width: this.menuSize});
            }
            else
            {
                var height = $(window).height() - this.$menu.height() - 10;
                if (!this.menuSize)
                {
                    this.menuSize = this.$menu.width()+40;
                }
                this.$sideBar.css({ height: height, width: 550, overflow: 'auto' });
                this.visible = true;
                this.$menuStr.html('<b>&uarr; '+i18n.get('Hide Lixuz sidebar')+' &uarr;</b>');
                this.$menu.animate({ width: 550 });
            }
            this.$sideBar.slideToggle();
        },

        showPI: function ()
        {
            this.$menuStr.html(i18n.get('Loading data ...')+' <img src="/static/images/progind.gif" width="24" height="25" />');
        },

        generateSidebar: function ()
        {
            this.showPI();
            var self = this;
            self.$menu.stop(true);
            self.$menu.animate({ 'background-color':'#FFF',color:'#000' },'fast');
            $.getJSON('/admin/articles/preview/'+LZ_PREVIEW_ARTICLE_ID+'?_JSON_Submit=1',function (data)
            {
                self.createSidebar(data);
            });
        },

        createSidebar: function (r)
        {
            var self = this;
            var $sideBar = this.$sideBar = $('<div/>');
            $sideBar.hide();
            $sideBar.appendTo(this.$menu);

            var html = '';
            if(LZ_PREVIEW_CAN_EDIT && !LZ_PREVIEW_IS_LOCKED)
            {
                html = html+'<a style="color:#000; font-weight: bold; text-decoration: underline;" href="/admin/articles/edit/'+LZ_PREVIEW_ARTICLE_ID+'">'+i18n.get('Edit article')+'</a><br />';
            }
            html = html +'<br />';
            html = html + '<b>'+i18n.get('Article ID:')+'</b> '+this.saneVal(LZ_PREVIEW_ARTICLE_ID)+'<br />';
            html = html + '<b>'+i18n.get('Publish time:')+'</b> '+this.saneVal(r.article.pubtime)+'<br />';
            html = html + '<b>'+i18n.get('Expiry time:')+'</b> '+this.saneVal(r.article.exptime)+'<br />';
            html = html + '<b>'+i18n.get('Folder path:')+'</b> '+this.saneVal(r.article.folder_path)+'<br />';
            html = html + '<b>'+i18n.get('Status:')+'</b> '+this.saneVal(r.article.status)+'<br />';
            html = html + '<b>'+i18n.get('Assigned to:')+'</b> '+this.saneVal(r.workflow.assigned_to)+'<br />';
            html = html + '<b>'+i18n.get('Assigned by:')+'</b> '+this.saneVal(r.workflow.assigned_by)+'<br />';
            html = html + '<b>'+i18n.get('Priority:')+'</b> '+this.saneVal(r.workflow.priority)+'<br />';
            html = html + '<b>'+i18n.get('Start date:')+'</b> '+this.saneVal(r.workflow.start_date)+'<br />';
            html = html + '<b>'+i18n.get('Deadline:')+'</b> '+this.saneVal(r.workflow.deadline)+'<br />';
            html = html + '<h2>'+i18n.get('Comments')+'</h2>';
            if (LZ_PREVIEW_CAN_COMMENT)
            {
                html = html + '<b>'+i18n.get('Subject')+'</b><input type="text" size="40" id="LZWF_CommentSubject" name="LZWF_CommentSubject" /><br />';
                html = html + '<textarea cols="60" id="LZWF_CommentBody" name="LZWF_CommentBody" rows="8"></textarea><br />';
                html = html + '<input type="button" value="'+i18n.get('Submit new comment')+'" id="LZWF_CommentSubmit" />';
                html = html + '<br />';
            }
            html = html + '<div id="LZWorkflowCommentsContainer"></div><br />';
            html = html + '<h2>'+i18n.get('Files')+'</h2><table>';
            var no = 0;
            $.each(r.files, function(i,file)
            {
                no++;
                if(no > 3)
                {
                    no = 0;
                    html = html + '</tr><tr>';
                }
                html = html +'<td><a style="color:#000; text-decoration: underline;" href="/files/get/'+file.identifier+'" target="_blank">'+file.iconItem+'</a>';
                if(file.caption)
                html = html +'<br /><div captionValue="'+file.caption+'" class="viewCaptionClick">'+i18n.get('View caption')+'</div>';
                else
                html = html + '<br />'+i18n.get('(no caption set)');
                html = html +'</td>';
            });
            html = html +'</tr></table>';
            html = html + '<h2>'+i18n.get('Additional fields')+'</h2>';
            $.each(r.fields, function(key,value)
            {
                html = html+'<b>'+key+'</b><br />'+value+'<br /><br />';
            });
            html = html + '<h2>'+i18n.get('Additional elements')+'</h2><span class="lzArtPreviewUITable"><table style="width:100%"><tr><th>'+i18n.get('ID')+'</th><th>'+i18n.get('Key')+'</th><th>'+i18n.get('Value')+'</th><th>'+i18n.get('Type')+'</th></tr>';
            $.each(r.elements, function(id,content)
            {
                html = html +'<tr><td>'+id+'</td><td>'+content.key+'</td><td>'+content.value+'</td><td>'+content.type+'</td></tr>';
            });
            html = html +'</table></span><br /><br /><br />';
            $sideBar.append(html);

            $('.viewCaptionClick').click(function ()
            {
                self.message(i18n.get('Caption'),$(this).attr('captionValue'));
            }).css({ 'text-decoration':'underline',cursor: 'pointer' });

            if (LZ_PREVIEW_CAN_COMMENT)
            $('#LZWF_CommentSubmit').lButton(function () { self.submitComment(); });
            $.get('/admin/articles/workflow/comments/'+LZ_PREVIEW_ARTICLE_ID, function (data)
            {
                $('#LZWorkflowCommentsContainer').html(data);
                self.toggleSidebar();
            });
        },

        message: function (title,content)
        {
            $('<div>'+content+'</div>').dialog({
                title: title,
                buttons: {
                    Ok: function() {
                        $(this).dialog('close');
                    }
                }});
            },

            submitComment: function ()
            {
                var subject = $('#LZWF_CommentSubject').val();
                var body = $('#LZWF_CommentBody').val();
                var revision = window.location.href.replace(/.*revision=(\d+).*/,'$1')
                if(revision == window.location.href)
                {
                    revision = null;
                }
                var self = this;
                if(body == null || body == '' || !body.match(/\S/))
                {
                    this.message(i18n.get('Error'),i18n.get('You must enter a comment'));
                    return;
                }
                $('#LZWF_CommentSubject').val('');
                $('#LZWF_CommentBody').val('');
                $.post('/admin/articles/workflow/submitComment', {
                    artid: LZ_PREVIEW_ARTICLE_ID,
                    revision: revision,
                    body: body,
                    subject: subject
                }, function ()
                {
                    $.get('/admin/articles/workflow/comments/'+LZ_PREVIEW_ARTICLE_ID, function (data)
                    {
                        $('#LZWorkflowCommentsContainer').html(data);
                    });
                });
            },

            saneVal: function (val)
            {
                if(val == null)
                {
                    return i18n.get('(none)');
                }
                return val;
            },

            getCSS: function ()
            {
                var css = [];
                css.push('<style type="text/css">');
                css.push('#lzArtPreviewUIMenu a { color: #000; text-decoration: underline }');
                css.push('#lzArtPreviewUIMenu {');
                css.push('  font-size: 13;');
                css.push('  font-family: arial, verdana, sans-serif');
                css.push('}');
                css.push('#lzArtPreviewUIMenu th { background-color: #DEF }');
                css.push('.lzArtPreviewUITable table {');
                css.push('  border: 1px solid #CCC;');
                css.push('  border-spacing: 2px 2px;');
                css.push('  background-color: #CCC;');
                css.push('}');
                css.push('.lzArtPreviewUITable td { background-color: #FFF; }');
                css.push('</style>');
                return css.join(' ');
            }
        });

        $(function ()
        {
            new lzArtPreviewUI();
        });
})(jQuery);
