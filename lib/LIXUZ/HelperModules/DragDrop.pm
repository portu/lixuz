# LIXUZ content management system
# Copyright (C) Utrop A/S Portu media & Communications 2008-2011
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# LIXUZ::HelperModules::DragDrop
#
# This module generates drag and drop HTML and JS
#
# SYNOPSIS FOR LIST PAGE:
# use LIXUZ::HelperModules::Includes qw(add_jsIncl add_cssIncl);
# my $dnd = LIXUZ::HelperModules::DragDrop->new($c,'lzDBNAME','/path/tohandler/',
# {
#   name => DATABASE_COLUMN_FOR_NAME,
#   uid => DATABASE_COLUMN_FOR_UID,
# });
# my $html = $dnd->get_html();
# add_jsIncl($c,$dnd->get_jsfiles());
# 
# If you want to be able to drag+drop things /into/ folders:
# $c->stash->{jsOnLoad} = $dnd->get_jsonload();
#
# And then name all dragable entities with an id= dragDropEntry[NO]
# where [NO] is a number, beginning at 0 or 1, and give them a uid= attribute
# containing the entrys uid. You will also need to supply an additional hashref
# (in both the ajax handler and list page), containing the keys objClass, and optionally also:
# objClass, objColumn. See the documentation for set_flags().
#
# SYNOPSIS FOR ACTION/AJAX HANDLER:
# my $dnd = LIXUZ::HelperModules::DragDrop->new($c,'lzDBNAME','/path/tohandler/',
#   {
#   name => DATABASE_COLUMN_FOR_NAME,
#   uid => DATABASE_COLUMN_FOR_UID,
#   });
# my $return = $dnd->handleInput();
package LIXUZ::HelperModules::DragDrop;

use strict;
use warnings;
use 5.010;
use Carp;
use Scalar::Util qw(weaken);
use LIXUZ::HelperModules::Includes qw(add_jsOnLoad add_jsHeadCode);
use LIXUZ::HelperModules::JSON qw(json_response json_error);

# Summary: Create a new drag and drop object
# Returns: New object
# Usage: $object = LIXUZ::HelperModules::DragDrop->new($c, MODELNAME, AJAXPATH, { fields }, { flags });
#   $c is the catalyst object
#   MODELNAME is the name of the model we're working with, ie. LIXUZDB::LzSomething
#   AJAXPATH is the path where AJAX calls are to be sent to, ie /something/ajax
#   { fields } is a hashref, identical to what you can supply to set_fields();,
#       see the documentation for set_fields();
#   { flags } is a hashref, identical to what you can supply to set_flags();,
#       see the documentation for set_flags();
sub new
{
    my $Package = shift;
    my $self = {};
    bless($self,$Package);
    $self->{genHtml} = '';
    $self->{c} = shift;
    weaken $self->{c};
    $self->{modelName} = shift;
    if(not $self->{modelName} =~ /^LIXUZDB/)
    {
        $self->{c}->log->warn('DragDrop.pm ->new() got a modelName without a LIXUZDB:: prefix, you may want to fix that: '.join(" ",caller));
    }
    $self->{ajaxHandler} = shift;
    $self->{db_uid} = 'uid';
    $self->{db_parent} = 'parent';
    $self->{db_name} = 'name';
    $self->{flags} = {
        immutable => 0,
        onclick => undef,
        hilightUIDs => {},
    };
    my $fields = shift;
    if ($fields)
    {
        $self->set_fields($fields);
    }
    my $flags = shift;
    if ($flags)
    {
        $self->set_flags($flags);
    }
    return $self;
}

