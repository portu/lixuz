/*! LAB.js v1.0.3 (c) Kyle Simpson MIT License */
/* Based on: https://gist.github.com/704226 */

// add some boilerplate "queue" behavior for use with LABjs
$LAB._queue = [];
$LAB._queueLoaded = false;
$LAB._secondQueue = [];
$LAB.onLoaded = function (run)
{
    if($LAB._queueLoaded === true)
    {
        run();
    }
    else
    {
        $LAB._secondQueue.push(run);
    }
};
$LAB.queue = function() {
    Array.prototype.push.apply($LAB._queue,arguments);
    return this;
};
$LAB.executeQueue = function() {
    var $L = $LAB;
    for (var i=0, len=$LAB._queue.length; i<len; i++) {
        if (typeof $LAB._queue[0] == "string") {
            var entry = $LAB._queue[0];
            $L = $L.script($LAB._queue[0]);
        }
        else if ($LAB._queue[0] === false) {
            $L = $L.wait();
        }
        else {
            $L = $L.wait($LAB._queue[0]);
        }
        $LAB._queue.shift(); // remove first element from the _queue
    }
    $L.wait(function ()
    {
        $LAB._queueLoaded = true;
        for (var i=0, len=$LAB._secondQueue.length; i<len; i++)
        {
            $LAB.onLoaded($LAB._secondQueue[0]);
            $LAB._secondQueue.shift();
        }
    });
    $LAB._queue = [];
};
