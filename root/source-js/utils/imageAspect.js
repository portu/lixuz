/*
 * Purpose: Recalculate the aspect ratio of a image
 * Usage: new_XY = get_new_aspect(oldWidth, oldHeight, newWidth, newHeight);
 * Only supply one of newHeight and newWidth (make the other null)
 * Returns the new width or height, keeping the aspect ratio
 *
 * JS equalent to get_new_aspect() from LIXUZ::HelperModules::Files
 *
 * Same syntax, some additional error handling (original die()s),
 * this one returns null on failure.
 */
function image_get_new_aspect (oldWidth, oldHeight, newWidth, newHeight)
{
    try
    {
        var percentage_change, oldVal, newVal, changeVal;

        if(newWidth != null)
        {
            oldVal = oldWidth;
            newVal = newWidth;
            changeVal = oldHeight;
        }
        else
        {
            oldVal = oldHeight;
            newVal = newHeight;
            changeVal = oldWidth;
        }

        if(oldWidth == null && newWidth == null && oldHeight == null && newHeight == null)
        {
            lzError('Programmer says: all of (new|old)(Width|Height) were null. Something went wrong. Please report this');
            return null;
        }

        if(oldVal == 0 || newVal == 0)
        {
            lzError('oldVal or newVal in image_get_new_aspect() is zero, ignoring');
            return null;
        }

        percentage_change = oldVal/newVal;

        if(changeVal == 0 || percentage_change == 0)
        {
            lzError("changeVal or percentage_change is zero, ignoring");
            return null;
        }
        var ret = Math.round(changeVal / percentage_change);
        if(ret == null)
        {
            lzError("Programmer says: Math.round("+changeVal+'/'+percentage_change+') failed. Something went wrong. Please report this.');
        }
        return ret;
    }
    catch(e)
    {
        lzException(e);
        return null;
    }
}

