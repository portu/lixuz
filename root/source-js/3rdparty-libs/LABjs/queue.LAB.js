(function($LAB)
{
    var queueLoaded = false,
        secondQueue = [];
    $LAB.onLoaded = function (run)
    {
        if(queueLoaded === true)
        {
            run();
        }
        else
        {
            secondQueue.push(run);
        }
    };
    $LAB.queue = function(fn,ignoredParam) {
        return $LAB.queueScript(fn).queueWait();
    };
    $LAB.executeQueue = function() {
        $LAB.queueWait(function ()
        {
             window.jQuery.each(secondQueue, function (k,v)
             {
                 v();
             });
            queueLoaded = true;
            secondQueue = null;
        });
        $LAB.runQueue();
    };
})($LAB);