# Summary: Handle input from AJAX
# Usage: ret = object->handleInput();
# Returns: Scalar with raw content to return to client
#
# You should provide the return value unmodified to the client
sub handleInput
{
    my $self = shift;
    my $req = $self->{req} = $self->{c}->req;
    if ($req->param('deleteIds'))
    {
        return $self->_handleDelete();
    }
    elsif($req->param('renameId'))
    {
        return $self->_handleRename();
    }
    elsif($req->param('orderChange'))
    {
        return $self->_handleReOrder();
    }
    elsif($req->param('addName'))
    {
        return $self->_handleCreate();
    }
    elsif($req->param('request'))
    {
        if ($req->param('request') eq 'HTML_LIST')
        {
            return $self->_handleJSListRequest();
        }
    }
    elsif($req->param('moveToFolder'))
    {
        return $self->_handleFolderMove();
    }
    elsif($req->param('saveExpanded'))
    {
        return $self->_saveExpanded();
    }
    return $self->_ajaxReturn(undef,'UNKNOWN_REQUEST');
}

# Summary: Get HTML that is to be put into the response and then parsed
#       by the JS
# Usage: html = obj->get_html();
# Returns: Scalar with XHTML
sub get_html
{
    my $self = shift;
    my $html = $self->get_htmlOnly();
    $html .= $self->_get_JSHTML();
    return $html;
}

sub get_htmlOnly
{
    my $self = shift;
    my $obj = $self->{c}->model($self->{modelName});
    my $html = $self->_buildXHTMLTree($obj);
    return $html;
}

# Summary: Get the onload= functions
# Usage: onload = obj->get_onload();
# Returns: Arrayref with onload function *names*, usually to be put in $c->stash->{jsOnLoad};
sub get_onload
{
    return [ 'lixuz_DD_CreateDragDropEntities' ];
}

# Summary: Set database fields
# Usage: object->set_fields({field => column, field => column});
#
# This is used to define which fields in the database is what,
# here we display a quick synopsis of what is what and its default value.
#
# {
#   uid => uid,         # The UID field, unique integer identifier
#   parent => parent,   # The parent of the entry, ie. the one above it.
#                           # this field can be NULL in the db, which means
#                           # that it is a root node
#   name => name,       # The name of the entry
# }
sub set_fields
{
    my $self = shift;
    my $fields = shift;
    return if not $fields;
    foreach my $k(keys %{$fields})
    {
        if ($k eq 'uid')
        {
            $self->{db_uid} = $fields->{$k};
        }
        elsif($k eq 'parent')
        {
            $self->{db_parent} = $fields->{$k};
        }
        elsif($k eq 'name')
        {
            $self->{db_name} = $fields->{$k};
        }
        else
        {
            carp('set_fields(): unknown field: '.$k);
        }
    }
    return;
}

# Summary: Set flags
# Usage: object->set_flags({flag => value, flag => value});
#
# This is used to enable and disable certain additional features
# of this module. Here we display a quick synopsis of each flag,
# and its default value.
#
# {
#   immutable => 0,     # Don't allow moving, renaming or any other such changes
#                       # to the tree.
#
#   onclick => undef,   # Do something when a user clicks on a node. This should be
#                       # the name of the JS function you want to call when the
#                       # user clicks on a node. The functions prototype must be:
#                       # (uid). You should not add any () to this string, the module
#                       # will handle that.
#
#   objClass => undef,  # The name of the class which these folders contain. This is
#                       # only needed if you have entities which can be dropped into the folders.
#                       # You need to supply objColumn as well.
#
#   objColumn => undef, # The name of the column that contains the id of objClass.
#                              # For instance for an LzArticle this would be article_id.
#
#   hilightUIDs => {},  # Contains a hashref of key => 1 pairs of UIDs that should be hilighted
#                       # by default (ie. have an enclosing <b></b> around its label.
# }
sub set_flags
{
    my $self = shift;
    my $flags = shift;
    return if not $flags;
    my %AllowedFlags = (
        immutable => 1,
        onclick => 1,
        objClass => 1,
        objColumn => 1,
        hilightUIDs => 1,
    );
    foreach my $k(keys %{$flags})
    {
        if ($AllowedFlags{$k})
        {
            $self->{flags}->{$k} = $flags->{$k}
        }
        else
        {
            carp('set_flags(): unknown flag: '.$k);
        }
    }
    return;
}

# Summary: Get an array of javascript files to include
# Usage: arrayref = obj->get_jsfiles();
# Returns: Array of paths to javascript files relative to the js/ dir
sub get_jsfiles
{
    my $self = shift;
    return ( 'core.js','dragdrop.js' );
}

