/* 
 * Wrapper for chosen, with additional defaults
 */
(function($)
{
    var orig = $.fn.chosen;
    $.fn.chosen = function(opts)
    {
        $(this).data('placeholder',i18n.get('-select-'));
        orig.call(this,$.extend({
            no_results_text: i18n.get("No results matched"),
        }, opts));
    };
})(jQuery);
