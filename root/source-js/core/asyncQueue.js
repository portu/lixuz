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
 * Asynchronous Lixuz call and variable queues.
 *
 * This library provides a simple means to have one or many named queues of
 * either function calls that can be made asynchronously, or variables.
 *
 * The syntax for using both queues are almost identical.
 *
 * Call queue:
 *
 *  // Create a new queue
 * queue = new lixuzCallQueue();
 *  // Add a function, with parameters, to the queue.
 * queue.add(function,arguments);
 *  // Run all queued functions in the current queue iteration.
 *  // If the current queue iteration is the only one left, this will
 *  // also call newQueue().
 * queue.run();
 *  // Create a new queue iteration in the object. Subsequent add() calls
 *  // will run on a new queue, while run() will still run the oldest one.
 * queue.newQueue();
 *
 *  // Check if something is queued
 * bool = queue.hasQueue();
 *
 * Variable queue:
 *
 *  // Create a new queue
 * queue = new lixuzVariableQueue();
 *  // Add a variable to the queue.
 *  // Note: This does some special processing. If the variable is a hash
 *  //  and there is already a value set, it will .combine them.
 * queue.add(variable,content);
 *  // Get a hash of variables in the queue.
 *  // If the current queue iteration is the only one left, this will
 *  // also call newQueue().
 * queue.getVariables();
 *
 *  // Create a new queue iteration in the object. Subsequent add() calls
 *  // will run on a new queue, while getVariables() will still return the oldest one.
 * queue.newQueue();
 *
 *  // Check if something is queued
 * bool = queue.hasQueue();
 *
 * - Both: -
 *  When either run() or getVariables() is called. That iteration will be forgotten
 *  and deleted in the object, in order to avoid leaks.
 */

// TODO: Implement this. It is currently just a stub.
function lixuzCallQueue ()
{
    // Init shared methods and vars
    _LQ_sharedPrep.apply(this);
}

function lixuzVariableQueue ()
{
    this.add = _LQ_addVar;
    this.set = _LQ_addVar;
    this._curr = _LQ_getCurr;
    this.getVariables = _LQ_getQueuedVars;
    this.get = _LQ_getVar;
    this.getOrNew = _LQ_getVarOrNew;
    // Init shared methods and vars
    _LQ_sharedPrep.apply(this);
}

function _LQ_sharedPrep ()
{
    this._contents = [];
    this._contents[0] = {};
    this._lastRun = null;
    this._currQueue = 0;
    // Shared methods
    this.newQueue = _LQ_newQueue;
    this.hasQueue = _LQ_hasQueue;
}

function _LQ_getQueuedVars ()
{
    var no = this._lastRun;
    if(no == null)
    {
        no = 0;
    }
    else
    {
        no = no +1;
    }
    var ret = this._contents[no];

    this._lastRun = no;

    if(this._currQueue == this._lastRun)
    {
        this.newQueue();
    }

    return ret;
}

function _LQ_getVarOrNew (vname, type)
{
    var cont = this.get(vname);
    if(cont == null)
    {
        if(type == 'array')
        {
            cont =  [];
        }
        else if (type == 'hash')
        {
            cont = {};
        }
    }
    return cont;
}

function _LQ_getVar (vname)
{
    var curr = this._curr();
    if(curr != null)
    {
        return curr.get(vname);
    }
    else
    {
        return null;
    }
}

function _LQ_getCurr ()
{
    var curr = this._contents[this._currQueue];
    if(curr == null)
    {
        curr = {};
        this._contents[this._currQueue] = curr;
    }
    return curr;
}

function _LQ_addVar (name, content)
{
    var curr = this._curr();
    if(curr[name])
    {
        var i = curr[name];
        if(typeof(i) == 'object' && typeof(content) == 'object')
        {
            content = $.extend(content,i);
        }
    }
    curr[name] = content;
}

function _LQ_newQueue ()
{
    var curr = this._curr();
    if( (curr != null) && (curr.getLength() > 0) )
    {
        this._currQueue++;
        this._contents[this._currQueue] = {};
    }
}

function _LQ_run ()
{
}

function _LQ_queueFunc (func,args)
{
    var curr = this._curr();
    curr.push({ 'func':func, 'args':args });
}

function _LQ_hasQueue ()
{
    // If there is no data in our queue, then we have no queue
    if(this._contents[this._currQueue] == null || this._contents[this._currQueue].getLength() == 0)
    {
        return false;
    }
    // If we got this far, and either _lastRun is null, or a number under _currQueue,
    // then we have queued data.
    if(this._lastRun == null)
    {
        return true;
    }
    else if(this._lastRun < this._currQueue)
    {
        return true;
    }
    // Otherwise, we don't.
    return false;
}
