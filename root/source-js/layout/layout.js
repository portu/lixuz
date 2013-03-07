var categoryLayout =
{
    spotMap: {},
    initialize: function()
    {
        var self = categoryLayout;
        self.updateArtList('root',null,true);

        $('.layout-default').each(function()
        {
            var $this = $(this);
            try
            {
                self.setSpotValue($this.data('spot'), $this.data('artid'), $this.data('arttitle'),$this.data('artimage'));
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
        var self = this;
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

        $('.targetSpot').droppable({
            drop: function (ev, UI)
            {
                var $dropped  = UI.draggable,
                    id    = $dropped.data('artid'),
                    title = $dropped.data('arttitle'),
                    lead  = $dropped.data('artlead'),
                    img   = $dropped.data('artimage'),
                    spotval   = $(this).data('spotval');

                if($('#spot_article_'+spotval).val() == id)
                {
                    $dropped.draggable('option','revert',true);
                    setTimeout(1,function()
                    {
                        $dropped.draggable('option','revert','invalid');
                    });
                    return;
                }
                $(this).html("");

                if($dropped.parents('#spotArea').length > 0)
                {
                    $dropped.remove();
                }
                self.setSpotValue(spotval,id,title,img);
            },
            over: function ()
            {
                $(this).css({ 'border':'1px solid black' });
            },
            out: function ()
            {
                $(this).css({ 'border':'1px solid #CCCCCC' });
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
    setSpotValue: function(spot,id,title,img)
    {
        var $target = $('.targetSpot[data-spotval='+spot+']');

        this.setSpotEntry(spot,id);

        $target.html(this.getSpotEntry(spot, id, title, img));

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
            textDiv.appendTo(parent);
        }
        else
        {
            lzlog('removeFromSpot: got artid='+artid+' and spotval='+spotval+' (with $object='+$object+'), ended up with zero removable spots');
        }
    },
    updateArtList: function renderArticleList(fid,search,init)
    {
        var self  = this,
            catid = $('#category_id').val();
        $('#folder_id').val(fid);
        if(init !== true)
        {
            showPI(i18n.get('Retrieving articles'));
        }
        var params = {
            folder: fid
        };
        if(search != null)
        {
            params.query = search;
            params._submitted_list_search = '1';
        }

        $.post('/admin/categories/layout/renderCatArticleList/'+catid, params,
            function (data)
            {
                $('#listdiv').html(data);
                self.initDrag();
                if(init !== true)
                {
                    destroyPI();
                }
            }
        );
    }
};

$.subscribe('/lixuz/init', categoryLayout.initialize);
