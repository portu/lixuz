/************************************************************************************************************
  Drag and drop folder tree
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

var JSTreeObj;
var treeUlCounter = 0;
var nodeId = 1;

/* Constructor */
function JSDragDropTree()
{
    var idOfTree;
    var imageFolder;
    var folderImage;
    var plusImage;
    var minusImage;
    var maximumDepth;
    var dragNode_source;
    var dragNode_parent;
    var dragNode_sourceNextSib;
    var dragNode_noSiblings;
    var ajaxObjects;

    var dragNode_destination;
    var floatingContainer;
    var dragDropTimer;
    var dropTargetIndicator;
    var insertAsSub;
    var indicator_offsetX;
    var indicator_offsetX_sub;
    var indicator_offsetY;

    this.imageFolder = 'images/';
    this.folderImage = 'dhtmlgoodies_folder.gif';
    this.plusImage = 'dhtmlgoodies_plus.gif';
    this.minusImage = 'dhtmlgoodies_minus.gif';
    this.maximumDepth = 6;
    var messageMaximumDepthReached;
    var filePathRenameItem;
    var filePathDeleteItem;
    var additionalRenameRequestParameters = {};
    var additionalDeleteRequestParameters = {};

    var renameAllowed;
    var deleteAllowed;
    var currentlyActiveItem;
    var contextMenu;
    var currentItemToEdit;		// Reference to item currently being edited(example: renamed)
    var helpObj;


    this.contextMenu = false;
    this.floatingContainer = document.createElement('UL');
    this.floatingContainer.style.position = 'absolute';
    this.floatingContainer.style.display='none';
    this.floatingContainer.id = 'floatingContainer';
    this.insertAsSub = false;
    document.body.appendChild(this.floatingContainer);
    this.dragDropTimer = -1;
    this.dragNode_noSiblings = false;
    this.currentItemToEdit = false;

    if(document.all){
        this.indicator_offsetX = 2;	// Offset position of small black lines indicating where nodes would be dropped.
        this.indicator_offsetX_sub = 4;
        this.indicator_offsetY = 2;
    }else{
        this.indicator_offsetX = 1;	// Offset position of small black lines indicating where nodes would be dropped.
        this.indicator_offsetX_sub = 3;
        this.indicator_offsetY = 2;			
    }
    if(navigator.userAgent.indexOf('Opera')>=0){
        this.indicator_offsetX = 2;	// Offset position of small black lines indicating where nodes would be dropped.
        this.indicator_offsetX_sub = 3;
        this.indicator_offsetY = -7;				
    }

    this.messageMaximumDepthReached = ''; // Use '' if you don't want to display a message 

    this.renameAllowed = true;
    this.deleteAllowed = true;
    this.currentlyActiveItem = false;
    this.filePathRenameItem = 'folderTree_updateItem.php';
    this.filePathDeleteItem = 'folderTree_updateItem.php';
    this.ajaxObjects = new Array();
    this.helpObj = false;

    this.RENAME_STATE_BEGIN = 1;
    this.RENAME_STATE_CANCELED = 2;
    this.RENAME_STATE_REQUEST_SENDED = 3;
    this.renameState = null;

    this.lastSavedValue = $.toJSON(window.DD_expandedNodes);
}


