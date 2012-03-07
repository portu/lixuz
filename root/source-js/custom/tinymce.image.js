(function($)
{
    var changeURL = function(id,width)
    {
        $('#src').val( '/files/get/'+id+'?width='+width);
    };
    var init = function ()
    {
        var ed = tinyMCEPopup.editor;
        var image = ed.selection.getNode();
        var $image = $(image);
        var src = $('#src').val().replace(/.*files\/get\/([^\?]+).*/,'$1');

        if(src.lenght > 8 || /\//.test(src))
        {
            return;
        }

        var changeWidth = function()
        {
            var $this = $(this);
            if($this.val() == null || $this.val == "")
            {
                return;
            }
            var newHeight = image_get_new_aspect($image.width(),$image.height(),$this.val());
            $('#height').val(newHeight);
            changeURL(src,$this.val());
        };
        var changeHeight = function()
        {
            var $this = $(this);
            if($this.val() == null || $this.val == "")
            {
                return;
            }
            var newWidth = image_get_new_aspect($image.width(),$image.height(),null,$this.val());
            $('#width').val(newWidth);
            changeURL(src,newWidth);
        };

        $('#width').focusout( changeWidth );
        $('#height').focusout( changeHeight );
    };
    $(function ()
    {
        setTimeout(init,1);
    });
})(jQuery.noConflict());
