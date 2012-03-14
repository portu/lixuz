(function($)
{
    var entry = 0;
    $(function ()
    {
        var chosenOptions = {
            allow_single_deselect: true
        };
        var $areaClone = $('.file_folder_area').first().clone().detach();

        var hasValues = function(returnTotal)
        {
            var hasValues = true;
            var numberOfValues = 0;
            $('#fileEditArea select.file_folder').each(function()
            {
                var value = $(this).val();
                if(isNaN(parseInt(value,10)))
                {
                    if (!hasValues)
                    {
                        $(this).parents('.file_folder_area').remove();
                    }
                    hasValues = false;
                }
                else
                {
                    numberOfValues++;
                }
            });
            if(returnTotal)
            {
                return numberOfValues;
            }
            return hasValues;
        };

        var addSecondAreaIfNeeded = function()
        {
            if (!hasValues())
            {
                return;
            }

            entry++;

            var $clone = $areaClone.clone();

            var $firstOption      = $clone.find('option').first();
            if(isNaN(parseInt($firstOption.val(),10)))
            {
                $firstOption.attr('selected','selected');
            }
            else
            {
                $('<option />').text('').attr('selected','selected').prependTo($clone.find('select'))
            }
            $clone.find('.label').find('span').text(i18n.get('Additional folder'));
            $clone.insertAfter($('.file_folder_area').last());
            var newName = $clone.find('select').attr('id');
            newName = newName+'_'+entry;
            $clone.find('select').attr('name',newName).attr('id',newName);
            $clone.find('select').chosen(chosenOptions);
        };

        $('.file_folder').chosen(chosenOptions);

        $('#fileEditArea').on('change','.file_folder',addSecondAreaIfNeeded);
        window.fileFormLogic_submit = function()
        {
            if (hasValues(true) <= 0)
            {
                userMessage(i18n.get('You must select at least one folder'));
                return false;
            }
        };
        $('#fileEditArea form').submit( window.fileFormLogic_submit );

        setTimeout(addSecondAreaIfNeeded,1);
    });
})(jQuery);
