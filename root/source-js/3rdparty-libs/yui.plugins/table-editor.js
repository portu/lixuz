YAHOO.widget.Editor.prototype.initTableEditor = function(container) {
  var Dom = YAHOO.util.Dom, 
         Event = YAHOO.util.Event,
         Connect = YAHOO.util.Connect;

  var currentTable = null;
  var currentCell = null;
  
  var tableForm = '<form id="' + this.get('id') + '_table_form" class="yui-table-form">\n' +
    '<div>\n' + 
    '<label for="rows"><strong>Rows:</strong><input type="textbox" name="rows" id="' + this.get('id') + '_table_rows" class="number" /></label>\n' +
    '<label for="cols"><strong>Cols:</strong><input type="textbox" name="cols" id="' + this.get('id') + '_table_cols" class="number" /></label>\n' +
    '</div>\n' + 
    '<div>\n' + 
    '<label for="width"><strong>Width:</strong><input type="textbox" name="width" id="' + this.get('id') + '_table_width" class="number"/><select id="' + this.get('id') + '_table_width_type" name="width_type"><option>%</option><option>px</option></select></label>\n' +
    '</div>\n' + 
    '</form>\n';
  
  var cellForm = '<form id="' + this.get('id') + '_cell_form">\n' +
    '<label for="width"><strong>Width:</strong><input type="textbox" name="width" id="' + this.get('id') + '_cell_width" class="number"/><select id="' + this.get('id') + '_cell_width_type" name="width_type"><option>%</option><option>px</option></select></label>\n' +
    '</form>\n';

  var tableEditorToolbar = null;
  
  var tableToolbarConfig = {
    buttonType: this._defaultToolbar.buttonType,
      buttons: [
        { group: 'padding', label: this.STR_IMAGE_PADDING + ':',
          buttons: [
            { type: 'spin', label: '0', value: 'padding', range: [0, 50] }
          ]
        },
        { type: 'separator' },
        { group: 'border', label: this.STR_IMAGE_BORDER + ':',
          buttons: [
            { type: 'select',  value: 'bordersize', 
              menu: [
                { text: 'none', value: '0', checked: true },
                { text: '1px', value: '1' },
                { text: '2px', value: '2' },
                { text: '3px', value: '3' },
                { text: '4px', value: '4' },
                { text: '5px', value: '5' }
              ]
            },
          { type: 'select',  value: 'bordertype', disabled: true, 
            menu: [
              { text: 'Solid', value: 'solid', checked: true },
              { text: 'Dashed', value: 'dashed' },
              { text: 'Dotted', value: 'dotted' }
            ]
          },
          { type: 'color', label: 'Border Color', value: 'bordercolor', disabled: true }
        ]
      }
    ]
  };


  var updateCols = function() {
    var form = this.form
    var rows = currentTable.getElementsByTagName('tr').length;
    var cols  = currentTable.getElementsByTagName('tr')[0].getElementsByTagName('td').length;

    if (form.cols.value < cols) {
      for (var i=cols-1;i>=form.cols.value;i--) {
        var trs = currentTable.getElementsByTagName('tr');
        for (var j=0; j<trs.length; j++) {
          trs[j].deleteCell(i);
        }
      }

    } else if (form.cols.value > cols) {
      for (var i=cols;i<form.cols.value;i++) {
        var trs = currentTable.getElementsByTagName('tr');
        for (var j=0; j<trs.length; j++) {
          var cell = newCell(trs[j].insertCell(-1));
        }
      }
    }
  }

  var updateRows = function() {
    var form = this.form
    var rows = currentTable.getElementsByTagName('tr').length;
    var cols  = currentTable.getElementsByTagName('tr')[0].getElementsByTagName('td').length;

    if (form.rows.value < rows) {
      for (var i=rows-1;i>=form.rows.value;i--) {
        currentTable.deleteRow(i);
      }
    } else if (form.rows.value > rows) {
      for (var i=rows;i<form.rows.value;i++) {
        var row = currentTable.insertRow(-1);
        for (var j=1; j<=cols; j++) {
          var cell = newCell(row.insertCell(-1));
        }
      }
    }
  }

  var insertRow = function(idx) {
    var cols  = currentTable.getElementsByTagName('tr')[0].getElementsByTagName('td').length;
    var row = currentTable.insertRow(idx);
    for (var j=1; j<=cols; j++) {
      var cell = newCell(row.insertCell(-1));
    }
  };

  var insertRowBefore = function() {
    insertRow(currentCell.parentNode.rowIndex);
  }

  var insertRowAfter = function() {
    insertRow(currentCell.parentNode.rowIndex + 1);
  }

  var deleteRow = function() {
    currentTable.deleteRow(currentCell.parentNode.rowIndex);
  };

  var insertCell = function(idx) {
    var trs = currentTable.getElementsByTagName('tr');
    for (var j=0; j<trs.length; j++) {
      var cell = newCell(trs[j].insertCell(idx));
    }
  }

  var insertCellBefore = function() {
    insertCell(currentCell.cellIndex);
  }

  var insertCellAfter = function() {
    insertCell(currentCell.cellIndex + 1);
  }

  var deleteCell = function() {
    var idx = currentCell.cellIndex;
    var trs = currentTable.getElementsByTagName('tr');
    for (var j=0; j<trs.length; j++) {
      trs[j].deleteCell(idx);
    }
  }

  var deleteTable = function() {
    currentTable.parentNode.removeChild(currentTable);
  }

  var newCell = function(cell) {
    var el = currentCell;
    copyCellStyle(el, cell);
    if (YAHOO.env.ua.gecko) {
      cell.innerHTML = " <br/>";
    } else {
      cell.innerHTML = " ";
    }
  }

  var copyCellStyle = function(from, to) {
    to.style.padding = from.style.padding;
    to.style.borderColor = from.style.borderColor;
    to.style.borderStyle = from.style.borderStyle;
    to.style.borderWidth = from.style.borderWidth;
  }


  var getParentElementByTagName = function(el, tn) {
    if (el.parentNode && el.parentNode.tagName) {
      if (el.parentNode.tagName.toLowerCase() == tn) {
        return el.parentNode;
      } else {
        return getParentElementByTagName(el.parentNode, tn);
      }
    }
  }

  var hasParent = function(el, tn) {
    if (el.parentNode && el.parentNode.tagName) {
      if (el.parentNode.tagName.toLowerCase() == tn) {
        return true;
      } else {
        return hasParent(el.parentNode, tn);
      }
    }
    return false;
  }

  var handleTableWindow = function() {
    tableEditor = new YAHOO.widget.EditorWindow("inserttable", {
        width: "350px"
    });
    tableEditor.setHeader("Table Properties");
    currentCell = this.currentElement[0];

    var table = getParentElementByTagName(currentCell, "table");
    if (table == null) {
      this.execCommand("inserthtml",
        "<table cellpadding=0 cellspacing=0 style='border-collapse: collapse; width:100%' id='new_table_tmp'><tr><td> </td><td> </td><td> </td></tr><tr><td> </td><td> </td><td> </td></tr></table>");
      table = this._getDoc().getElementById("new_table_tmp");
      this.currentElement = [table.getElementsByTagName("td")[0]];
      table.id = "";
    }

    currentTable = table;
    this.openWindow(tableEditor);
    this.toolbar.selectButton('inserttable');

    var form = document.getElementById(this.get('id') + "_table_form");

    var table_width = table.style.width;
    if (table_width.match("%$")) {
      form.width.value = table_width.replace('%', '');
      form.width_type.selectedIndex = 0;
    } else if (table_width.match("px$")) {
      form.width.value = table_width.replace('px', '');
      form.width_type.selectedIndex = 1;
    } else {
      form.width.value = '';
      form.width_type.selectedIndex = 0;
    }
    form.rows.value = table.getElementsByTagName('tr').length;
    form.cols.value = table.getElementsByTagName('tr')[0].getElementsByTagName('td').length;
    
    var paddingButton = tableEditorToolbar.getButtonByValue('padding');
    paddingButton.set('label', currentTable.cellPadding);

    var bsize = '0', btype = 'solid';

    if (currentCell.style.borderLeftWidth) {
      bsize = parseInt(currentCell.style.borderLeftWidth, 10);
    }
    if (currentCell.style.borderLeftStyle) {
      btype = currentCell.style.borderLeftStyle;
    }

    var bs_button = tableEditorToolbar.getButtonByValue('bordersize'),
          bSizeStr = ((parseInt(bsize, 10) > 0) ? '' : this.STR_NONE);
    bs_button.set('label', '<span class="yui-toolbar-bordersize-' + bsize + '">' + bSizeStr + '</span>');
    this._updateMenuChecked('bordersize', bsize, tableEditorToolbar);

    var bt_button = tableEditorToolbar.getButtonByValue('bordertype');
    bt_button.set('label', '<span class="yui-toolbar-bordertype-' + btype + '">asdfa</span>');
    this._updateMenuChecked('bordertype', btype, tableEditorToolbar);
    if (parseInt(bsize, 10) > 0) {
      tableEditorToolbar.enableButton(bt_button);
      tableEditorToolbar.enableButton(bs_button);
      tableEditorToolbar.enableButton('bordercolor');
    } else {
      tableEditorToolbar.disableButton(bt_button);
      tableEditorToolbar.disableButton('bordercolor');
    }
                                                                                                                    
    
    Event.on(this.get('id') + '_table_width', 'blur', function() {
      currentTable.style.width = this.form.width.value + this.form.width_type.value;
    });
    Event.on(this.get('id') + '_table_width_type', 'change', function() {
      currentTable.style.width = this.form.width.value + this.form.width_type.value;
    });
    Event.on(this.get('id') + '_table_rows', 'blur', updateRows);
    Event.on(this.get('id') + '_table_cols', 'blur', updateCols);

  }

  var handleCellWindow = function() {
    cellEditor = new YAHOO.widget.EditorWindow("celleditor", {
        width: "300px"
    });
    cellEditor.setHeader("Cell Properties");
    this.openWindow(cellEditor);

    var form = document.getElementById(this.get('id') + "_cell_form");
    var cell_width = currentCell.style.width;
    if (cell_width.match("%$")) {
      form.width.value = cell_width.replace('%', '');
      form.width_type.selectedIndex = 0;
    } else if (cell_width.match("px$")) {
      form.width.value = cell_width.replace('px', '');
      form.width_type.selectedIndex = 1;
    } else {
      form.width.value = '';
      form.width_type.selectedIndex = 0;
    }
    
    var editor = this;
    Event.on(this.get('id') + '_cell_width', 'blur', function() {
      editor.currentElement[0].style.width = this.form.width.value + this.form.width_type.value;
    });

    Event.on(this.get('id') + '_cell_width_type', 'change', function() {
      editor.currentElement[0].style.width = this.form.width.value + this.form.width_type.value;
    });
  }

  this.cmd_inserttable = function() {
    this.currentElement = [this._getSelectedElement()];
    handleTableWindow.call(this);
    return [false]
  }

  this.on('windowRender', function() {
      var body = document.createElement('div');
      body.id = 'table_container';
      body.innerHTML = tableForm;

      var toolbarCont = document.createElement("div");
      toolbarCont.id = "table_toolbar";
      var toolbar = new YAHOO.widget.Toolbar(toolbarCont, tableToolbarConfig);

      var editor = this;

      toolbar.on('paddingClick', function(o) {
        var table = getParentElementByTagName(editor.currentElement[0], "table");
        var button = toolbar.getButtonById(o.button.id);
        table.cellPadding = button.get('label');
      });

      toolbar.on('bordersizeClick', function(o) {
        var table = getParentElementByTagName(editor.currentElement[0], "table");
        var cells = table.getElementsByTagName('td');
        if (o.button.value == 0) {
          toolbar.disableButton("bordertype");
          toolbar.disableButton("bordercolor");
          for (var i=0;i<cells.length;i++) {
            cells[i].style.borderStyle = null;
            cells[i].style.borderColor = null;
            cells[i].style.borderWidth = null;
          }
        } else {
          toolbar.enableButton("bordertype");
          toolbar.enableButton("bordercolor");
          for (var i=0;i<cells.length;i++) {
            if (cells[i].style.borderStyle == '') {
              cells[i].style.borderStyle = 'solid';
            }
            if (cells[i].style.borderColor == '') {
              cells[i].style.borderColor = '#000';
            }
            cells[i].style.borderWidth = o.button.value + 'px';
          }
        }
      });

      toolbar.on('bordertypeClick', function(o) {
        var table = getParentElementByTagName(editor.currentElement[0], "table");
        var cells = table.getElementsByTagName('td');
        if (o.button.value == 0) {
          for (var i=0;i<cells.length;i++) {
            cells[i].style.borderStyle = null;
          }
        } else {
          for (var i=0;i<cells.length;i++) {
            cells[i].style.borderStyle = o.button.value;
          }
        }
      });

      toolbar.on('colorPickerClicked', function(o) {
        var table = getParentElementByTagName(editor.currentElement[0], "table");
        var cells = table.getElementsByTagName('td');
        for (var i=0;i<cells.length;i++) {
          cells[i].style.borderColor = "#" + o.color;
        }
      });

      tableEditorToolbar = toolbar;

      body.appendChild(toolbarCont);

      this._windows.inserttable = {
          body: body
      };

      var cell = document.createElement('div');
      cell.id = 'cell_container';
      cell.innerHTML = cellForm;

      this._windows.celleditor = {
          body: cell
      };
  });

  this.on('editorContentLoaded', function() {
    try{this._getDoc().execCommand('enableInlineTableEditing',false,false);} catch
    (ex){  }

    var editor = this;

    var menuItems = [
      [{ 
        text: "Insert Row Before", onclick: { fn: function() { insertRowBefore(); }  }
      },
      {
        text: "Insert Row After", onclick: { fn: function() { insertRowAfter(); }  }
      },
      {
        text: "Delete Row", onclick: { fn: function() { deleteRow(); }  }
      }], 
      [{
        text: "Insert Column Before", onclick: { fn: function() { insertCellBefore(); } }
      },
      {
        text: "Insert Column After", onclick: { fn: function() { insertCellAfter(); } }
      },
      {
        text: "Delete Column", onclick: { fn: function() { deleteCell(); } }
      },
      {
        text: "Edit Column", onclick: { fn: function() { handleCellWindow.call(editor); } }
      }], 
      [{
        text: "Edit Table", onclick: { fn: function() { handleTableWindow.call(editor); } }
      }, 
      {
        text: "Delete Table", onclick: { fn: function() { deleteTable.call(editor); } }
      }]
    ];


    var tableMenu = new YAHOO.widget.ContextMenu("tableMenu",
      {
        itemdata: menuItems,
        container: container ? container : document.body,
        lazyload: true
      }
    );

    Event.on(this._getDoc(), "contextmenu", function(e) {
      currentCell = editor._getSelectedElement();
      currentTable = getParentElementByTagName(currentCell, "table");
      editor.currentElement = [currentCell];

      if (currentCell && currentCell.tagName && currentCell.tagName.toLowerCase() == 'td') {
        tableMenu.show();
        var iframeRegion = Dom.getRegion(editor.get('iframe'));

        var x = Event.getXY(e)[0] + (iframeRegion.left - Dom.getDocumentScrollLeft(editor._getDoc()));
        var y = Event.getXY(e)[1] + (iframeRegion.top - Dom.getDocumentScrollTop(editor._getDoc())); 

        tableMenu.cfg.setProperty('x', x);
        tableMenu.cfg.setProperty('y', y);
        Event.stopEvent(e);
      }
    });

    Event.on(this._getDoc(), "click", function(e) {
      tableMenu.hide();
    });
        
  }, this, true);

}

