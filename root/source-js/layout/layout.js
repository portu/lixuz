   
var articleList =
{

    initDrag: function()
    {
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
            var $dropped = UI.draggable;
            var art_id = $dropped.attr('artid');
            var art_title = $dropped.attr('arttitle');
            var art_lead = $dropped.attr('artlead');
            var art_img = $dropped.attr('artimage');
            var spotval = $(this).attr('spotval');
            $(this).html("");

            var existingval = $('#spotArea').find('div[artid='+art_id+']');
            if (existingval.length > 0)
            {
                existingval.remove();
            }

            $('#spot_article_'+spotval).val(art_id);

            var htmldata = '<div class="dropcontainer" artid="'+ art_id +'" arttitle="'+ art_title +'" artlead = "'+ art_lead +'" artimage = "'+ art_img +'" style="poistion:relative;">';
            htmldata = htmldata + '<img src="'+ art_img +'" style="float:left;margin:5px;border-radius:5px;">';
            htmldata = htmldata + '<h3>'+ art_title +'</h3>';
            htmldata = htmldata + '<p>'+ art_lead +'</p>';
            htmldata = htmldata + '<div style="align:right;"> <a href="#" onclick="articleList.removeFromSpot('+ art_id + ',' + spotval +');" title="cancel"><img src="/static/images/icons/cancel-mono.png"></a></div>';

            htmldata = htmldata + '</div>';
            $(this).html(htmldata);

            articleList.initDrag();

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
    removeFromSpot: function (artid,spotval)
    {
        $('#spot_article_'+spotval).val("");
        var removableSpot = $('#spotArea').find('div[artid='+artid+']');
        if (removableSpot.length > 0)
        {
            removableSpot.remove();
        }
    },
};

$(articleList.initDrag);

function renderArticleList(fid)
{
    var catid = $('#category_id').val();
    $('#folder_id').val(fid);

    $.get('/admin/categories/layout/renderCatArticleList/'+catid+'?folder='+fid, function (data)
    {
        $('#listdiv').html(data);
    });

    showPI(i18n.get('Retrieving file spots'));
    destroyPI();
}
    
