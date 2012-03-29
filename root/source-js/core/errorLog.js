(function($,LIXUZ)
{
    LIXUZ.addNamespace('errorLog',
    {
        send: function(error,backtrace)
        {
            try
            {
                var $errorLog = $('#lixuz_error_log');
                if (!$errorLog || $errorLog.val() != 'enable')
                {
                    return;
                }
                var userAgent = '';
                var URL = '';
                try { userAgent = navigator.userAgent; } catch(e) { }
                try {
                    if(document.url)
                        URL = document.url;
                    else if(document.URL)
                        URL = document.URL;
                    else if(window.location)
                        URL = window.location;
                } catch(e) { }

                var submit = {
                    error: error || '',
                    backtrace: backtrace || '',
                    URL: URL || '',
                    UA: userAgent || ''
                };
                // Send the request and forget about it
                $.ajax({
                    type: 'POST',
                    data: submit,
                    success: $.noop,
                    error: $.noop,
                    cache: false,
                    url: '/admin/logservice'
                });
            } catch(e) { }
        }
    });
})(jQuery,LIXUZ);
