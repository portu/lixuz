$(document).ready(function(){

    // Dynamically enforce a minimum width
    var $first = $('.select ul').first();
    var width = 0;
    $first.find('li.option').each(function()
    {
        var thisWidth = $(this).width();
        if (thisWidth > width)
        {
            width = thisWidth;
        }
    });
    width = width + 20;
    $first.parents('td').css({ 'min-width':width+'px' });

    $('.select ul li.option').click(function(e) {
        e.stopPropagation();
        var $this = $(this);
        var selectdOption= $this.attr('data');
        var theID=$this.parents('div.select').attr('id');
        var divData=$this.parents('div.select').attr('data');
        var orgval = $("#articlestatus_"+divData).attr('data');
        if(orgval == selectdOption)
        {
            $("#articlestatus_"+divData).attr('disabled','disabled');
            $('#'+theID).removeAttr("dt");
            $('#unsavedstatus_'+divData).html('');
            $('#unsavedTd_'+divData).removeAttr("style");
        }
        else
        {
            $('#articlestatus_'+divData).removeAttr('disabled');
            $("#articlestatus_"+divData).val(selectdOption);
            $('#'+theID).attr('dt','nofollow');
            $('#unsavedstatus_'+divData).html(i18n.get('(Unsaved)'));
            $('#unsavedTd_'+divData).css("height", "35px");
        }
        var $unsaveddiv = $('#quickedit div[dt=nofollow]');

        if($unsaveddiv.length)
        {
            $("#submitbutton").show();
        }
        else
        {
            $("#submitbutton").hide();
        }
        $('.select').not('#'+theID).find('ul li.option').each(function()
        {
            if ( !$(this).is(":hidden") )
            {
                $(this).not('.darr').slideToggle(100);
            }
        });
        $this.siblings().slideToggle(100).removeClass('darr');
        $this.addClass('darr');
        var isDisplayed = $this.parents('.select').is('.select_displayed');
        $('.select_displayed').removeClass('select_displayed');
        if (!isDisplayed)
        {
            $this.parents('.select').toggleClass('select_displayed');
        }
    });

    $(document).click(function(e)
    {
        $('.select ul li.option').each(function()
        {
            if ( !$(this).is(":hidden") )
            {
                $(this).not('.darr').slideToggle(100);
            }
        });
    });

    $('div.dclass').click(function()
    {
        var cdivId=$(this).attr('id');
        var cdivData=$(this).attr('data');
        $("#writeaccesss_"+cdivData).hide();
        $("#writeaccessmsg_"+cdivData).show();

        $('div.showmsg').each(function(){
            var cdivDt=$(this).attr('data');

            $(this).removeClass('showmsg');
            $(this).hide();
            $("#writeaccesss_"+cdivDt).show();
        })

        $("#writeaccessmsg_"+cdivData).addClass('showmsg');
    });
    $("#quickedit").submit(function(){
        $(window).unbind("beforeunload");
    });
    $(window).bind('beforeunload', function()
    {
        if ($('#quickedit div[dt=nofollow]').length > 0 )
        {
            return i18n.get('You have unsaved status changes, those changes will be lost if you leave without saving.');
        }
    });

});