# Summary: Get an array of css files to include
# Usage: array = obj->get_cssfiles();
# Returns: Array of paths to css files relative to the css/ dir
sub get_cssfiles
{
    my $self = shift;
    return ( 'dragdrop/context-menu.css','dragdrop/drag-drop-folder-tree.css' );
}

# Summary: Mark something as a stub
# Usage: STUB();
sub STUB
{
    my ($stub_package, $stub_filename, $stub_line, $stub_subroutine, $stub_hasargs,
        $stub_wantarray, $evaltext, $is_require, $hints, $bitmask) = caller(1);
    warn "STUB: $stub_subroutine\n";
}

# -- INTERNAL METHODS - NOT FOR USE OUTSIDE OF THE MODULE, SUBJECT TO CHANGE --

# Summary: Generate a return value for the AJAX to interperate
# Usage: self->_ajaxReturn(success?, return status, return content);
#   success is a boolean, true if the action was successful, false otherwise
#   return status is the raw status value to supply
#   return content is optionally the content to return to the ajax after
#       the status
#   If return status is not supplied then it will return UNKNOWN as the
#       status
sub _ajaxReturn
{
    my $self = shift;
    my $result = shift;
    my $status = shift;
    my $content = shift;

    my $return;

    if ($result)
    {
        $return = 'OK';
    }
    else
    {
        $return = 'ERR';
    }

    if(defined $status or defined $content)
    {
        if (not defined $status or not length $status)
        {
            $status = 'UNKNOWN';
        }
        $return .= ' '.$status;
    }

    if (defined $content and length $content)
    {
        $return .= "\n";
        $return .= $content;
    }

    return $return;
}

# Summary: Handle reordering of the entries
# Usage: self->_handleReOrder();
sub _handleReOrder
{
    my $self = shift;
    my $order = $self->{req}->param('orderChange');
    my $model = $self->{c}->model($self->{modelName});
    my $error;
    foreach my $ent (split(/,/,$order))
    {
        # TODO: Do we want to validate that the parent actually exists?
        my ($uid,$parent) = split(/-/,$ent);
        next if $uid eq 'root';
        if ($uid =~ /\D/)
        {
            $self->{c}->log->error('ERROR IN DragDrop.pm->_handleReOrder: Got nondigit uid param (skipping this entry): '.$uid);
            next;
        }
        my $obj = $model->find({$self->{db_uid} => $uid});
        if(not $obj)
        {
            $self->{c}->log->error('ERROR IN DragDrop.pm->_handleReOrder: Unable to fetch object for (skipping this entry): '.$uid);
            next;
        }
        if ($parent eq 'root')
        {
            $parent = undef;
            if (not defined $obj->get_column('parent'))
            {
                next;
            }
        }
        else
        {
            if(defined $obj->get_column('parent') and $obj->get_column('parent') eq $parent)
            {
                next;
            }
        }
        $obj->set_column('parent',$parent);
        $obj->update();
    }
    if ($error)
    {
        return $self->_ajaxReturn(undef, $error);
    }
    else
    {
        return $self->_ajaxReturn(1);
    }
}

# Summary: Handle delete requests from client code
# Usage: self->_handleDelete();
sub _handleDelete
{
    my $self = shift;
    my $model = $self->{c}->model($self->{modelName});
    foreach my $uid (split(/,/,$self->{req}->param('deleteIds')))
    {
        if ($uid =~ /\D/)
        {
            $self->{c}->log->error('ERROR IN DragDrop.pm->_handleDelete: Got nondigit uid param: '.$uid);
            return $self->_ajaxReturn(undef,'NONDIGIT_PARAM - '.$uid);
        }
        my $obj = $model->find({$self->{db_uid} => $uid});
        if(not $obj->delete())
        {
            return $self->_ajaxReturn(undef,'DELETEFAIL');
        }
    }
    return $self->_ajaxReturn(1);
}

