/*
 * LIXUZ content management system
 * Copyright (C) Utrop A/S Portu media & Communications 2012
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
/*
 * File UI handling code for Lixuz article pages. Handles things like drag+drop
 * to file spots
 */
var filesUI = {
    _spotArea:null,
    spots: null,

    // This works around jQuery UI crashing if a droppable element disappears before
    // it has finished processing. We remove it later.
    _jqDropWorkaround: function($dropped)
    {
        $dropped.hide().appendTo('body');
        setTimeout(function()
        {
            $dropped.remove();
        },100);
    },

    init: function()
    {
        filesUI.subscribeToEvents();
    },

    spotArea: function()
    {
        if( ! filesUI._spotArea)
        {
            filesUI._spotArea = $('<div />').prependTo('#article_file_list').css({
                'float': 'left',
                'margin-right':'2px',
                'background-color':'#DDD',
                'text-align':'center',
                'color':'#999',
                'min-height':$('#files_slider_inner .list_inner').height()+'px'
            }).attr('id','spotDDArea');

            // We subscribe to sectionToggled so that we can ensure
            // that we're the proper size whenever it changes.
            $.subscribe('/article/files/sectionToggled',function()
            {
                filesUI._spotArea.css({
                    'min-height':$('#files_slider_inner .list_inner').height()+'px'
                });
            });
        }
        return filesUI._spotArea;
    },

    subscribeToEvents: function()
    {
        $.subscribe('/articles/files/generatedFileList', this.generatedList);
        $.subscribe('/articles/files/spots/image', this.gotSpots);
    },

    spotBuilder: function()
    {
        if (!filesUI.spots)
        {
            return;
        }

        var $spots = filesUI.spotArea();
        $spots.empty();
        var lastHadItem = true;
        $.each(filesUI.spots, function(i, spot)
        {
            var file = articleFiles.getFileBySpot(spot.id);
            if(spot.dynamicContent != null)
            {
                if (!lastHadItem && !file)
                {
                    return;
                }
            }
            var $entry = $('<div />');
            $entry.css({
                width: 100+'px',
                height: 120+'px',
                border: '1px solid transparent'
            }).addClass('filesDropTarget').data('spot',spot).text(spot.name).appendTo($spots);

            if(file != null)
            {
                lastHadItem = true;
                var $container = $('<div />').addClass('dragDropContainer').data('spot_id',spot.id);
                $container.appendTo($entry);
                var $img = $('<img />');
                $img.attr('src',articleFiles.getThumbnailFor(file)).appendTo($container);
                $('<i />').addClass('file_id').css('display','block').text(file.file.file_id).appendTo($container);

                var $preloader = $('<img />').attr('src','/static/images/icons/cancel.png').hide().load(function()
                {
                    $preloader.remove();
                }).appendTo('body');

                $img.load(function()
                {
                    var padding = ($container.width()-$img.width())/2;
                    var width = $img.width() + padding;
                    // Image is 16px, and we leave 1px for the margin
                    var left = width-17;
                    var $cancel = $('<img />');
                    $cancel.attr('src','/static/images/icons/cancel-mono.png');
                    $cancel.css({
                        width:'16px',
                        height:'16px',
                        'position':'absolute',
                        'margin':'1px',
                        left:left
                    });
                    $cancel.prependTo($container);
                    $cancel.hover(function()
                    {
                        $(this).attr('src','/static/images/icons/cancel.png');
                    },
                    function()
                    {
                        $(this).attr('src','/static/images/icons/cancel-mono.png');
                    });
                    $cancel.click(function()
                    {
                        articleFiles.removeFromSpot(file.file_id);
                        articleFiles.buildFileList();
                    });

                });
            }
            else if (spot.dynamicContent != null)
            {
                lastHadItem = false;
            }
        });

        $('.filesDropTarget').droppable({
            drop: function(ev, UI)
            {
                var $this = $(this);
                $this.css({ 'border':'0px', 'margin':'1px' });
                var $dropped = UI.draggable;

                if($this.find('.file_id').text() == $dropped.find('.file_id').text())
                {
                    filesUI._jqDropWorkaround($dropped);
                    filesUI.generatedList();
                    return;
                }

                if($dropped.is('.dragDropContainer') && $this.find('.file_id').text() != "")
                {
                    articleFiles.assignToSpot($this.find('.file_id').text(), $dropped.data('spot_id'));
                }

                articleFiles.assignToSpot($dropped.find('.file_id').text(), $this.data('spot').id);
                filesUI._jqDropWorkaround($dropped);
                articleFiles.buildFileList();
            },
            over: function()
            {
                $(this).css({ 'border':'1px solid black' });
            },
            out: function()
            {
                $(this).css({ 'border':'1px solid transparent' });
            },
        });
    },

    /* Event subscribers */
    generatedList: function()
    {
        filesUI.spotBuilder();
        $('#article_file_list .fileIconItem').draggable({
            containment: '#article_file_list',
            helper: 'clone',
            revert: 'invalid',
            start: function(e,ui)
            {
                $(ui.helper).find('.useTipsy').removeClass('useTipsy').tipsy('hide');
            }
        });
        $('#article_file_list .dragDropContainer').draggable({
            containment: '#article_file_list',
            revert: 'invalid'
        });
    },

    gotSpots: function(data)
    {
        filesUI.spots = data.spots;
        filesUI.spotBuilder();
    }
};

$(filesUI.init);
