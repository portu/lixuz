$(window).bind('beforeunload', function ()
{
    var messages = [];
    $.publish('/lixuz/beforeunload',[ messages ]);
    if(messages.length)
    {
        return messages.join("\n");
    }
});