/* JSDragDropTree class */
JSDragDropTree.prototype = {
    // {{{ addEvent()
    /**
     *
     *  This function adds an event listener to an element on the page.
     *
     *	@param Object whichObject = Reference to HTML element(Which object to assigne the event)
     *	@param String eventType = Which type of event, example "mousemove" or "mouseup"
     *	@param functionName = Name of function to execute. 
     * 
     * @public
     */	
addEvent : function(whichObject,eventType,functionName)
           { 
               if(whichObject.attachEvent){ 
                   whichObject['e'+eventType+functionName] = functionName; 
                   whichObject[eventType+functionName] = function(){whichObject['e'+eventType+functionName]( window.event );} 
                   whichObject.attachEvent( 'on'+eventType, whichObject[eventType+functionName] ); 
               } else 
                   whichObject.addEventListener(eventType,functionName,false); 	    
           } 
           // }}}	
           ,	
               // {{{ removeEvent()
               /**
                *
                *  This function removes an event listener from an element on the page.
                *
                *	@param Object whichObject = Reference to HTML element(Which object to assigne the event)
                *	@param String eventType = Which type of event, example "mousemove" or "mouseup"
                *	@param functionName = Name of function to execute. 
                * 
                * @public
                */		
               removeEvent : function(whichObject,eventType,functionName)
               { 
                   if(whichObject.detachEvent){ 
                       whichObject.detachEvent('on'+eventType, whichObject[eventType+functionName]); 
                       whichObject[eventType+functionName] = null; 
                   } else 
                       whichObject.removeEventListener(eventType,functionName,false); 
               } 
           ,	
               // This function has been slightly modified
               SaveExpanded : function(value)
               {
                   var strValue = $.toJSON(value);
                   if(strValue == this.lastSavedValue)
                   {
                       return;
                   }
                   this.lastSavedValue = strValue;
                   XHR.Form.POST(lixuz_DD_URL, {
                       saveExpanded: 1,
                       value: value
                   },$.noop,$.noop);
               } 
           ,
               setFileNameRename : function(newFileName)
               {
                   this.filePathRenameItem = newFileName;
               }
           ,
               setFileNameDelete : function(newFileName)
               {
                   this.filePathDeleteItem = newFileName;
               }
           ,
               setAdditionalRenameRequestParameters : function(requestParameters)
               {
                   this.additionalRenameRequestParameters = requestParameters;
               }
           ,
               setAdditionalDeleteRequestParameters : function(requestParameters)
               {
                   this.additionalDeleteRequestParameters = requestParameters;
               }
           ,setRenameAllowed : function(renameAllowed)
           {
               this.renameAllowed = renameAllowed;			
           }
           ,
               setDeleteAllowed : function(deleteAllowed)
               {
                   this.deleteAllowed = deleteAllowed;	
               }
           ,setMaximumDepth : function(maxDepth)
           {
               this.maximumDepth = maxDepth;	
           }
           ,setMessageMaximumDepthReached : function(newMessage)
           {
               this.messageMaximumDepthReached = newMessage;
           }
           ,	
               setImageFolder : function(path)
               {
                   this.imageFolder = path;	
               }
           ,
               setFolderImage : function(imagePath)
               {
                   this.folderImage = imagePath;			
               }
           ,
               setPlusImage : function(imagePath)
               {
                   this.plusImage = imagePath;				
               }
           ,
               setMinusImage : function(imagePath)
               {
                   this.minusImage = imagePath;			
               }
           ,		
               setTreeId : function(idOfTree)
               {
                   this.idOfTree = idOfTree;			
               }	
           ,
               expandAll : function()
               {
                   var menuItems = document.getElementById(this.idOfTree).getElementsByTagName('LI');
                   for(var no=0;no<menuItems.length;no++){
                       var subItems = menuItems[no].getElementsByTagName('UL');
                       if(subItems.length>0 && subItems[0].style.display!='block'){
                           JSTreeObj.showHideNode(false,menuItems[no].id);
                       }			
                   }
               }	
           ,
               collapseAll : function()
               {
                   var menuItems = document.getElementById(this.idOfTree).getElementsByTagName('LI');
                   for(var no=0;no<menuItems.length;no++){
                       var subItems = menuItems[no].getElementsByTagName('UL');
                       if(subItems.length>0 && subItems[0].style.display=='block'){
                           JSTreeObj.showHideNode(false,menuItems[no].id);
                       }			
                   }		
               }	
           ,
               /*
                  Find top pos of a tree node
                  */
               getTopPos : function(obj){
                   var top = obj.offsetTop/1;
                   while((obj = obj.offsetParent) != null){
                       if(obj.tagName!='HTML')top += obj.offsetTop;
                   }			
                   if(document.all)top = top/1 + 13; else top = top/1 + 4;		
                   return top;
               }
           ,	
               /*
                  Find left pos of a tree node
                  */
               getLeftPos : function(obj){
                   var left = obj.offsetLeft/1 + 1;
                   while((obj = obj.offsetParent) != null){
                       if(obj.tagName!='HTML')left += obj.offsetLeft;
                   }

                   if(document.all)left = left/1 - 2;
                   return left;
               }	

           ,
               showHideNode : function(e,inputId)
               {
                   if(inputId){
                       if(!document.getElementById(inputId))return;
                       thisNode = document.getElementById(inputId).getElementsByTagName('IMG')[0]; 
                   }else {
                       thisNode = this;
                       if(this.tagName=='A')thisNode = this.parentNode.getElementsByTagName('IMG')[0];	

                   }
                   if(thisNode.style.visibility=='hidden')return;		
                   var parentNode = thisNode.parentNode;
                   inputId = parentNode.id.replace(/[^0-9]/g,'');
                   if(thisNode.src.indexOf(JSTreeObj.plusImage)>=0){
                       thisNode.src = thisNode.src.replace(JSTreeObj.plusImage,JSTreeObj.minusImage);
                       var ul = parentNode.getElementsByTagName('UL')[0];
                       ul.style.display='block';
                       if(!initExpandedNodes)initExpandedNodes = ',';
                       if(initExpandedNodes.indexOf(',' + inputId + ',')<0) initExpandedNodes = initExpandedNodes + inputId + ',';
                   }else{
                       thisNode.src = thisNode.src.replace(JSTreeObj.minusImage,JSTreeObj.plusImage);
                       parentNode.getElementsByTagName('UL')[0].style.display='none';
                       var myNodes = initExpandedNodes.split(',');
                       initExpandedNodes = null;
                       for(var no=0;no<myNodes.length;no++)
                       {
                           if(myNodes[no] && myNodes[no] != inputId)
                           {
                               initExpandedNodes = initExpandedNodes+','+myNodes[no];
                           }
                       }
                       initExpandedNodes = initExpandedNodes+',';
                   }	
                   JSTreeObj.SaveExpanded(initExpandedNodes);
                   return false;						
               }
           ,
               /* Initialize drag */
               initDrag : function(e)
               {
                   if(document.all)e = event;	

                   var subs = JSTreeObj.floatingContainer.getElementsByTagName('LI');
                   if(subs.length>0){
                       if(JSTreeObj.dragNode_sourceNextSib){
                           JSTreeObj.dragNode_parent.insertBefore(JSTreeObj.dragNode_source,JSTreeObj.dragNode_sourceNextSib);
                       }else{
                           JSTreeObj.dragNode_parent.appendChild(JSTreeObj.dragNode_source);
                       }					
                   }

                   JSTreeObj.dragNode_source = this.parentNode;
                   JSTreeObj.dragNode_parent = this.parentNode.parentNode;
                   JSTreeObj.dragNode_sourceNextSib = false;


                   if(JSTreeObj.dragNode_source.nextSibling)JSTreeObj.dragNode_sourceNextSib = JSTreeObj.dragNode_source.nextSibling;
                   JSTreeObj.dragNode_destination = false;
                   JSTreeObj.dragDropTimer = 0;
                   JSTreeObj.timerDrag();
                   return false;
               }
           ,
               timerDrag : function()
               {	
                   if(this.dragDropTimer>=0 && this.dragDropTimer<10){
                       this.dragDropTimer = this.dragDropTimer + 1;
                       setTimeout('JSTreeObj.timerDrag()',20);
                       return;
                   }
                   if(this.dragDropTimer==10)
                   {
                       JSTreeObj.floatingContainer.style.display='block';
                       JSTreeObj.floatingContainer.appendChild(JSTreeObj.dragNode_source);	
                   }
               }
           ,
               moveDragableNodes : function(e)
               {
                   if(JSTreeObj.dragDropTimer<10)return;
                   if(document.all)e = event;
                   dragDrop_x = e.clientX/1 + 5 + document.body.scrollLeft;
                   dragDrop_y = e.clientY/1 + 5 + document.documentElement.scrollTop;	

                   JSTreeObj.floatingContainer.style.left = dragDrop_x + 'px';
                   JSTreeObj.floatingContainer.style.top = dragDrop_y + 'px';

                   var thisObj = this;
                   if(thisObj.tagName=='A' || thisObj.tagName=='IMG')thisObj = thisObj.parentNode;

                   JSTreeObj.dragNode_noSiblings = false;
                   var tmpVar = thisObj.getAttribute('noSiblings');
                   if(!tmpVar)tmpVar = thisObj.noSiblings;
                   if(tmpVar=='true')JSTreeObj.dragNode_noSiblings=true;

                   if(thisObj && thisObj.id)
                   {
                       JSTreeObj.dragNode_destination = thisObj;
                       var img = thisObj.getElementsByTagName('IMG')[1];
                       var tmpObj= JSTreeObj.dropTargetIndicator;
                       tmpObj.style.display='block';

                       var eventSourceObj = this;
                       if(JSTreeObj.dragNode_noSiblings && eventSourceObj.tagName=='IMG')eventSourceObj = eventSourceObj.nextSibling;

                       var tmpImg = tmpObj.getElementsByTagName('IMG')[0];
                       if(this.tagName=='A' || JSTreeObj.dragNode_noSiblings){
                           tmpImg.src = tmpImg.src.replace('ind1','ind2');	
                           JSTreeObj.insertAsSub = true;
                           tmpObj.style.left = (JSTreeObj.getLeftPos(eventSourceObj) + JSTreeObj.indicator_offsetX_sub) + 'px';
                       }else{
                           tmpImg.src = tmpImg.src.replace('ind2','ind1');
                           JSTreeObj.insertAsSub = false;
                           tmpObj.style.left = (JSTreeObj.getLeftPos(eventSourceObj) + JSTreeObj.indicator_offsetX) + 'px';
                       }


                       tmpObj.style.top = (JSTreeObj.getTopPos(thisObj) + JSTreeObj.indicator_offsetY) + 'px';
                   }

                   return false;

               }
           ,
               dropDragableNodes:function()
               {
                   if(JSTreeObj.dragDropTimer<10){				
                       JSTreeObj.dragDropTimer = -1;
                       return;
                   }
                   var showMessage = false;
                   if(JSTreeObj.dragNode_destination){	// Check depth
                       var countUp = JSTreeObj.dragDropCountLevels(JSTreeObj.dragNode_destination,'up');
                       var countDown = JSTreeObj.dragDropCountLevels(JSTreeObj.dragNode_source,'down');
                       var countLevels = countUp/1 + countDown/1 + (JSTreeObj.insertAsSub?1:0);		

                       if(countLevels>JSTreeObj.maximumDepth){
                           JSTreeObj.dragNode_destination = false;
                           showMessage = true; 	// Used later down in this function
                       }
                   }


                   if(JSTreeObj.dragNode_destination){			
                       if(JSTreeObj.insertAsSub){
                           var uls = JSTreeObj.dragNode_destination.getElementsByTagName('UL');
                           if(uls.length>0){
                               ul = uls[0];
                               ul.style.display='block';

                               var lis = ul.getElementsByTagName('LI');

                               if(lis.length>0){	// Sub elements exists - drop dragable node before the first one
                                   ul.insertBefore(JSTreeObj.dragNode_source,lis[0]);	
                               }else {	// No sub exists - use the appendChild method - This line should not be executed unless there's something wrong in the HTML, i.e empty <ul>
                                   ul.appendChild(JSTreeObj.dragNode_source);	
                               }
                           }else{
                               var ul = document.createElement('UL');
                               ul.style.display='block';
                               JSTreeObj.dragNode_destination.appendChild(ul);
                               ul.appendChild(JSTreeObj.dragNode_source);
                           }
                           var img = JSTreeObj.dragNode_destination.getElementsByTagName('IMG')[0];					
                           img.style.visibility='visible';
                           img.src = img.src.replace(JSTreeObj.plusImage,JSTreeObj.minusImage);					


                       }else{
                           if(JSTreeObj.dragNode_destination.nextSibling){
                               var nextSib = JSTreeObj.dragNode_destination.nextSibling;
                               nextSib.parentNode.insertBefore(JSTreeObj.dragNode_source,nextSib);
                           }else{
                               JSTreeObj.dragNode_destination.parentNode.appendChild(JSTreeObj.dragNode_source);
                           }
                       }	
                       /* Clear parent object */
                       var tmpObj = JSTreeObj.dragNode_parent;
                       var lis = tmpObj.getElementsByTagName('LI');
                       if(lis.length==0){
                           var img = tmpObj.parentNode.getElementsByTagName('IMG')[0];
                           img.style.visibility='hidden';	// Hide [+],[-] icon
                           tmpObj.parentNode.removeChild(tmpObj);						
                       }

                   }else{
                       // Putting the item back to it's original location

                       if(JSTreeObj.dragNode_sourceNextSib){
                           JSTreeObj.dragNode_parent.insertBefore(JSTreeObj.dragNode_source,JSTreeObj.dragNode_sourceNextSib);
                       }else{
                           JSTreeObj.dragNode_parent.appendChild(JSTreeObj.dragNode_source);
                       }			

                   }
                   JSTreeObj.dropTargetIndicator.style.display='none';		
                   JSTreeObj.dragDropTimer = -1;	
                   if(showMessage && JSTreeObj.messageMaximumDepthReached)alert(JSTreeObj.messageMaximumDepthReached);
                   if(JSTreeObj.orderChangeEvent)
                   {
                       JSTreeObj.orderChangeEvent();
                   }
               }
           ,
               createDropIndicator : function()
               {
                   this.dropTargetIndicator = document.createElement('DIV');
                   this.dropTargetIndicator.style.position = 'absolute';
                   this.dropTargetIndicator.style.display='none';			
                   var img = document.createElement('IMG');
                   img.src = this.imageFolder + 'dragDrop_ind1.gif';
                   img.id = 'dragDropIndicatorImage';
                   this.dropTargetIndicator.appendChild(img);
                   document.body.appendChild(this.dropTargetIndicator);

               }
           ,
               dragDropCountLevels : function(obj,direction,stopAtObject){
                   var countLevels = 0;
                   if(direction=='up'){
                       while(obj.parentNode && obj.parentNode!=stopAtObject){
                           obj = obj.parentNode;
                           if(obj.tagName=='UL')countLevels = countLevels/1 +1;
                       }		
                       return countLevels;
                   }	

                   if(direction=='down'){ 
                       var subObjects = obj.getElementsByTagName('LI');
                       for(var no=0;no<subObjects.length;no++){
                           countLevels = Math.max(countLevels,JSTreeObj.dragDropCountLevels(subObjects[no],"up",obj));
                       }
                       return countLevels;
                   }	
               }		
           ,
               cancelEvent : function()
               {
                   return false;	
               }
           ,
               cancelSelectionEvent : function()
               {

                   if(JSTreeObj.dragDropTimer<10)return true;
                   return false;	
               }
           ,getNodeOrders : function(initObj,saveString)
           {

               if(!saveString)
                   var saveString = '';
               if(!initObj)
               {
                   initObj = document.getElementById(this.idOfTree);

               }
               var lis = initObj.getElementsByTagName('LI');

               if(lis.length>0){
                   var li = lis[0];
                   while(li){
                       if(li.id){
                           if(saveString.length>0)saveString = saveString + ',';
                           var numericID = li.getAttribute('uid');
                           numericParentID = li.parentNode.parentNode.getAttribute('uid');
                           saveString = saveString + numericID;
                           saveString = saveString + '-';

                           if(numericParentID == null)
                           {
                               numericParentID = 'root';
                           }
                           else if (li.parentNode.id == this.idOfTree)
                           {
                               numericParentID = 'root';
                           }
                           saveString = saveString + numericParentID;

                           var ul = li.getElementsByTagName('UL');
                           if(ul.length>0){
                               saveString = this.getNodeOrders(ul[0],saveString);	
                           }	
                       }			
                       li = li.nextSibling;
                   }
               }

               if(initObj.id == this.idOfTree){
                   return saveString;

               }
               return saveString;
           }
           ,highlightItem : function(inputObj,e)
           {
               if(JSTreeObj.currentlyActiveItem)JSTreeObj.currentlyActiveItem.className = '';
               this.className = 'highlightedNodeItem';
               JSTreeObj.currentlyActiveItem = this;
           }
           ,
               removeHighlight : function()
               {
                   if(JSTreeObj.currentlyActiveItem)JSTreeObj.currentlyActiveItem.className = '';
                   JSTreeObj.currentlyActiveItem = false;
               }
           ,
               hasSubNodes : function(obj)
               {
                   var subs = obj.getElementsByTagName('LI');
                   if(subs.length>0)return true;
                   return false;	
               }
           ,
               deleteItem : function(obj1,obj2)
               {
                   var message = 'Click OK to delete item ' + obj2.innerHTML;
                   if(this.hasSubNodes(obj2.parentNode)) message = message + ' and it\'s sub nodes';
                   if(confirm(message)){
                       this.__deleteItem_step2(obj2.parentNode);	// Sending <LI> tag to the __deleteItem_step2 method	
                   }

               }
           ,
               __refreshDisplay : function(obj)
               {
                   if(this.hasSubNodes(obj))return;

                   var img = obj.getElementsByTagName('IMG')[0];
                   img.style.visibility = 'hidden';	
               }
           ,
               __deleteItem_step2 : function(obj)
               {

                   var saveString = obj.getAttribute('uid').replace(/[^0-9]/gi,'');

                   var lis = obj.getElementsByTagName('LI');
                   for(var no=0;no<lis.length;no++){
                       saveString = saveString + ',' + lis[no].getAttribute('uid').replace(/[^0-9]/gi,'');
                   }

                   // Creating ajax object and send items
                   var ajaxIndex = JSTreeObj.ajaxObjects.length;
                   JSTreeObj.ajaxObjects[ajaxIndex] = new sack();
                   JSTreeObj.ajaxObjects[ajaxIndex].method = "GET";
                   JSTreeObj.ajaxObjects[ajaxIndex].setVar("deleteIds", saveString);
                   JSTreeObj.__addAdditionalRequestParameters(JSTreeObj.ajaxObjects[ajaxIndex], JSTreeObj.additionalDeleteRequestParameters);
                   JSTreeObj.ajaxObjects[ajaxIndex].requestFile = JSTreeObj.filePathDeleteItem;	// Specifying which file to get
                   JSTreeObj.ajaxObjects[ajaxIndex].onCompletion = function() { JSTreeObj.__deleteComplete(ajaxIndex,obj); } ;	// Specify function that will be executed after file has been found
                   JSTreeObj.ajaxObjects[ajaxIndex].runAJAX();		// Execute AJAX function				


               }
           ,
               __deleteComplete : function(ajaxIndex,obj)
               {
                   if(this.ajaxObjects[ajaxIndex].response!='OK'){
                       alert('ERROR WHEN TRYING TO DELETE NODE: ' + this.ajaxObjects[ajaxIndex].response); 	// Rename failed
                   }else{
                       var parentRef = obj.parentNode.parentNode;
                       obj.parentNode.removeChild(obj);
                       this.__refreshDisplay(parentRef);

                   }			

               }
           ,
               __renameComplete : function(ajaxIndex)
               {
                   if(this.ajaxObjects[ajaxIndex].response!='OK'){
                       alert('ERROR WHEN TRYING TO RENAME NODE: ' + this.ajaxObjects[ajaxIndex].response); 	// Rename failed
                   }
               }
           ,
               __saveTextBoxChanges : function(e,inputObj)
               {
                   if(!inputObj && this)inputObj = this;
                   if(document.all)e = event;
                   if(e.keyCode && e.keyCode==27){
                       JSTreeObj.__cancelRename(e,inputObj);
                       return;
                   }
                   inputObj.style.display='none';
                   inputObj.nextSibling.style.visibility='visible';
                   if(inputObj.value.length>0){
                       inputObj.nextSibling.innerHTML = inputObj.value;	
                       // Send changes to the server.
                       if (JSTreeObj.renameState != JSTreeObj.RENAME_STATE_BEGIN) {
                           return;
                       }
                       JSTreeObj.renameState = JSTreeObj.RENAME_STATE_REQUEST_SENDED;

                       var ajaxIndex = JSTreeObj.ajaxObjects.length;
                       JSTreeObj.ajaxObjects[ajaxIndex] = new sack();
                       JSTreeObj.ajaxObjects[ajaxIndex].method = "GET";
                       JSTreeObj.ajaxObjects[ajaxIndex].setVar("renameId", inputObj.parentNode.getAttribute('uid').replace(/[^0-9]/gi,''));
                       JSTreeObj.ajaxObjects[ajaxIndex].setVar("newName", inputObj.value);
                       JSTreeObj.__addAdditionalRequestParameters(JSTreeObj.ajaxObjects[ajaxIndex], JSTreeObj.additionalRenameRequestParameters);
                       JSTreeObj.ajaxObjects[ajaxIndex].requestFile = JSTreeObj.filePathRenameItem;	// Specifying which file to get
                       JSTreeObj.ajaxObjects[ajaxIndex].onCompletion = function() { JSTreeObj.__renameComplete(ajaxIndex); } ;	// Specify function that will be executed after file has been found
                       JSTreeObj.ajaxObjects[ajaxIndex].runAJAX();		// Execute AJAX function		



                   }
               }
           ,
               __cancelRename : function(e,inputObj)
               {
                   JSTreeObj.renameState = JSTreeObj.RENAME_STATE_CANCELD;
                   if(!inputObj && this)inputObj = this;
                   inputObj.value = JSTreeObj.helpObj.innerHTML;
                   inputObj.nextSibling.innerHTML = JSTreeObj.helpObj.innerHTML;
                   inputObj.style.display = 'none';
                   inputObj.nextSibling.style.visibility = 'visible';
               }
           ,
               __renameCheckKeyCode : function(e)
               {
                   if(document.all)e = event;
                   if(e.keyCode==13){	// Enter pressed
                       JSTreeObj.__saveTextBoxChanges(false,this);	
                   }	
                   if(e.keyCode==27){	// ESC pressed
                       JSTreeObj.__cancelRename(false,this);
                   }
               }
           ,
               __createTextBox : function(obj)
               {
                   var textBox = document.createElement('INPUT');
                   textBox.className = 'folderTreeTextBox';
                   textBox.value = obj.innerHTML;
                   obj.parentNode.insertBefore(textBox,obj);	
                   textBox.id = 'textBox' + obj.parentNode.id.replace(/[^0-9]/gi,'');
                   textBox.onblur = this.__saveTextBoxChanges;	
                   textBox.onkeydown = this.__renameCheckKeyCode;
                   this.__renameEnableTextBox(obj);
               }
           ,
               __renameEnableTextBox : function(obj)
               {
                   JSTreeObj.renameState = JSTreeObj.RENAME_STATE_BEGIN;
                   obj.style.visibility = 'hidden';
                   obj.previousSibling.value = obj.innerHTML;
                   obj.previousSibling.style.display = 'inline';	
                   obj.previousSibling.select();
               }
           ,
               renameItem : function(obj1,obj2)
               {
                   currentItemToEdit = obj2.parentNode;	// Reference to the <li> tag.
                   if(!obj2.previousSibling || obj2.previousSibling.tagName.toLowerCase()!='input'){
                       this.__createTextBox(obj2);
                   }else{
                       this.__renameEnableTextBox(obj2);
                   }
                   this.helpObj.innerHTML = obj2.innerHTML;

               }
           ,
               initTree : function()
               {
                   JSTreeObj = this;
                   if(this.renameAllowed || this.deleteAllowed)
                   {
                       JSTreeObj.createDropIndicator();
                       document.documentElement.onselectstart = JSTreeObj.cancelSelectionEvent;
                       document.documentElement.ondragstart = JSTreeObj.cancelEvent;
                       document.documentElement.onmousedown = JSTreeObj.removeHighlight;
                   }

                   /* Creating help object for storage of values */
                   this.helpObj = document.createElement('DIV');
                   this.helpObj.style.display = 'none';
                   document.body.appendChild(this.helpObj);

                   /* Create context menu */
                   if(this.deleteAllowed || this.renameAllowed){
                       try{
                           /* Creating menu model for the context menu, i.e. the datasource */
                           var menuModel = new DHTMLGoodies_menuModel();
                           if(this.deleteAllowed)menuModel.addItem(1,'Delete','','',false,'JSTreeObj.deleteItem');
                           if(this.renameAllowed)menuModel.addItem(2,'Rename','','',false,'JSTreeObj.renameItem');
                           menuModel.addItem(3,'Add new','','',false,'lixuz_DD_NewItem');
                           menuModel.init();	

                           var menuModelRenameOnly = new DHTMLGoodies_menuModel();
                           if(this.renameAllowed)menuModelRenameOnly.addItem(3,'Rename','','',false,'JSTreeObj.renameItem');
                           menuModelRenameOnly.addItem(5,'Add new','','',false,'lixuz_DD_NewItem');
                           menuModelRenameOnly.init();	

                           var menuModelDeleteOnly = new DHTMLGoodies_menuModel();
                           if(this.deleteAllowed)menuModelDeleteOnly.addItem(4,'Delete','','',false,'JSTreeObj.deleteItem');
                           menuModelDeleteOnly.addItem(6,'Add new','','',false,'lixuz_DD_NewItem');
                           menuModelDeleteOnly.init();	

                           window.refToDragDropTree = this;

                           this.contextMenu = new DHTMLGoodies_contextMenu();
                           this.contextMenu.setWidth(120);
                           referenceToDHTMLSuiteContextMenu = this.contextMenu;
                       }catch(e){

                       }
                   }


                   var nodeId = 0;
                   var dhtmlgoodies_tree = document.getElementById(this.idOfTree);
                   var menuItems = dhtmlgoodies_tree.getElementsByTagName('LI');	// Get an array of all menu items
                   for(var no=0;no<menuItems.length;no++){
                       // No children var set ?
                       var noChildren = false;
                       var tmpVar = menuItems[no].getAttribute('noChildren');
                       if(!tmpVar)tmpVar = menuItems[no].noChildren;
                       if(tmpVar=='true')noChildren=true;
                       // No drag var set ?
                       var noDrag = false;
                       var tmpVar = menuItems[no].getAttribute('noDrag');
                       if(!tmpVar)tmpVar = menuItems[no].noDrag;
                       if(tmpVar=='true')noDrag=true;

                       nodeId++;
                       var subItems = menuItems[no].getElementsByTagName('UL');
                       var img = document.createElement('IMG');
                       img.src = this.imageFolder + this.plusImage;
                       img.onclick = JSTreeObj.showHideNode;

                       if(subItems.length==0)img.style.visibility='hidden';else{
                           subItems[0].id = 'tree_ul_' + treeUlCounter;
                           treeUlCounter++;
                       }
                       var aTag = menuItems[no].getElementsByTagName('A')[0];
                       aTag.id = 'nodeATag' + menuItems[no].id.replace(/[^0-9]/gi,'');
                       //aTag.onclick = JSTreeObj.showHideNode;
                       if(!noDrag)aTag.onmousedown = JSTreeObj.initDrag;
                       if(!noChildren)aTag.onmousemove = JSTreeObj.moveDragableNodes;
                       menuItems[no].insertBefore(img,aTag);
                       //menuItems[no].id = 'dhtmlgoodies_treeNode' + nodeId;
                       var folderImg = document.createElement('IMG');
                       if(!noDrag)folderImg.onmousedown = JSTreeObj.initDrag;
                       folderImg.onmousemove = JSTreeObj.moveDragableNodes;
                       if(menuItems[no].className){
                           folderImg.src = this.imageFolder + menuItems[no].className;
                       }else{
                           folderImg.src = this.imageFolder + this.folderImage;
                       }
                       menuItems[no].insertBefore(folderImg,aTag);

                       if(this.contextMenu){
                           var noDelete = menuItems[no].getAttribute('noDelete');
                           if(!noDelete)noDelete = menuItems[no].noDelete;
                           var noRename = menuItems[no].getAttribute('noRename');
                           if(!noRename)noRename = menuItems[no].noRename;

                           if(noRename=='true' && noDelete=='true'){}else{
                               if(noDelete == 'true')this.contextMenu.attachToElement(aTag,false,menuModelRenameOnly);
                               else if(noRename == 'true')this.contextMenu.attachToElement(aTag,false,menuModelDeleteOnly);
                               else this.contextMenu.attachToElement(aTag,false,menuModel);

                           }
                       }
                       this.addEvent(aTag,'contextmenu',this.highlightItem);



                   }	



                   initExpandedNodes = window.DD_expandedNodes;
                   if(initExpandedNodes){
                       var nodes = initExpandedNodes.split(',');
                       for(var no=0;no<nodes.length;no++){
                           if(nodes[no])this.showHideNode(false,'node'+nodes[no],true);	
                       }			
                   }			


                   document.documentElement.onmousemove = JSTreeObj.moveDragableNodes;	
                   document.documentElement.onmouseup = JSTreeObj.dropDragableNodes;
               }
           ,
               __addAdditionalRequestParameters : function(ajax, parameters)
               {
                   for (var parameter in parameters) {
                       ajax.setVar(parameter, parameters[parameter]);
                   }
               }
}