# Summary: Handle a rename request from client code
# Usage: self->_handleRename();
sub _handleRename
{
    my $self = shift;
    my $model = $self->{c}->model($self->{modelName});
    my $obj = $model->find({$self->{db_uid} => $self->{req}->param('renameId')});
    if(not $obj)
    {
        $self->{c}->log->error('Unable to locate object with uid: '.$self->{req}->param('renameId'));
        return $self->_ajaxReturn(undef,'UIDNOTFOUND');
    }
    my $newname = $self->{req}->param('newName');
    if(not $newname)
    {
        $self->{c}->log->error('newName param missing');
        return $self->_ajaxReturn(undef,'ERR MISSINGPARAM newName');
    }
    $obj->set_column($self->{db_name},$newname);
    $obj->update();
    return $self->_ajaxReturn(1);
}

# Summary: Handle an "create new node" request from client code
# Usage: self->_handleCreate();
sub _handleCreate
{
    my $self = shift;
    my $c = $self->{c};
    my $model = $c->model($self->{modelName});
    my $req = $c->req;
    my $parent = $req->param('parent');
    my $name = $req->param('addName');
    if(not $parent or not length $parent or ($parent =~ /\D/ and not $parent eq 'root'))
    {
        return json_error($c, 'INVALIDPARENT');
    }
    elsif(not $name or not length $name)
    {
        return json_error($c, 'INVALIDNAME');
    }
    my $obj = $model->create({
            $self->{db_name} => $name
        });
    if(not $obj)
    {
        return json_error($c, 'SQL_ERROR');
    }
    if(defined $parent and not $parent eq 'root')
    {
        $obj->set_column($self->{db_parent}, $parent);
    }
    else
    {
        my $pos = 0;
        foreach (qw(title lead author body publish_time expiry_time status_id folder template_id))
        {
            my $field = $c->model('LIXUZDB::LzField')->search({
                    inline => $_,
                });
            if(not $field or not $field->count > 0)
            {
                $c->log->error('Failed to locate inline field '.$_.' - going on without it');
                next;
            }
            $field = $field->next;
            $c->model('LIXUZDB::LzFieldModule')->create({
                    field_id => $field->field_id,
                    module => 'folders',
                    object_id => $obj->folder_id,
                    enabled => 1,
                    position => $pos,
                });
            $pos++;
        }
    }
    $obj->update();
    return json_response($c,{ newObj => $obj->get_column($self->{db_uid})});
}

# Summary: Handle an "move/link item to folder" request from client code
# Usage: self->_handleFolderMove();
sub _handleFolderMove
{
    my $self = shift;
    my $c = $self->{c};
    my $req = $self->{req};
    my $target = $req->param('moveToFolder');
    my $item = $req->param('item');
    if(not $target or $target =~ /\D/)
    {
        return $self->_ajaxReturn(undef,'TARGETINVALID');
    }
    if(not $item or $item =~ /\D/)
    {
        return $self->_ajaxReturn(undef,'ITEMINVALID');
    }
    if($self->{flags}->{objClass})
    {
        my $m = $c->model($self->{flags}->{objClass});
        if (!$m)
        {
            $c->log->error('DragDrop.pm: failed to look up model: '.$self->{flags}->{objClass});
            return $self->_ajaxReturn(undef, 'MODELLOOKUPERR');
        }
        $m = $m->find({$self->{flags}->{objColumn} => $item});
        if (!$m)
        {
            return $self->_ajaxReturn(undef, 'ITEMLOOKUPERR');
        }
        $m->set_column('folder_id',$target);
        $m->update();
        return $self->_ajaxReturn(1,'DONE');
    }
    else
    {
        return $self->_ajaxReturn(undef,'OBJCLASS MISSING');
    }
}

# Summary Handle an "give me the raw XHTML" request from client code
# Usage: self->_handleJSListRequest();
sub _handleJSListRequest
{
    my $self = shift;
    my $content;
    my $model = $self->{c}->model($self->{modelName});
    eval
    {
        $content = $self->_buildXHTMLTree($model,1);
    };
    if(not $content)
    {
        return $self->_ajaxReturn(undef,$@);
    }
    else
    {
        return $self->_ajaxReturn(1,'FOLLOWS',$content);
    }
}

