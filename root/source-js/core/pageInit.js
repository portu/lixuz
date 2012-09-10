/*
 * LIXUZ content management system
 * Copyright (C) Utrop A/S Portu media & Communications 2008-2011
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as
 * published by the Free Software Foundation, either version 3 of the
 * License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
/*
 * Standard page initialization code.
 */
(function($)
{
    $(function()
    {

        // Activate chosen
        $('.enableChosen').chosen();

        // Set up resizable text areas
        $('textarea:not(.yui-RTE)').resizable({handles: 'se'});
        $('.ui-resizable-se').css({ bottom: '14px', right: '2px'});

        // Set up hover menus
        $('.hoverMenu').hoverIntent(function() {
            $(this).children('.subMenu').stop(true,true);
            $(this).children('.subMenu').attr('style','display:none;');
            $(this).children('.subMenu').slideDown();
        }, function () {
            $(this).children('.subMenu').stop(true);
            $(this).children('.subMenu').slideUp();
        });

        // Set up calendars (needs jscalendar loaded, so push to the end of the LAB stack)
        $LAB.onLoaded(function ()
        {
            $('.jsCalendar').each(function ()
            {
                var $this = $(this);
                var settings = {
                    inputField : $this.attr('id'),
                    timeFormat : 24,
                    button: $this.attr('id')+'-triggerButton',
                    singleClick: true,
                    step: 1,
                };
                if($this.is('.dateOnly'))
                {
                    settings.showsTime = false;
                    settings.ifFormat = '%d.%m.%Y';
                }
                else
                {
                    settings.showsTime = true;
                    settings.ifFormat = '%d.%m.%Y %H:%M';
                }
                Calendar.setup(settings);
            });
        });

        // Enable tipsy on existing elements, we attach a live handler in the
        // final page initializer function call below (live appears to fail
        // sometimes for certain elements)
        $('.useTipsy').tipsy({ gravity: 'ne' });
        $('.useTipsyW').tipsy({ gravity: 'nw' });

        // Publish an initialization event
        $.publish('/lixuz/init');

        // Page initialization that should run after everything else
        // (setTimeout pushes it to the end of the call stack)
        setTimeout(function ()
        {
            // Style buttons that aren't already handled
            $('input:button:not(ui-button), button:not(ui-button), input:submit:not(ui-button), input:reset:not(ui-button)').not('.native-button').button();
            // Attach a live tipsy handler
            $('.useTipsy').tipsy({ gravity: 'ne', live: true });
            $('.useTipsyW').tipsy({ gravity: 'nw', live: true });
            // Publish an initialization event
            $.publish('/lixuz/lastInit');
        }, 1);
    });
})(jQuery);
