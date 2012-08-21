var SELECTED_RANGE = null;
function getselectionHandler()
{
    var startDate = null;
    var ignoreEvent = false;

    return function(cal)
    {
        var selectionObject = cal.params;
        selectionObject.inputField.value = cal.date.print(selectionObject.ifFormat);
        var selectedDate = selectionObject.inputField.value;

        if (startDate == null)
        {
            startDate = selectedDate;
            SELECTED_RANGE = null;
            cal.refresh();
        }
        else
        {
            ignoreEvent = true;
            selectionObject.inputField.value = "";
            var pstStartDateFormat = startDate.replace(/\./g,'/');
            var pstEndDateFormat = selectedDate.replace(/\./g,'/');
            if (new Date(pstStartDateFormat).getTime() > new Date(pstEndDateFormat).getTime())
            {
                userMessage(i18n.get('Start date should be less than end date.'));
                return false;
            }
            selectionObject.inputField.value =startDate+"-"+selectedDate;   
            ignoreEvent = false;
            startDate = null;
            cal.refresh();
        }
    };
};

