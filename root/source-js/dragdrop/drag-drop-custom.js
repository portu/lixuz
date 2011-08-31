/************************************************************************************************************

  Drag and drop
  Copyright (C) 2006  DTHMLGoodies.com, Alf Magne Kalleland

  This library is free software; you can redistribute it and/or
  modify it under the terms of the GNU Lesser General Public
  License as published by the Free Software Foundation; either
  version 2.1 of the License, or (at your option) any later version.

  This library is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
  Lesser General Public License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with this library; if not, write to the Free Software
  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA

************************************************************************************************************/

/************************************************************************************************************
*
* Global variables
*
************************************************************************************************************/

var standardObjectsCreated = false;	// The classes below will check this variable, if it is false, default help objects will be created
var clientInfoObj;	// Object of class dragDrop_clientInfo
var dhtmlSuiteConfigObj = false; 	// Object of class dragDrop_config
var dhtmlSuiteCommonObj;	// Object of class dragDrop_common

// {{{ dragDrop_createStandardObjects()
/**
 * Create objects used by all scripts
 *
 * @public
 */
    
function dragDrop_createStandardObjects()
{
	clientInfoObj = new dragDrop_clientInfo();	// Create browser info object
	clientInfoObj.init();	
	if(!dhtmlSuiteConfigObj){	// If this object isn't allready created, create it.
		dhtmlSuiteConfigObj = new dragDrop_config();	// Create configuration object.
		dhtmlSuiteConfigObj.init();
	}
	dhtmlSuiteCommonObj = new dragDrop_common();	// Create configuration object.
	dhtmlSuiteCommonObj.init();
}

/************************************************************************************************************
*	Configuration class used by most of the scripts
*
*	Created:			August, 19th, 2006
*	Purpose of class:	Store global variables/configurations used by the classes below. Example: If you want to  
*						change the path to the images used by the scripts, change it here. An object of this   
*						class will always be available to the other classes. The name of this object is 
*						"dhtmlSuiteConfigObj".	
*			
*						If you want to create an object of this class manually, remember to name it "dhtmlSuiteConfigObj"
*						This object should then be created before any other objects. This is nescessary if you want
*						the other objects to use the values you have put into the object. 
* 	Update log:
*
************************************************************************************************************/

// {{{ dragDrop_config()
/**
 * Constructor
 *
 * @public
 */
function dragDrop_config()
{
	var imagePath;	// Path to images used by the classes. 
	var cssPath;	// Path to CSS files used by the DHTML suite.		
}


dragDrop_config.prototype = {
	// {{{ init()
	/**
	 *
	 * @public
	 */
	init : function()
	{
		this.imagePath = 'images_dhtmlsuite/';	// Path to images		
		this.cssPath = 'css_dhtmlsuite/';	// Path to images		
	}	
	// }}}
	,
	// {{{ setCssPath()
    /**
     * This method will save a new CSS path, i.e. where the css files of the dhtml suite are located.
     *
     * @param string newCssPath = New path to css files
     * @public
     */
    	
	setCssPath : function(newCssPath)
	{
		this.cssPath = newCssPath;
	}
	// }}}
	,
	// {{{ setImagePath()
    /**
     * This method will save a new image file path, i.e. where the image files used by the dhtml suite ar located
     *
     * @param string newImagePath = New path to image files
     * @public
     */
	setImagePath : function(newImagePath)
	{
		this.imagePath = newImagePath;
	}
	// }}}
}

/************************************************************************************************************
*	A class with general methods used by most of the scripts
*
*	Created:			August, 19th, 2006
*	Purpose of class:	A class containing common method used by one or more of the gui classes below, 
* 						example: loadCSS. 
*						An object("dhtmlSuiteCommonObj") of this  class will always be available to the other classes. 
* 	Update log:
*
************************************************************************************************************/

// {{{ dragDrop_common()
/**
 * Constructor
 *
 */
function dragDrop_common()
{
	var loadedCSSFiles;	// Array of loaded CSS files. Prevent same CSS file from being loaded twice.
}

