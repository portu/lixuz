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
/*
 * Image handling code for Lixuz. Interacts with the RTE, allowing
 * the user to add and edit images
 *
 * The API here publishes the following events:
 * /articles/files/generatedFileList
 *      Issued whenever we (re)build the list of files
 */
var articleFiles = {
    filesList: null,
    showSelector: function() {},

    imageSpots: [],

    getSpotNameFor: function(spot,extra)
    {
        var spotO = articleFiles.getSpotById(spot);
        if(spotO)
        {
            if(spotO.name)
                return spotO.name;
            if(spotO.as)
                return spotO.as;
        }
        if(extra.spot_name)
            return entry.spot_name;
        return 'Spot '+spot;
    },

    initBuild: function ()
    {
        if(articleFiles.filesList == null)
        {
            try
            {
                articleFiles.filesList = FILES_BOOTSTRAP.entries;
                FILES_BOOTSTRAP = null;
            } catch(e) {}
        }
    },

    buildFileList: function ()
    {
        var html = '';
        $.each(articleFiles.filesList, function (i, entry)
        {
            var obj = entry;
            entry = '<table><tr><td>'+articleFiles.getIconItem(entry);
            entry = entry + '</td><td><a href="#" class="removeFile">'+i18n.get('Remove')+'</a><br /><a target="_blank" href="/files/get/'+obj.file.identifier+'/'+obj.file.file_name+'" class="downloadFile">'+i18n.get('Download')+'</a></td></table>';
            html = html + '<div class="fileEntry" style="width:150px;">'+entry+'</div>';
        });

        // This is done in an attempt to avoid white 'flashing' when content is
        // being appended, caused by the div attempting to resize to smaller
        // and then larger
        $('#article_file_list').css({'min-height':$('#article_file_list').height+'px'});

        $('#article_file_list').find('.list_inner').remove();

        $('#article_file_list').append('<div class="list_inner">'+html+'<div style="clear:both";></div></div>');

        $('.removeFile').click(function ()
        {
            try
            {
                var id = $(this).parent().parent().html().replace(/.*File\s*ID/,'').replace(/^\D+/,'').replace(/\D.*/g,'');
                articleFiles.removeFile(id);
            } catch(e) { lzException(e); }
            return false;
        });

        articleFiles.updateRelCount();

        $.publish('/articles/files/generatedFileList');

        $('#article_file_list').css({'min-height':'0px'});
    },

    removeFile: function(id)
    {
        var existing = articleFiles.getFileByID(id,true);
        var spot = articleFiles.filesList[existing].spot_no;
        articleFiles.filesList.splice(existing,1);
        articleFiles.buildFileList();
    },

    getIconItem: function (entry)
    {
        var file = entry.file;
        var html = '<div class="fileIconItem">';
        var hadA = false;
        if(file.icon == null)
        {
            file.icon = '/static/images/icons/mimetypes/unknown.png';
        }
        if(file.is_image)
        {
            hadA = true;
            html = html+'<a href="#" onclick="LZ_AddImageToArticle('+file.file_id+'); return false;">';
            html = html+'<img src="'+articleFiles.getThumbnailFor(entry)+'" alt="" />';
        }
        else if(file.is_video)
        {
            hadA = true;
            html = html + '<a href="#" onclick="LZ_AddVideoToArticle('+file.file_id+'); return false;"><img src="/static/images/icons/video.png" alt="" />';
        }
        else if(file.is_audio)
        {
            hadA = true;
            html = html + '<a href="#" onclick="LZ_AddAudioToArticle('+file.file_id+'); return false;"><img src="/static/images/icons/audio.png" alt="" />';
        }
        else
        {
            hadA = true;
            html = html+'<a href="#" onclick="LZ_AddFileToArticle('+file.file_id+'); return false"><img src="'+file.icon+'" alt="" />';
        }
        html = html+'<br />';
        html = html +'<b>'+articleFiles.shortSTR(file.file_name)+'</b><br />';
        html = html+i18n.get('File ID')+': <span class="file_id">'+file.file_id+'</span><br />';
        html = html+i18n.get('Folder')+': '+articleFiles.shortSTR(file.folder,8,true)+'<br />';
        var spotName;
        if(entry.spot_no)
        {
            spotName = articleFiles.getSpotNameFor(entry.spot_no,entry);
        }
        else
        {
            spotName = '(none)';
        }
        html = html+articleFiles.shortSTR(i18n.get('Spot:')+' '+spotName);
        if(hadA)
            html = html+'</a>';
        html = html+'</div>';
        return html;
    },

    shortSTR: function(str, maxLen,pathMode)
    {
        maxLen = maxLen || 13;
        if(str == null)
            throw('shortSTR: got null str');
        if(str.length > maxLen)
        {
            // FIXME: This is rather ugly, fix it by encoding "" in a raw
            // abbr title instead
            var d = $('<div />');
            var abbr = $('<abbr />');
            abbr.attr('title',str).addClass('useTipsy');
            abbr.appendTo(d);
            if(pathMode)
            {
                var noChars = maxLen-4;
                var startAt = noChars-(noChars*2);
                str = '/... '+str.substr(startAt,maxLen);
            }
            else
            {
                str = str.substr(0,9)+' ...';
            }
            abbr.html(str);
            str = d.html();
            d.remove();
        }
        return str;
    },

    getFileByID: function(fileid, wantsId)
    {
        var file;
        var id;
        $.each(articleFiles.filesList, function (i, ent)
        {
            if(ent.file_id == fileid)
            {
                file = ent;
                id = i;
            }
        });
        if(wantsId)
            return id;
        return file;
    },

    getIdentifierByID: function(fileid)
    {
        var file = this.getFileByID(fileid);
        if(file == null)
        {
            throw('Unknown file id: '+fileid);
        }
        return file.file.identifier;
    },

    getSpotById: function(spot)
    {
        var ret = null;
        $.each(articleFiles.imageSpots, function (i,ent)
        {
            if(ent.id == spot)
            {
                ret = ent;
            }
        });
        return ret;
    },

    spotTaken: function(spot)
    {
        if(articleFiles.getFileBySpot(spot) == null)
            return false;
        return true;
    },

    getFileBySpot: function(spot)
    {
        var file = null;
        if ($.isPlainObject(spot))
        {
            if(spot.spot_no)
                spot = spot.spot_no;
            else
                spot = spot.id;
        }
        $.each(articleFiles.filesList, function (i, ent)
        {
            if(ent.spot_no == spot)
                file = ent;
        });
        return file;
    },

    autoAssignToSpot: function(entry)
    {
        var spot;
        $.each(articleFiles.imageSpots, function (i,ent)
        {
            if(spot)
                return;
            if(articleFiles.spotTaken(ent))
                return;
            spot = ent.id;
        });
        return spot;
    },

    getFileFromVar: function (getFrom)
    {
        if($.isPlainObject(getFrom))
            return getFrom;
        return articleFiles.getFileByID(getFrom);
    },

    getFileCaption: function (file)
    {
        file = articleFiles.getFileFromVar(file);
        if(file.caption)
            return file.caption;
        return file.file.caption;
    },

    getThumbnailFor: function(file)
    {
        file = articleFiles.getFileFromVar(file);
        var size = '?width=80';
        if(parseInt(file.file.height,10) > parseInt(file.file.width,10))
        {
            size = '?height=80';
        }
        return '/files/get/'+file.file.identifier+size;
    },

    assignToSpot: function (file, spot)
    {
        if (!spot)
            spot = articleFiles.autoAssignToSpot(fileEntry);
        var fileEntry = articleFiles.getFileFromVar(file);
        if (!fileEntry)
        {
            throw('Failed to fetch fileEntry for "'+file+'"');
        }
        if (articleFiles.spotTaken(spot))
        {
            $.each(articleFiles.filesList, function(i,ent)
            {
                if(ent.spot_no == spot)
                    ent.spot_no = null;
            });
        }
        fileEntry.spot_no = spot;
        return fileEntry;
    },

    removeFromSpot: function(fileEntry)
    {
        fileEntry = articleFiles.getFileFromVar(fileEntry);
        fileEntry.spot_no = null;
    },

    performFileAddition: function(data,files)
    {
        destroyPI();
        if(data !== null)
            articleFiles.imageSpots = data['/admin/services/templateInfo'].spots;
        $.each(files, function(i, ent)
        {
            if (ent == null || ! $.isPlainObject(ent) || $.isEmptyObject(ent))
                return;
            var file = { file: ent, file_id: ent.file_id };

            var existing = articleFiles.getFileByID(file.file.file_id,true);

            if(file.file.is_image)
                articleFiles.assignToSpot(file);

            if(existing)
            {
                articleFiles.filesList[existing] = file;
            }
            else
            {
                articleFiles.filesList.push(file);
            }
        });

        articleFiles.buildFileList();
    },

    addTheseFiles: function (files)
    {
        LZ_RetrieveSpots('image',function (data)
        {
            articleFiles.performFileAddition(data,files);
        });
    },

    retrieveFileSpots: function(type,onDone)
    {
        showPI(i18n.get('Fetching list of file spots...'));
        if(onDone)
        {
            // Legacy API support
            // We emulate the legacy API by subscribing for the duration of a single
            // request, and then unsubscribing before handing the supplied onDone
            // function its response.
            var id = $.subscribe('/articles/files/spots/'+type, function(data)
            {
                $.unsubscribe(id);

                onDone({
                    '/admin/services/templateInfo': {
                        spots: data.spots
                    },
                    '/admin/articles/JSON/getTakenFileSpots': {
                        taken: data.taken
                    }
                });
            });
        }

        JSON_multiRequest([ '/admin/services/templateInfo', '/admin/articles/JSON/getTakenFileSpots' ], {
                'template_id':$L('template_id').value,
                'get':'spotlist',
                'article_id':$L('artid').value,
                'type':type
                },function(data)
                {
                    $.publish('/articles/files/spots/'+type, [ {
                        spots: data['/admin/services/templateInfo'].spots,
                        taken: data['/admin/articles/JSON/getTakenFileSpots'].taken
                    }]);
                },null);
    },

    /*
     * Update the file count, as displayed on the page
     */
    updateRelCount: function ()
    {
        $('#filesInArticle').text($('.fileEntry').length);
    }
};

$(articleFiles.initBuild);