# Summary: Build an XHTML tree structure for the JS to parse from the root
#       of the object supplied
# Usage: xhtml = obj->_buildXHTMLTree(db object, nowrap?);
# Returns: String of XHTML
#  If nowrap is true then it will not include the enclosing <ul></ul>
sub _buildXHTMLTree
{
    my $self = shift;
    my $database = shift;
    my $noWrap = shift;
    my $nodeNo = 0;
    my @RootObjs = $database->search({
        $self->{db_parent} => \'IS NULL',
    });
    my $content = '';
    if(not $noWrap)
    {
        $content .= '<ul id="treeview" class="dhtmlgoodies_tree">';
    }
    my $i18n = $self->{c}->stash->{i18n};
    $content .= $self->_getSingleNodeXHTML('root', \$nodeNo, $i18n->get('All')) . '<ul>';
    foreach my $obj (@RootObjs)
    {
        $self->_buildXHTMLTreeNode(\$content,\$nodeNo,$obj,$database);
    }
    $content .= '</ul></li>';
    if(not $noWrap)
    {
        $content .= '</ul>';
    }
    return $content;
}

# Summary: Recursively build a tree structure into the scalar ref supplied,
#       beginning at the node supplied and working down through the tree
# Usage: obj->_buildXHTMLTreeNode(\$scalar, \$nodeInt, $nodeObject, $dbObject);
# Returns: Nothing meaningful
sub _buildXHTMLTreeNode
{
    my $self = shift;
    my $content = shift;
    my $nodeNo = shift;
    if ($$nodeNo > 9999)
    {
        carp("\nDragDrop.pm::_buildXHTMLTreeNode: FATAL ERROR: Insane amount of nodes, probable eternal loop! Refusing to generate more.");
        return;
    }
    my $nodeObj = shift;
    if(not $nodeObj->can_read($self->{c}))
    {
        return;
    }
    my $database = shift;
    my @Objs = $database->search({
        $self->{db_parent} => $nodeObj->get_column($self->{db_uid}),
    });
    $$content .= $self->_getSingleNodeXHTML(
        $nodeObj->get_column($self->{db_uid}),
        $nodeNo,
        $nodeObj->get_column($self->{db_name}),
    );
    if (@Objs)
    {
        $$content .= '<ul>';
    }
    foreach my $obj (@Objs)
    {
        # Process further down the tree
        $self->_buildXHTMLTreeNode($content,$nodeNo,$obj,$database);
    }
    if (@Objs)
    {
        $$content .= '</ul>';
    }
    $$content .= '</li>';
}

# Summary: Get the HTML for a single node
# Usage: html = obj->_getSingleNodeXHTML(UID, name, \nodeNo, ignoreFlags);
# Returns: String of XHTML
# Important note: Does NOT return the </li> end tag for the node.
#       You have to add that yourself.
# If ignoreFlags is true then any flags will be ignored
sub _getSingleNodeXHTML
{
    my $self = shift;
    my $UID = shift;
    my $nodeNo = shift;
    my $name = shift;
    my $ignoreFlags = shift;
    $$nodeNo++;
    my $ret = "\n".'<li id="node'.$$nodeNo.'"';
    $ret .= ' uid="'.$UID.'"';
    if($UID eq 'root')
    {
        $ret .= ' noDrag="true" noDelete="true" noRename="true" noSiblings="true"';
    }
    elsif (not $ignoreFlags and $self->{flags}->{immutable})
    {
        $ret .= ' noDrag="true" noDelete="true" noRename="true"';
    }
    $ret .= '><a href="#" id="node'.$$nodeNo.'_string"';
    if (not $ignoreFlags and defined $self->{flags}{onclick})
    {
        # Use quotes around the UID
        $ret .= ' onclick="'.$self->{flags}{onclick}.'(\''.$UID.'\',\''.$$nodeNo.'\'); return false;"';
    }
    $ret .= '>';
    if ($self->{flags}->{hilightUIDs}{$UID})
    {
        $ret .= '<b>'.$name.'</b>';
    }
    else
    {
        $ret .= $name;
    }
    $ret .= '</a>';
    return $ret;
}

