$(function ()
{
    // Dynamically enforce a minimum width
    var $first = $('.select ul').first();
        width  = 0;
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

    // Handle option clicks
    $('.select ul li.option').click(function(e) {
        e.stopPropagation();

        var $this         = $(this),
            selectdOption = $this.data('value'),
            clickedID     = '#'+$this.parents('div.select').attr('id'),
            divData       = $this.parents('div.select').data('value'),
            $statusDiv    = $('#articlestatus_'+divData);

        if($statusDiv.data('value') == selectdOption)
        {
            $statusDiv.attr('disabled','disabled');
            $(clickedID).removeAttr("dt");
            $('#unsavedstatus_'+divData).html('');
            $('#unsavedTd_'+divData).css('height','auto');
        }
        else
        {
            $('#articlestatus_'+ divData).removeAttr('disabled');
            $statusDiv.val(selectdOption);
            $(clickedID).attr('dt','nofollow');
            $('#unsavedstatus_'+ divData).html(i18n.get('(Unsaved)'));
            $('#unsavedTd_'    + divData).css("height", "35px");
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
        $('.select').not(clickedID).find('ul li.option').each(function()
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

    // Show/hide arrows upon document click
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
        var $this = $(this),
            cdivId   = $this.attr('id'),
            cdivData = $this.data('value');
        $("#writeaccesss_"+cdivData).hide();
        $("#writeaccessmsg_"+cdivData).show();

        $('div.showmsg').each(function(){
            var $this  = $(this),
                cdivDt = $this.data('value');

            $this.removeClass('showmsg');
            $this.hide();
            $("#writeaccesss_"+cdivDt).show();
        })

        $("#writeaccessmsg_"+cdivData).addClass('showmsg');
    });

    // Don't run beforeunload when submitting
    $("#quickedit").submit(function(){
        $(window).unbind("beforeunload");
    });
    // Check if any changes have been made and needs to be submitting before
    // allowing the user to move away from the page.
    $(window).bind('beforeunload', function()
    {
        if ($('#quickedit div[dt=nofollow]').length > 0 )
        {
            return i18n.get('You have unsaved status changes, those changes will be lost if you leave without saving.');
        }
    });
});