dragDrop_common.prototype = {
	
	// {{{ init()
    /**
     * This method initializes the dragDrop_common object.
     *
     * @public
     */
    	
	init : function()
	{
		this.loadedCSSFiles = new Array();
	}	
	// }}}
	,
	// {{{ getTopPos()
    /**
     * This method will return the top coordinate(pixel) of an object
     *
     * @param Object inputObj = Reference to HTML element
     * @public
     */	
	getTopPos : function(inputObj)
	{		
	  var returnValue = inputObj.offsetTop;
	  while((inputObj = inputObj.offsetParent) != null){
	  	if(inputObj.tagName!='HTML'){
	  		returnValue += inputObj.offsetTop;
	  		if(document.all)returnValue+=inputObj.clientTop;
	  	}
	  } 
	  return returnValue;
	}
	// }}}
	
	,
	// {{{ getLeftPos()
    /**
     * This method will return the left coordinate(pixel) of an object
     *
     * @param Object inputObj = Reference to HTML element
     * @public
     */	
	getLeftPos : function(inputObj)
	{	  
	  var returnValue = inputObj.offsetLeft;
	  while((inputObj = inputObj.offsetParent) != null){
	  	if(inputObj.tagName!='HTML'){
	  		returnValue += inputObj.offsetLeft;
	  		if(document.all)returnValue+=inputObj.clientLeft;
	  	}
	  }
	  return returnValue;
	}
	// }}}
	,
	// {{{ cancelEvent()
    /**
     *
     *  This function only returns false. It is used to cancel selections and drag
     *
     * 
     * @public
     */	
    	
	cancelEvent : function()
	{
		return false;
	}
	// }}}	
	
}


/************************************************************************************************************
*	Client info class
*
*	Created:			August, 18th, 2006
*	Purpose of class:	Provide browser information to the classes below. Instead of checking for
*						browser versions and browser types in the classes below, they should check this
*						easily by referncing properties in the class below. An object("clientInfoObj") of this 
*						class will always be accessible to the other classes. 
* 	Update log:
*
************************************************************************************************************/

/* 
Constructor 
*/

function dragDrop_clientInfo()
{
	var browser;			// Complete user agent information
	
	var isOpera;			// Is the browser "Opera"
	var isMSIE;				// Is the browser "Internet Explorer"	
	var isFirefox;			// Is the browser "Firefox"
	var navigatorVersion;	// Browser version
}
	
dragDrop_clientInfo.prototype = {
	
	/**
	* 	Constructor
	*	Params: 		none:
	*  	return value: 	none;
	**/
	// {{{ init()
    /**
     *
	 *
     *  This method initializes the script
     *
     * 
     * @public
     */	
    	
	init : function()
	{
		this.browser = navigator.userAgent;	
		this.isOpera = (this.browser.toLowerCase().indexOf('opera')>=0)?true:false;
		this.isFirefox = (this.browser.toLowerCase().indexOf('firefox')>=0)?true:false;
		this.isMSIE = (this.browser.toLowerCase().indexOf('msie')>=0)?true:false;
		this.navigatorVersion = navigator.appVersion.replace(/.*?MSIE (\d\.\d).*/g,'$1')/1;
	}	
	// }}}		
}


/************************************************************************************************************
*	Drag and drop class
*
*	Created:			August, 18th, 2006
*	Purpose of class:	A general drag and drop class. By creating objects of this class, you can make elements
*						on your web page dragable and also assign actions to element when an item is dropped on it.
*						A page should only have one object of this class.
*
*						IMPORTANT when you use this class: Don't assign layout to the dragable element ids
*						Assign it to classes or the tag instead. example: If you make <div id="dragableBox1" class="aBox">
*						dragable, don't assign css to #dragableBox1. Assign it to div or .aBox instead.
*
* 	Update log:
*
************************************************************************************************************/

var referenceToDragDropObject;	// A reference to an object of the class below. 

