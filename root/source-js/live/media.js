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
 * Media (audio and video) support on live websites for Lixuz
 */

/*
 * Overrides:
 *
 * Set the variable lixuz_VideoPlayerOverride to a JavaScript function.
 * This will override the function that gets called when Lixuz wants
 * to play a video file.
 *
 * The function should have the following signature:
 *
 * window.lixuz_VideoPlayerOverride = function (videoElementID, helpers)
 * {
 * };
 *
 * helpers is a javascript hash ("object") containing keys referencing
 * the various Lixuz video player functions. The reason for this is that
 * the actual functions reside within an enclosure, and thus can't be
 * directly referenced outside of it.
 *
 * The hash and the enclosed functions it references:
 * {
 *      'play': defaultPlayVideo,
 *      'playWithAds': playerWithAds,
 *      'getURL':getFLVURL
 * }
 *
 * You are guaranteed that the flowplayer javascript is loaded by the
 * time your override gets called.
 */

/*
 * We insert our functions inside an enclosure so that they don't pollute the
 * main namespace. This also makes the minifier more efficient.
 */
(function($)
{
    var runOnVideoReady = [],

    // The FlowPlayer version in use, only used for cache-bursting purposes
        FPVER = '3.2.5',
    // Array of videos on the page
        videos = [];

    /*
     * This function looks for elements with lixuz_video as their name attribute.
     * If it finds any then it tries to start the player.  If none is found it just
     * returns
     */
    function initMedia ()
    {
        try 
        { 
            var $media = $('[name=lixuz_video], [name=lixuz_audio]');
            if($media.length)
            {
                $.getScript('/swf/flowplayer/flowplayer.js?'+FPVER,function ()
                {
                    $media.each(function ()
                    {
                        var $this = $(this);
                        if($this.attr('name') == 'lixuz_video')
                        {
                            playVideo($this.attr('id'));
                        }
                        else
                        {
                            playAudio($this.attr('id'));
                        }
                    });
                });
            }
        } catch(e) { }
    }
    /* *****
     * Audio 
     * *****/

    /*
     * Run either the client overridden, or the default video player function,
     * depending on the presence of an override setting.
     */
     function playAudio(id)
     {
        var override = null;
        try
        {
            override = window.lixuz_AudioPlayerOverride;
        } catch(e) { override = null; }
        if(override != null && override != undefined)
        {
            return override(id, {
                'play'        : defaultPlayAudio,
                'getURL'      : getMP3url
            });
        }
        else
        {
            return defaultPlayAudio(id);
        }
     }

     function defaultPlayAudio (id)
     {
        try
        {
            var $e = $('#'+id);
            var URL = getMP3url(id);
            if(URL == null)
            {
                return;
            }
            $e.empty();
            var newId = $e.attr('id')+'_fpe';
            $('<div />').css({'max-height':'40px','height':'40px'}).attr('id',newId).appendTo($e);
            var vid = safePlayer(newId,{ 
                playlist: [
                    URL
                ],
                plugins:
                {
                    audio: {
                        url: '/swf/flowplayer/flowplayer.audio.swf?'+FPVER
                    },
                    controls: {
                        fullscreen:false,
                        height:40,
                        autoHide: false
                    }
                },
                clip: { 
                    autoPlay: false, 
                    // autoBuffering can cause autoPlay to be true AND
                    // have the controls msess up, so best leave it
                    // disabled for now.
                    autoBuffering: false
                }
            });
            return vid;
        }
        catch(e)
        {
            lzlog('defaultPlayAudio('+id+') error: '+e.message);
        }
     }

    /*
     * Returns the URL to the MP3 for the audio ID supplied
     */
    function getMP3url (id)
    {
        try
        {
            if(typeof(id) != 'object')
            {
                id = '#'+id;
            }
            var $element = $(id);
            if (!$element.length)
            {
                lzlog('getMP3url('+id+'): failed to retrieve element DOM object');
                return null;
            }

            var URL = $element.attr('href');
            if(! URL)
            {
                var uid = $element.attr('uid');
                if (uid == null)
                {
                    lzlog('uid missing from video element that had no href');
                    return;
                }
                URL = '/files/get/'+uid+'/lzaudio.mp3';
            }
            else
            {
                URL = element.attr('href');
            }
            return URL;
        }
        catch(e)
        {
            lzlog('Failed to retrieve MP3 URL from '+id+': '+e.message);
            return null;
        }
    }

    /* *****
     * Video
     * *****/

    /*
     * Starts a flowplayer on the id supplied
     */
    function defaultPlayVideo(id)
    {
        try
        {
            var $e = $('#'+id);
            var URL = getFLVURL(id);
            if(URL != null)
            {
                $e.attr('href',URL);
            }
            if ($e.attr('href') == null)
            {
                return;
            }
            var vid = safePlayer(id,{ 
                clip: { 
                    autoPlay: false, 
                    autoBuffering: true 
                } 
            });
            return vid;
        }
        catch(e)
        {
            lzlog('playVideo('+id+') error: '+e.message);
        }
    }

    /*
     * Starts a flowplayer on the id supplied, with ads either before, after or
     * both.
     */
    function playerWithAds (id,adBefore,adAfter)
    {
        var playlist = [];
        var mainAutoPlay = false;
        if(adBefore)
        {
            playlist.push({ url: adBefore,
                        seekableOnBegin: false,
                        controls: { playlist: false, scrubber: false }
                        });
            mainAutoPlay = true;
        }
        var vidURL = getFLVURL(id);
        if(vidURL == null)
            return;
        playlist.push({ url: vidURL, autoPlay: mainAutoPlay });
        if(adAfter)
        {
            playlist.push({ url: adAfter,
                        seekableOnBegin: false,
                        controls: { playlist: false, scrubber: false },
                        autoPlay: true
                        });
        }
        var player = safePlayer(id, {
            clip: {
                autoPlay: false,
                autoBuffering: true
            },
            'playlist':playlist,
            plugins: {
                controls: {
                    playlist: false
                }
            }
        });
        player.__lixuzInfo = { fired: 0, mainVidURL: vidURL };
        player.onFinish(function () {
                var clips = player.getPlaylist();
                if(clips.length == 1)
                {
                    return;
                }
                this.__lixuzInfo.fired++;
                if(clips.length == this.__lixuzInfo.fired)
                {
                    this.setPlaylist([ {
                        autoPlay: false,
                        autoBuffering: true,
                        url: this.__lixuzInfo.mainVidURL,
                        seekableOnBegin: true
                        }]);
                }
            });
        return player;
    }

    /*
     * Run either the client overridden, or the default video player function,
     * depending on the presence of an override setting.
     */
    function playVideo(id)
    {
        var override = null;
        try
        {
            override = window.lixuz_VideoPlayerOverride;
        } catch(e) { override = null; }
        if(override != null && override != undefined)
        {
            return override(id, {
                'play'        : defaultPlayVideo,
                'playWithAds' : playerWithAds,
                'getURL'      : getFLVURL
            });
        }
        else
        {
            return defaultPlayVideo(id);
        }
    }

    /*
     * Returns the URL to the FLV for the video ID supplied
     */
    function getFLVURL (id)
    {
        try
        {
            if(typeof(id) != 'object')
            {
                id = '#'+id;
            }
            var $element = $(id);
            if (!$element.length)
            {
                lzlog('getFLVURL('+id+'): failed to retrieve element DOM object');
                return null;
            }

            var URL = $element.attr('href');
            if(! URL)
            {
                var uid = $element.attr('uid');
                if (uid == null)
                {
                    // Element appears to be missing both attributes that we can use to build
                    // the video URL. We're going to make a final attempt at finding it.
                    // All Lixuz-generated video elements has an img inside them. That img tag
                    // also contains the UID for the video within its src attribute. The first
                    // int found in the img tag can be assumed to be the UID of the movie.
                    var i;
                    try
                    {
                        i = $element.find('img').attr('src').replace(/^\D+/,'').replace(/\?flvp.+$/,'');
                    } catch(e) {}
                    if(i != null && i.match(/^\d+$/))
                    {
                        uid = i;
                    }
                    else
                    {
                        lzlog('uid missing from video element that had no href');
                        return;
                    }
                }
                URL = '/files/get/'+uid+'?flv=1';
            }
            else
            {
                URL = element.attr('href');
            }
            return URL;
        }
        catch(e)
        {
            lzlog('Failed to retrieve FLV URL from '+id+': '+e.message);
            return null;
        }
    }

    /*
     * Creates a flowplayer object with the parameter hash supplied
     * and returns it
     */
    function getFP(id,options)
    {
        lzlog('Initializing flowPlayer on element '+id);
        $('#'+id).empty();
        var vid = $f(id,'/swf/flowplayer/flowplayer.swf?'+FPVER,options);
        return vid;
    }

    /*
     * A safe starter for flowplayer video players. Will gracefully fail if
     * it detects known errors.
     *
     * Returns the flowplayer object on success, null on failure.
     */
    function safePlayer (id, options)
    {
        try
        {
            var $element = $('#'+id);
            if (!$element.length)
            {
                lzlog('playVideo(): Failed to locate the player $element: '+id);
                return null;
            }
            else
            {
                /*
                 * Lixuz-generated video elements are small, and contain an <img>
                 * element. Here we perform checks for badly created ones which is
                 * usually caused by <div>s not getting closed properly. If we
                 * initialize the video even though the div doesn't look like it
                 * contains the usual Lixuz <img> tag, but something else, then we
                 * might overwrite information.
                 *
                 * This will never happen with properly generated Lixuz videos
                 */
                if($element.html().length > 200)
                {
                    lzlog('playVideo(): The html() of '+id+' exceeded 200 characters (it has '+$element.html().length+'). Suspecting an unclosed div. Refusing to initialize video.');
                    return null;
                }
                else if ( ($element.html().length > 100) && (! $element.html().match(/</)))
                {
                    lzlog('playVideo(): The html() of '+id+' exceeded 100 characters (it has '+$element.html().length+') AND it has NO HTML tags inside it. Suspecting an unclosed div. Refusing to initialize video.');
                    return null;
                }
                var vid = getFP(id,options);
                return vid;
            }
        }
        catch(err)
        {
            lzlog('Failure in safePlayer when attempting to start player on '+id+': '+err.message);
        }
        return null;
    }

    /*
     * Onload handler
     */
    $(function ()
    {
        try 
        { 
            initMedia();
        } 
        catch(e) { } 
    });

})(jQuery);
