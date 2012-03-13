(function($)
{
    $(function ()
    {
        $('#list_search select').each(function()
        {
            var $this = $(this);
            $this.width( $this.width()+50);
            $this.chosen({ allow_single_deselect: true });
        });
    });
})(jQuery);