# Summary: Get javascript that initializes the treeview
# Usage: html .= obj->_get_JSHTML();
sub _get_JSHTML
{
    my $self = shift;
    my $c = $self->{c};
    my $isMSIE = $c->req->user_agent =~ /(microsoft|explorer|msie)/i ? 1 : 0;
    my $depthMsg = $c->stash->{i18n}->get('Maximum depth of nodes reached');

    my $savedVal = $self->{c}->model('LIXUZDB::LzUserConfig')->find({
            user_id => $self->{c}->user->user_id,
            name => 'folderExpanded'
        });
    my $confVal;
    if ($savedVal)
    {
        $confVal = $savedVal->value;
    }
    elsif($c->req->cookie('lixuzTreeView_expandedNodes'))
    {
        $confVal = $c->req->cookies->{'lixuzTreeView_expandedNodes'}->value;
    }
    else
    {
        $confVal = '';
    }
    $confVal =~ s/["']//g;

    my $ret = "\n";
    $ret .= '<script type="text/javascript">'."\n";
    $ret .= '$LAB.onLoaded(function () {'."\n";
    # Note: We're generating this JS as a function because the session might need to regenerate
    # it, and this way an identical treeview can be regenerated by simply replacing the HTML in the
    # document and then calling this function.
    $ret .= 'window.buildLXTreeView = function()'."\n{\n";
    $ret .= "\t" . 'try {'."\n";
    $ret .= "\t\t" . 'window.DD_expandedNodes = "'.$confVal.'";'."\n";
    $ret .= "\t\t" . 'var treeObj = new JSDragDropTree();'."\n";
    $ret .= "\t\t" . 'treeObj.setImageFolder("/static/images/dragdrop/");'."\n";
    $ret .= "\t\t" . 'treeObj.setTreeId("treeview");'."\n";
    $ret .= "\t\t" . 'treeObj.setMaximumDepth(7);'."\n";
    $ret .= "\t\t" . 'treeObj.filePathRenameItem = "'.$self->{ajaxHandler}.'";'."\n";
    $ret .= "\t\t" . 'treeObj.filePathDeleteItem = "'.$self->{ajaxHandler}.'";'."\n";
    $ret .= "\t\t" . 'window.lixuz_DD_URL = "'.$self->{ajaxHandler}.'";'."\n";
    $ret .= "\t\t" . 'treeObj.setMessageMaximumDepthReached("'.$depthMsg.'");'."\n";
    if ($self->{flags}->{immutable})
    {
        $ret .= "\t\t" . 'treeObj.renameAllowed = false;'."\n";
        $ret .= "\t\t" . 'treeObj.deleteAllowed = false;'."\n";
    }
    $ret .= "\t\t" . 'treeObj.initTree();'."\n";
    $ret .= "\t\t" . 'lixuz_DD_LastOrder = treeObj.getNodeOrders()'."\n";
    $ret .= "\t\t" . 'treeObj.orderChangeEvent = lixuz_DD_OrderChangeEvent;'."\n";
    if ($confVal eq '')
    {
        $ret .= "\t\t" . 'treeObj.expandAll();'."\n";
    }
    $ret .= "\t" . '} catch(e) {'."\n";
    $ret .= "\t\t" . 'lzException("Failed to initialize tree view: "+e.message);'."\n";
    $ret .= "\t" . '}'."\n";
    $ret .= '};'."\n";
    $ret .= 'buildLXTreeView();'."\n";
    if ($self->{flags}->{objClass})
    {
        $ret .= 'window.lixuz_DD_FolderType = "multi"'."\n";
    }
    $ret .= "});"."\n";
    $ret .= '</script>'."\n";
    return $ret;
}

# Saves expanded nodes to the db
sub _saveExpanded
{
    my $self = shift;
    my $val = $self->{c}->req->param('value');
    my $entry = $self->{c}->model('LIXUZDB::LzUserConfig')->find_or_create({
            user_id => $self->{c}->user->user_id,
            name => 'folderExpanded'
        });
    $entry->set_column('value',$val);
    $entry->update();
    return json_response($self->{c});
}

1;
