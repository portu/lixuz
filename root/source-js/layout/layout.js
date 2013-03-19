var categoryLayout =
{
    spotMap: {},
    changed: false,
    initialize: function()
    {
        var self = categoryLayout;
        self.updateArtList('root',null,true);

        $('.layout-default').each(function()
        {
            var $this = $(this),
                meta  = self.getSpotMetaFromElement($this);
            try
            {
                self.setSpotValue(meta.spot, meta.id, meta.title, meta.img);
            } catch(e) { lzException(e) }
        });

        $('#list_submit_search').click(function(e)
        {
            e.preventDefault();
            this.updateArtList('root',$('#query').val());
        });

        $('#list_search').submit(function(e)
        {
            $('#list_submit_search').click();
            e.preventDefault();
        });

        $('#saveLayoutChanges').click(function(e)
        {
            e.preventDefault();
            $('#saveArticleOrdering').click();
        });
        $('#saveArticleOrdering').click(function()
        {
            self.changed = false;
        });

        $('#spotArea').on('click','.remove-from-spot',function(e)
        {
            e.preventDefault();
            var $parent = $(this).parents('.dropcontainer');
            self.removeFromSpot( $parent.data('artid'), $parent.parent().data('spotval') );
        });
    },

    getEntryFromSpot: function(spot)
    {
        var $spot = $('#spot_article_'+spot);
        if($spot)
        {
            return $spot.val();
        }
        return;
    },

    getSpotFromEntry: function(entry)
    {
        if(this.spotMap[entry])
        {
            return this.spotMap[entry];
        }
        var $orig = $('#spotArea').find('div[data-artid='+entry+']');
        if($orig)
        {
            return $orig.val();
        }
        return;
    },

    setSpotEntry: function(spot,entry)
    {
        var $element = $('#spot_article_'+spot);
        if($element.val())
        {
            this.spotMap[$element.val()] = null;
        }
        $element.val(entry);
        if(this.spotMap[entry] != null)
        {
            var $otherElement = $('#spot_article_'+this.spotMap[entry]);
            $otherElement.val('');
        }
        this.spotMap[entry] = spot;
    },

    initDrag: function()
    {
        var self = this,
            dropTargetUI;
        $('#ddcontents .makeMeDraggable').draggable(
        {
            containment: '#ddcontents',
            helper: 'clone',
            revert: 'invalid'
        });

        $('#ddcontents .dropcontainer').draggable(
        {
            containment: '#ddcontents',
            revert: 'invalid'
        });

        dropTargetUI = {
            mouseOver: function($elem)
            {
                $elem.css({ 'border':'1px solid black' });
            },
            mouseOut:function($elem)
            {
                $elem.css({ 'border':'1px solid #CCCCCC' });
            }
        };

        $('.targetSpot').droppable({
            drop: function (ev, UI)
            {
                var $this     = $(this),
                    $dropped  = UI.draggable,
                    meta      = self.getSpotMetaFromElement($dropped),
                    spotval   = $this.data('spotval'),
                    existing  = self.getSpotMetaFromElement($this.find('.dropcontainer')),
                    previous  = self.getSpotFromEntry(meta.id);

                if($('#spot_article_'+spotval).val() == meta.id)
                {
                    $dropped.draggable('option','revert',true);
                    setTimeout(1,function()
                    {
                        $dropped.draggable('option','revert','invalid');
                    });
                    return;
                }
                $this.html("");

                if($dropped.parents('#spotArea').length > 0)
                {
                    $dropped.remove();
                }
                self.setSpotValue(spotval,meta.id,meta.title,meta.img);
                if(existing && existing.id != null && previous != null)
                {
                    self.setSpotValue(previous, existing.id,existing.title,existing.img);
                }
                dropTargetUI.mouseOut($this);
                self.changed = true;
            },
            over: function ()
            {
                dropTargetUI.mouseOver($(this));
            },
            out: function ()
            {
                dropTargetUI.mouseOut($(this));
            } 
        });

    },
    getSpotEntry: function(spot,id,title,img)
    {
        var htmldata = '<div class="dropcontainer" data-artid="'+ id +'" data-arttitle="'+ title +'" data-artimage = "'+ img +'" style="position:relative;">';
        htmldata = htmldata + '<img src="'+ img +'" style="float:left;margin:5px;border-radius:5px;">';
        htmldata = htmldata + '<h3>'+ title +'</h3>';
        htmldata = htmldata + i18n.get('Article ID: ')+id;
        htmldata = htmldata + '<div class="removeButton"><a href="#" class="remove-from-spot" title="'+i18n.get("Remove article")+'"></a></div>';

        htmldata = htmldata + '</div>';

        return htmldata;
    },
    getSpotMetaFromElement: function($element)
    {
        if($element == null)
        {
            return {};
        }
        var meta = {
            spot:  $element.data('spot'),
            id:    $element.data('artid'),
            title: $element.data('arttitle'),
            lead:  $element.data('artlead'),
            img:   $element.data('artimage')
        };
        return meta;
    },
    setSpotValue: function(spot,id,title,img)
    {
        var $target   = $('.targetSpot[data-spotval='+spot+']'),
            alreadyIn = this.getSpotFromEntry(id);

        if(alreadyIn != null && alreadyIn != '')
        {
            this.removeFromSpot(id,alreadyIn);
        }

        this.setSpotEntry(spot,id);

        $target.html(this.getSpotEntry(spot, id, title, img));
        $target.parent().find('.auto-label').remove();

        categoryLayout.initDrag();
    },
    removeFromSpot: function (artid,spotval,$object)
    {
        var removableSpot;
        $('#spot_article_'+spotval).val("");
        if($object)
        {
            removableSpot = $object;
        }
        else
        {
            removableSpot = $('#spotArea').find('div[data-artid='+artid+']');
        }
        if (removableSpot.length > 0)
        {
            var parent = removableSpot.parent();
            removableSpot.remove();

            var text = i18n.get('(auto)'),
                textDiv = $('<div />');
            textDiv.text(text);
            textDiv.addClass('auto-label');
            textDiv.appendTo(parent);
        }
        else
        {
            lzlog('removeFromSpot: got artid='+artid+' and spotval='+spotval+' (with $object='+$object+'), ended up with zero removable spots');
        }
    },
    updateArtList: function renderArticleList(fid,search,init,page)
    {
        var self  = this,
            catid = $('#category_id').val();
        $('#folder_id').val(fid);
        if (!_.isNumber(page))
        {
            page = 1;
        }
        if(init !== true)
        {
            showPI(i18n.get('Retrieving articles'));
        }
        var params = {
            folder: fid,
            page: page
        };
        if(search != null)
        {
            params.query = search;
            params._submitted_list_search = '1';
        }

        $.post('/admin/categories/layout/renderCatArticleList/'+catid, params,
            function (data)
            {
                var $listDiv = $('#listdiv');
                $listDiv.html(data);
                setTimeout(function()
                {
                    var $pager = $listDiv.find('.pagination');
                    self.initDrag();
                    $pager.find('a').click(function(ev)
                    {
                        ev.preventDefault();
                        var $this = $(this);
                        self.updateArtList(fid,search,false, $this.data('page'));
                    });
                    $pager.data({
                        fid: fid,
                        search: search
                    });
                },1);
                if(init !== true)
                {
                    destroyPI();
                }
            }
        );
    }
};

$.subscribe('/lixuz/pagerChange',function(data)
{
    data.handled = true;
    var $pager = $('#listdiv').find('pagination');
    categoryLayout.updateArtList( $pager.data('fid'), $pager.data('search'), false, data.page );
});
$.subscribe('/lixuz/init', categoryLayout.initialize);
$.subscribe('/lixuz/beforeunload', function(messages)
{
    if ( categoryLayout.changed === true )
    {
        messages.push(i18n.get('You have unsaved changes, those changes will be lost if you leave without saving.'));
    }
});