/* 
Constructor 
*/
function dragDrop_dragDrop()
{
	var mouse_x;					// mouse x position when drag is started
	var mouse_y;					// mouse y position when drag is started.
	
	var el_x;						// x position of dragable element
	var el_y;						// y position of dragable element
	
	var dragDropTimer;				// Timer - short delay from mouse down to drag init.
	var numericIdToBeDragged;		// numeric reference to element currently being dragged.
	var dragObjCloneArray;			// Array of cloned dragable elements. every
	var dragDropSourcesArray;		// Array of source elements, i.e. dragable elements.
	var dragDropTargetArray;		// Array of target elements, i.e. elements where items could be dropped.
	var currentZIndex;				// Current z index. incremented on each drag so that currently dragged element is always on top.
	var okToStartDrag;				// Variable which is true or false. It would be false for 1/100 seconds after a drag has been started.
									// This is useful when you have nested dragable elements. It prevents the drag process from staring on
									// parent element when you click on dragable sub element.
	var moveBackBySliding;			// Variable indicating if objects should slide into place moved back to their location without any slide animation.
}

dragDrop_dragDrop.prototype = {
	
	// {{{ init()
    /**
     * Initialize the script
     * This method should be called after you have added sources and destinations.
     * 
     * @public
     */	
	init : function()
	{
		if(!standardObjectsCreated)dragDrop_createStandardObjects();	// This line starts all the init methods
		this.currentZIndex = 10000;
		this.dragDropTimer = -1;
		this.dragObjCloneArray = new Array();
		this.numericIdToBeDragged = false;	
		this.__initDragDropScript();	
		referenceToDragDropObject = this;	
		this.okToStartDrag = true;
		this.moveBackBySliding = true;
	}
	// }}}	
	,
	// {{{ addSource()
    /**
     * Add dragable element
     *
     * @param String sourceId = Id of source
     * @param boolean slideBackAfterDrop = Slide the item back to it's original location after drop.
     * @param boolean xAxis = Allowed to slide along the x-axis(default = true, i.e. if omitted).
     * @param boolean yAxis = Allowed to slide along the y-axis(default = true, i.e. if omitted).
     * @param String dragOnlyWithinElId = You will only allow this element to be dragged within the boundaries of the element with this id.
     * @param String functionToCallOnDrag = Function to call when drag is initiated. id of element(clone and orig) will be passed to this function . clone is a copy of the element created by this script. The clone is what you see when drag is in process.
     * 
     * @public
     */	
	addSource : function(sourceId,slideBackAfterDrop,xAxis,yAxis,dragOnlyWithinElId,functionToCallOnDrag)
	{
		if(!functionToCallOnDrag)functionToCallOnDrag=false;
		if(!this.dragDropSourcesArray)this.dragDropSourcesArray = new Array();
		if(!document.getElementById(sourceId))alert('The source element with id ' + sourceId + ' does not exists');
		var obj = document.getElementById(sourceId);
		
		if(xAxis!==false)xAxis = true;
		if(yAxis!==false)yAxis = true;
				
		this.dragDropSourcesArray[this.dragDropSourcesArray.length]  = [obj,slideBackAfterDrop,xAxis,yAxis,dragOnlyWithinElId,functionToCallOnDrag];	
		obj.setAttribute('dragableElement',this.dragDropSourcesArray.length-1);
		obj.dragableElement = this.dragDropSourcesArray.length-1;
		
	}
	// }}}	
	,
	// {{{ addTarget()
    /**
     * Add drop target
     *
     * @param String targetId = Id of drop target
     * @param String functionToCallOnDrop = name of function to call on drop. 
	 *		Input to this the function specified in functionToCallOnDrop function would be 
	 *		id of dragged element 
	 *		id of the element the item was dropped on.
	 *		mouse x coordinate when item was dropped
	 *		mouse y coordinate when item was dropped     
     * 
     * @public
     */	
	addTarget : function(targetId,functionToCallOnDrop)
	{
		if(!this.dragDropTargetArray)this.dragDropTargetArray = new Array();
		if(!document.getElementById(targetId))alert('The target element with id ' + targetId + ' does not exists');
		var obj = document.getElementById(targetId);
		this.dragDropTargetArray[this.dragDropTargetArray.length]  = [obj,functionToCallOnDrop];		
	}
	// }}}	
	,
	
	// {{{ setSlide()
    /**
     * Activate or deactivate sliding animations.
     *
     * @param boolean slide = Move element back to orig. location in a sliding animation
     * 
     * @public
     */	
	setSlide : function(slide)
	{
		this.moveBackBySliding = slide;	
		
	}
	// }}}	
	,
	
	/* Start private methods */
	
	// {{{ __initDragDropScript()
    /**
     * Initialize drag drop script - this method is called by the init() method.
     * 
     * @private
     */	
	__initDragDropScript : function()
	{
		var refToThis = this;
		for(var no=0;no<this.dragDropSourcesArray.length;no++){
			var el = this.dragDropSourcesArray[no][0].cloneNode(true);
			el.onmousedown =this.__initDragDropElement;		
			el.id = 'dragDrop_dragableElement' + no;
			el.style.position='absolute';
			el.style.visibility='hidden';
			el.style.display='none';			

			this.dragDropSourcesArray[no][0].parentNode.insertBefore(el,this.dragDropSourcesArray[no][0]);
			
			el.style.top = dhtmlSuiteCommonObj.getTopPos(this.dragDropSourcesArray[no][0]) + 'px';
			el.style.left = dhtmlSuiteCommonObj.getLeftPos(this.dragDropSourcesArray[no][0]) + 'px';
					
			this.dragDropSourcesArray[no][0].onmousedown =this.__initDragDropElement;
										
			this.dragObjCloneArray[no] = el; 
		}
		
		document.documentElement.onmousemove = this.__moveDragableElement;
		document.documentElement.onmouseup = this.__stop_dragDropElement;
		document.documentElement.onselectstart = function() { return refToThis.__cancelSelectionEvent(false,this) };
		document.documentElement.ondragstart = function() { return dhtmlSuiteCommonObj.cancelEvent(false,this) };		
	}	
	// }}}	
	,	
	
	// {{{ __initDragDropElement()
    /**
     * Initialize drag process
     *
     * @param Event e = Event object, used to get x and y coordinate of mouse pointer
     * 
     * @private
     */	
	// {{{ __initDragDropElement()
    /**
     * Initialize drag process
     *
     * @param Event e = Event object, used to get x and y coordinate of mouse pointer
     * 
     * @private
     */	
	__initDragDropElement : function(e)
	{
		if(!referenceToDragDropObject.okToStartDrag)return;
		referenceToDragDropObject.okToStartDrag = false;
		setTimeout('referenceToDragDropObject.okToStartDrag = true;',100);
		if(document.all)e = event;
		referenceToDragDropObject.numericIdToBeDragged = this.getAttribute('dragableElement');
		referenceToDragDropObject.numericIdToBeDragged = referenceToDragDropObject.numericIdToBeDragged + '';
		if(referenceToDragDropObject.numericIdToBeDragged=='')referenceToDragDropObject.numericIdToBeDragged = this.dragableElement;
		referenceToDragDropObject.dragDropTimer=0;
		
		referenceToDragDropObject.mouse_x = e.clientX;
		referenceToDragDropObject.mouse_y = e.clientY;
		
		referenceToDragDropObject.currentZIndex = referenceToDragDropObject.currentZIndex + 1;
		
		referenceToDragDropObject.dragObjCloneArray[referenceToDragDropObject.numericIdToBeDragged].style.zIndex = referenceToDragDropObject.currentZIndex;
		
		referenceToDragDropObject.currentEl_allowX = referenceToDragDropObject.dragDropSourcesArray[referenceToDragDropObject.numericIdToBeDragged][2];
		referenceToDragDropObject.currentEl_allowY = referenceToDragDropObject.dragDropSourcesArray[referenceToDragDropObject.numericIdToBeDragged][3];

		var parentEl = referenceToDragDropObject.dragDropSourcesArray[referenceToDragDropObject.numericIdToBeDragged][4];
		referenceToDragDropObject.drag_minX = false;
		referenceToDragDropObject.drag_minY = false;
		referenceToDragDropObject.drag_maxX = false;
		referenceToDragDropObject.drag_maxY = false;
		if(parentEl){
			var obj = document.getElementById(parentEl);
			if(obj){
				referenceToDragDropObject.drag_minX = dhtmlSuiteCommonObj.getLeftPos(obj);
				referenceToDragDropObject.drag_minY = dhtmlSuiteCommonObj.getTopPos(obj);
				referenceToDragDropObject.drag_maxX = referenceToDragDropObject.drag_minX + obj.clientWidth;
				referenceToDragDropObject.drag_maxY = referenceToDragDropObject.drag_minY + obj.clientHeight;				
			}		
		}
		
		
		
		
		// Reposition dragable element
		if(referenceToDragDropObject.dragDropSourcesArray[referenceToDragDropObject.numericIdToBeDragged][1]){
			referenceToDragDropObject.dragObjCloneArray[referenceToDragDropObject.numericIdToBeDragged].style.top = dhtmlSuiteCommonObj.getTopPos(referenceToDragDropObject.dragDropSourcesArray[referenceToDragDropObject.numericIdToBeDragged][0]) + 'px';
			referenceToDragDropObject.dragObjCloneArray[referenceToDragDropObject.numericIdToBeDragged].style.left = dhtmlSuiteCommonObj.getLeftPos(referenceToDragDropObject.dragDropSourcesArray[referenceToDragDropObject.numericIdToBeDragged][0]) + 'px';
		}
		referenceToDragDropObject.el_x = referenceToDragDropObject.dragObjCloneArray[referenceToDragDropObject.numericIdToBeDragged].style.left.replace('px','')/1;
		referenceToDragDropObject.el_y = referenceToDragDropObject.dragObjCloneArray[referenceToDragDropObject.numericIdToBeDragged].style.top.replace('px','')/1;

		
				
		referenceToDragDropObject.__timerDragDropElement();
		

		
		return false;
	}	
	// }}}	
	,
	
	// {{{ __timerDragDropElement()
    /**
     * A small delay from mouse down to drag starts 
     * 
     * @private
     */	
	__timerDragDropElement : function()
	{
		window.thisRef = this;
		if(this.dragDropTimer>=0 && this.dragDropTimer<5){
			this.dragDropTimer = this.dragDropTimer + 1;
			setTimeout('window.thisRef.__timerDragDropElement()',2);
			return;			
		}
		if(this.dragDropTimer>=5){
			if(this.dragObjCloneArray[this.numericIdToBeDragged].style.display=='none'){
				this.dragDropSourcesArray[this.numericIdToBeDragged][0].style.visibility = 'hidden';
				this.dragObjCloneArray[this.numericIdToBeDragged].style.display = 'block';
				this.dragObjCloneArray[this.numericIdToBeDragged].style.visibility = 'visible';
				this.dragObjCloneArray[this.numericIdToBeDragged].style.top = dhtmlSuiteCommonObj.getTopPos(this.dragDropSourcesArray[this.numericIdToBeDragged][0]) + 'px';
				this.dragObjCloneArray[this.numericIdToBeDragged].style.left = dhtmlSuiteCommonObj.getLeftPos(this.dragDropSourcesArray[this.numericIdToBeDragged][0]) + 'px';
			}
		
			if(this.dragDropSourcesArray[referenceToDragDropObject.numericIdToBeDragged][5]){
				var id1 = this.dragObjCloneArray[this.numericIdToBeDragged].id + '';
				var id2 = this.dragDropSourcesArray[this.numericIdToBeDragged][0].id + '';
				
				var string = this.dragDropSourcesArray[referenceToDragDropObject.numericIdToBeDragged][5] + '("' + id1 + '","' + id2 + '")';
				eval(string);
			}			
		}		
	}	
	// }}}	
	,
	
	// {{{ __cancelSelectionEvent()
    /**
     * Cancel text selection when drag is in progress
     * 
     * @private
     */	
	__cancelSelectionEvent : function()
	{
		if(this.dragDropTimer>=0)return false;
		return true;
	}	
	// }}}	
	,
	
	// {{{ __moveDragableElement()
    /**
     * Move dragable element according to mouse position when drag is in process.
     *
     * @param Event e = Event object, used to get x and y coordinate of mouse pointer
     * 
     * @private
     */	
	__moveDragableElement : function(e)
	{
		if(document.all)e = event;
		if(referenceToDragDropObject.dragDropTimer<5)return;	
		var dragObj = referenceToDragDropObject.dragObjCloneArray[referenceToDragDropObject.numericIdToBeDragged];
		
		if(referenceToDragDropObject.currentEl_allowX){			
			
			var leftPos = (e.clientX - referenceToDragDropObject.mouse_x + referenceToDragDropObject.el_x);
			if(referenceToDragDropObject.drag_maxX){
				var tmpMaxX = referenceToDragDropObject.drag_maxX - dragObj.offsetWidth;
				if(leftPos > tmpMaxX)leftPos = tmpMaxX
				if(leftPos < referenceToDragDropObject.drag_minX)leftPos = referenceToDragDropObject.drag_minX;				
			}
			dragObj.style.left = leftPos + 'px'; 
		
		}	
		if(referenceToDragDropObject.currentEl_allowY){
			var topPos = (e.clientY - referenceToDragDropObject.mouse_y + referenceToDragDropObject.el_y);
			if(referenceToDragDropObject.drag_maxY){	
				var tmpMaxY = referenceToDragDropObject.drag_maxY - dragObj.offsetHeight;		
				if(topPos > tmpMaxY)topPos = tmpMaxY;
				if(topPos < referenceToDragDropObject.drag_minY)topPos = referenceToDragDropObject.drag_minY;	
				
			}			
			
			dragObj.style.top = topPos + 'px'; 
		}
		
	}
	// }}}	
	,
	
	// {{{ __stop_dragDropElement()
    /**
     * Drag process stopped.
     * Note! In this method "this" refers to the element being dragged. referenceToDragDropObject refers to the dragDropObject.
     *
     * @param Event e = Event object, used to get x and y coordinate of mouse pointer
     * 
     * @private
     */	
	__stop_dragDropElement : function(e)
	{
		if(referenceToDragDropObject.dragDropTimer<5)return;
		if(document.all)e = event;
			
		// Dropped on which element
		if (e.target) dropDestination = e.target;
			else if (e.srcElement) dropDestination = e.srcElement;
			if (dropDestination.nodeType == 3) // defeat Safari bug
				dropDestination = dropDestination.parentNode;	
		
		
		var leftPosMouse = e.clientX + Math.max(document.body.scrollLeft,document.documentElement.scrollLeft);
		var topPosMouse = e.clientY + Math.max(document.body.scrollTop,document.documentElement.scrollTop);
		
		if(!referenceToDragDropObject.dragDropTargetArray)referenceToDragDropObject.dragDropTargetArray = new Array();
		// Loop through drop targets and check if the coordinate of the mouse is over it. If it is, call specified drop function.
		for(var no=0;no<referenceToDragDropObject.dragDropTargetArray.length;no++){
			var leftPosEl = dhtmlSuiteCommonObj.getLeftPos(referenceToDragDropObject.dragDropTargetArray[no][0]);
			var topPosEl = dhtmlSuiteCommonObj.getTopPos(referenceToDragDropObject.dragDropTargetArray[no][0]);
			var widthEl = referenceToDragDropObject.dragDropTargetArray[no][0].offsetWidth;
			var heightEl = referenceToDragDropObject.dragDropTargetArray[no][0].offsetHeight;
			
			if(leftPosMouse > leftPosEl && leftPosMouse < (leftPosEl + widthEl) && topPosMouse > topPosEl && topPosMouse < (topPosEl + heightEl)){
				if(referenceToDragDropObject.dragDropTargetArray[no][1])eval(referenceToDragDropObject.dragDropTargetArray[no][1] + '("' + referenceToDragDropObject.dragDropSourcesArray[referenceToDragDropObject.numericIdToBeDragged][0].id + '","' + referenceToDragDropObject.dragDropTargetArray[no][0].id + '",' + e.clientX + ',' + e.clientY + ')');
				break;
			}			
		}	
		
		if(referenceToDragDropObject.dragDropSourcesArray[referenceToDragDropObject.numericIdToBeDragged][1]){
			referenceToDragDropObject.__slideElementBackIntoItsOriginalPosition(referenceToDragDropObject.numericIdToBeDragged);
		}
		
		// Variable cleanup after drop
		referenceToDragDropObject.dragDropTimer = -1;
		referenceToDragDropObject.numericIdToBeDragged = false;
									
	}	
	// }}}	
	,
	
	// {{{ __slideElementBackIntoItsOriginalPosition()
    /**
     * Slide an item back to it's original position
     *
     * @param Integer numId = numeric index of currently dragged element	
     * 
     * @private
     */	
	__slideElementBackIntoItsOriginalPosition : function(numId)
	{
		// Coordinates current element position
		var currentX = this.dragObjCloneArray[numId].style.left.replace('px','')/1;
		var currentY = this.dragObjCloneArray[numId].style.top.replace('px','')/1;
		
		// Coordinates - where it should slide to
		var targetX = dhtmlSuiteCommonObj.getLeftPos(referenceToDragDropObject.dragDropSourcesArray[numId][0]);
		var targetY = dhtmlSuiteCommonObj.getTopPos(referenceToDragDropObject.dragDropSourcesArray[numId][0]);;
		
		if(this.moveBackBySliding){
			// Call the step by step slide method
			this.__processSlide(numId,currentX,currentY,targetX,targetY);
		}else{
			this.dragObjCloneArray[numId].style.display='none';
			this.dragDropSourcesArray[numId][0].style.visibility = 'visible';			
		}
			
	}
	// }}}	
	,
	
	// {{{ __processSlide()
    /**
     * Move the element step by step in this method
     *
     * @param Int numId = numeric index of currently dragged element
     * @param Int currentX = Elements current X position
     * @param Int currentY = Elements current Y position
     * @param Int targetX = Destination X position, i.e. where the element should slide to
     * @param Int targetY = Destination Y position, i.e. where the element should slide to
     * 
     * @private
     */	
	__processSlide : function(numId,currentX,currentY,targetX,targetY)
	{				
		// Find slide x value
		var slideX = Math.round(Math.abs(Math.max(currentX,targetX) - Math.min(currentX,targetX)) / 10);		
		// Find slide y value
		var slideY = Math.round(Math.abs(Math.max(currentY,targetY) - Math.min(currentY,targetY)) / 10);
		
		if(slideY<3 && Math.abs(slideX)<10)slideY = 3;	// 3 is minimum slide value
		if(slideX<3 && Math.abs(slideY)<10)slideX = 3;	// 3 is minimum slide value
		
		
		if(currentX > targetX) slideX*=-1;	// If current x is larger than target x, make slide value negative<br>
		if(currentY > targetY) slideY*=-1;	// If current y is larger than target x, make slide value negative
		
		// Update currentX and currentY
		currentX = currentX + slideX;	
		currentY = currentY + slideY;

		// If currentX or currentY is close to targetX or targetY, make currentX equal to targetX(or currentY equal to targetY)
		if(Math.max(currentX,targetX) - Math.min(currentX,targetX) < 4)currentX = targetX;
		if(Math.max(currentY,targetY) - Math.min(currentY,targetY) < 4)currentY = targetY;

		// Update CSS position(left and top)
		this.dragObjCloneArray[numId].style.left = currentX + 'px';
		this.dragObjCloneArray[numId].style.top = currentY + 'px';	
		
		// currentX different than targetX or currentY different than targetY, call this function in again in 5 milliseconds
		if(currentX!=targetX || currentY != targetY){
			window.thisRef = this;	// Reference to this dragdrop object
			setTimeout('window.thisRef.__processSlide("' + numId + '",' + currentX + ',' + currentY + ',' + targetX + ',' + targetY + ')',5);
		}else{	// Slide completed. Make absolute positioned element invisible and original element visible
			this.dragObjCloneArray[numId].style.display='none';
			this.dragDropSourcesArray[numId][0].style.visibility = 'visible';
		}		
	}
}
