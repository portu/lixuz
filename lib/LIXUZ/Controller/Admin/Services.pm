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

# This file contains various Lixuz back-end services that doesn't really
# fit any of the others, or is too generic to be tied to a specific controller.
package LIXUZ::Controller::Admin::Services;
use Moose;
use namespace::autoclean;
BEGIN { extends 'Catalyst::Controller' };

use LIXUZ::HelperModules::JSON qw(json_response json_error);
use JSON::XS;
use Try::Tiny;
use LIXUZ::HelperModules::Search qw(perform_search);
use LIXUZ::HelperModules::Cache qw(get_ckey CT_24H);
use LIXUZ::HelperModules::RevisionHelpers qw(get_latest_article);
use constant {
    TYPE_PREFORMATTED => 1,
    TYPE_HASH => 2,
    TYPE_EXTENDED_HASH => 3,
    TYPE_HASHINFO => 4,
    true => 1,
    false => 0,
    };

# Summary: Handler for "merged" ajax requests
# This subroutine performs routing of requests from the client side where it
# has requested information from multiple sources at the same time.
sub multiRequest : Local
{
    my ($self,$c) = @_;
    # Map of paths to controller
    my %reqMap = (
        '/articles'                         => [ qw(LIXUZ::Controller::Admin::Articles index) ],
        '/articles/ajax'                    => [ qw(LIXUZ::Controller::Admin::Articles::JSON ajaxHandler) ],
        '/articles/submit'                  => [ qw(LIXUZ::Controller::Admin::Articles::JSON submit) ],
        '/articles/workflow/submit'         => [ qw(LIXUZ::Controller::Admin::Articles::Workflow submit) ],
        '/files'                            => [ qw(LIXUZ::Controller::Admin::Files index) ],
        '/services/templateList'            => [ qw(LIXUZ::Controller::Admin::Services templateList) ],
        '/services/folderList'              => [ qw(LIXUZ::Controller::Admin::Services folderList) ],
        '/services/templateInfo'            => [ qw(LIXUZ::Controller::Admin::Services templateInfo) ],
        '/services/filesInArticle'          => [ qw(LIXUZ::Controller::Admin::Services filesInArticle) ],
        '/services/roleAndUserList'         => [ qw(LIXUZ::Controller::Admin::Services roleAndUserList) ],
        '/services/permList'                => [ qw(LIXUZ::Controller::Admin::Services permList) ],
        '/articles/JSON/getTakenFileSpots'  => [ qw(LIXUZ::Controller::Admin::Articles::JSON getTakenFileSpots) ],
    );
    # Map of paths to ACL paths, entries are only needed here if the ACL path
    # differs from the request path (keep in mind that the /admin prefix is always stripped)
    my %aclMap = (
        '/articles/ajax'    => '/articles/json/ajaxHandler',
    );

    my @requests = $c->req->param('mrSource');
    $c->stash->{multiRequestMode} = 1;
    $c->stash->{multiRequestResponse} = {};

    foreach my $s (@requests)
    {
        $s =~ s{/+$}{};
        $s =~ s{/+}{/};
        (my $rs = $s) =~ s{^/+admin}{}g;
        my $aclS = $rs;
        if ($aclMap{$rs})
        {
            $aclS = $aclMap{$rs};
        }
        if (
            $c->user->can_access($aclS) && defined $reqMap{$rs}
        )
        {
            $c->stash->{multiRequestCurr} = $s;

            eval
            {
                $c->forward(@{$reqMap{$rs}});
                1;
            } or do {
                my $e = $@;
                chomp($e);
                if(not $e eq 'catalyst_detach')
                {
                    if ($c->error)
                    {
                        $c->log->error('When forwarding to action for path '.$rs.': '.$c->error);
                    }
                    else
                    {
                        $c->log->error('When forwarding to action for path '.$rs.': '.$@);
                    }
                    $c->stash->{multiRequestMode} = 0;
                    return json_error($c,'MULTIREQ_CRASH');
                }
            };
            if ($c->stash->{'MULTIREQ_SUBFAILURE'})
            {
                $c->stash->{multiRequestMode} = 0;
                return json_error($c,'MULTIREQ_SUBFAILURE',$c->stash->{'MULTIREQ_SUBFAILURE'}->{error});
            }
            if ($c->stash->{'MULTIREQ_STOP_PROCESSING'})
            {
                last;
            }
        }
        else
        {
            if(not $reqMap{$rs})
            {
                $c->log->warn('Invalid multiRequest path: '.$rs);
                $c->stash->{multiRequestMode} = 0;
                return json_error($c,'INVALID_MULTIREQ_PATH');
            }
            elsif ($c->req->param('multiReqFatal'))
            {
                $c->stash->{multiRequestMode} = 0;
                return json_error($c,'ACCESS_DENIED');
            }
            else
            {
                # Flag it.
                $c->stash->{multiRequestResponse}->{$s} = { 'status' => 'ERR', 'fatal' => 0, 'error' => 'ACCESS_DENIED' };
            }
        }
    }

    $c->stash->{multiRequestMode} = 0;
    return json_response($c,$c->stash->{multiRequestResponse});
}

# Summary: Retusns a JSON-list of all templates
sub templateList : Local
{
    my ($self,$c) = @_;
    my $templates = $c->model('LIXUZDB::LzTemplate')->search();

    if ($c->req->param('template_type'))
    {
        $templates = $templates->search({ type => $c->req->param('template_type') });
    }

    my @list;
    while(my $t = $templates->next)
    {
        push(@list, { template_id => $t->template_id, name => $t->name } );
    }
    return json_response($c,{ list => \@list });
}

# Summary: Returns a JSON-object with information about a specified template
sub templateInfo : Local
{
    my ($self,$c) = @_;
    my $template_id = $c->req->param('template_id');
    my $get = $c->req->param('get');
    my $template;

    if ($template_id eq 'undef')
    {
        $template = $c->model('LIXUZDB::LzTemplate')->find({ type => 'article', is_default => 1});
    }

    if(not $template)
    {
        $template = $c->model('LIXUZDB::LzTemplate')->find({ template_id => $template_id });
    }

    if(not $template)
    {
        return json_error($c,'INVALIDTEMPLATEID');
    }

    if ($get eq 'spotlist')
    {
        my $spots;
        my $spotType = $c->req->param('type');
        if ($spotType)
        {
            my $ckey = get_ckey('template','spotListType'.$spotType,$template->template_id);
            if(not $spots = $c->cache->get($ckey))
            {
                $spots = [];
                my $info = $template->get_info($c);
                foreach my $spot (@{$info->{spots_parsed}})
                {
                    my @accepts;
                    if ($spot->{accepts})
                    {
                        @accepts = split(/\s+/,$spot->{accepts});
                    }

                    if ($spot->{type} eq $c->req->param('type') or
                        grep($c->req->param('type'),@accepts))
                    {
                        push(@{$spots},$spot);
                    }
                }
            }
            $c->cache->set($ckey,$spots,CT_24H);
        }
        else
        {
            $spotType = 'all';
            my $info = $template->get_info($c);
            $spots = $info->{spots_parsed};
        }
        return json_response($c,{ spot_type => $spotType, spots => $spots, for_template => $template->template_id });
    }
    else
    {
        return json_error($c,'UNKNOWNREQUEST');
    }
}

# Summary: Get a list of folders
# Returns a HTML tree, takes zero or more of the following params:
# selected = the ID of the selected folder
# showRoot = true if you want to show the root folder
# includeNoFolder = true if you want to include an "Unsorted" option
sub folderList : Local
{
    my($self,$c) = @_;
    my $selected = defined $c->req->param('selected') ? $c->req->param('selected'): undef;
    my $require = defined $c->req->param('require') ? $c->req->param('require') : 'read';
    if (defined $selected && ($selected eq 'root' || $selected eq 'null'))
    {
        $selected = undef;
    }
    my $tree = $self->buildtree($c,$selected,undef,$require);
    my $includeRoot = (defined $c->req->param('showRoot') && $c->req->param('showRoot') eq 'true') ? 1 : 0;
    my $includeNoFolder = (defined $c->req->param('includeNoFolder') && $c->req->param('includeNoFolder') eq 'true') ? 1 : 0;
    if ($includeRoot)
    {
        $tree = '<option value="root">/</option>'.$tree;
    }
    if ($includeNoFolder)
    {
        $tree = '<option value="null">'.$c->stash->{i18n}->get('Unsorted (files that are not in any folder yet)').'</option>'.$tree;
    }
    return json_response($c,{ tree => $tree });
}

# Summary: Get a list of files in an article
sub filesInArticle : Local
{
    my($self,$c) = @_;
    my $artid = $c->req->param('article_id');
    my $article = $c->model('LIXUZDB::LzArticle')->find({article_id => $artid},{prefetch => 'workflow'});

    # Perform ACL check
    $c->forward('LIXUZ::Controller::Admin::Articles::Workflow','writecheck',[undef, $article]) or $c->detach();

    my $files = $c->model('LIXUZDB::LzArticleFile')->search({article_id => $artid},{prefetch => 'file'});
    return $self->filesInWhatever($c,$files,undef,true,$artid,undef,true);
}

# Summary: Worker function for filesInFolder and filesInArticle, this does all the real work.
sub filesInWhatever : Private
{
    my($self,$c,$files,$perLine,$joiningTable, $myId,$pager,$hasCustomCaption) = @_;
    # The type
    # TYPE_HASH returns an hash with file_id => icon items
    # TYPE_PREFORMATTED returns a preformatted list one can just shove into the HTML
    my $type = $c->req->param('formatType');
    if (defined $type && $type eq 'hash')
    {
        $type = TYPE_HASH;
    }
    elsif(defined $type && $type eq 'extended_hash')
    {
        $type = TYPE_EXTENDED_HASH;
    }
    elsif(defined $type && $type eq 'hashinfo')
    {
        $type = TYPE_HASHINFO;
    }
    else
    {
        $type = TYPE_PREFORMATTED
    }
    # Used in TYPE_PREFORMATTED mode, the action performed when clicking an icon
    my $clickAction;
    # Used in TYPE_PREFORMATTED mode, how many files per line?
    $perLine = $perLine ? $perLine : 3;

    my $foundFiles = 0;
    # Detect the clickAction
    if (($type == TYPE_PREFORMATTED) && ($clickAction = $c->req->param('clickDialogAction')))
    {
        if ($clickAction eq 'delete')
        {
            $clickAction = 'LZ_deleteFileFromArticle';
        }
        elsif($clickAction eq 'add')
        {
            $clickAction = 'LZ_OS_ObjectClicked';
        }
        else
        {
            $clickAction = 0;
        }
    }
    # The HTML returned in TYPE_PREFORMATTED mode
    my $html;
    # The hash returned in TYPE_HASH mode
    my %hashContents;
    # Add initial html for TYPE_PREFORMATTED
    if ($type == TYPE_PREFORMATTED)
    {
        $html = '<table width="100%" cellspacing="0" id="fileGrid"><tr>';
    }
    # Loop counter used in TYPE_PREFORMATTED
    my $n = 0;
    # Process each entry in the resultset
    while(my $file = $files->next)
    {
        $foundFiles = 1;
        my $customCaption;
        # If it is marked as a joining table, fetch the real file
        if ($joiningTable)
        {
            if ($file->caption)
            {
                $customCaption = $file->caption;
            }
            $file = $file->file;
        }
        # Processing for TYPE_PREFORMATTED
        if ($type == TYPE_PREFORMATTED)
        {
            if ($n++ >= $perLine)
            {
                $html .='</tr><tr>';
                $n = 1;
            }
            $html .= '<td><center>';
            if ($clickAction)
            {
                $html .= '<a href="#" style="text-decoration: none;" onclick="'.$clickAction.'('.$file->file_id.'); return false;">';
            }
            $html .= $file->get_iconItem($c);
            if ($clickAction)
            {
                $html .= '</a>';
            }
            $html .= '</center></td>';
        }
        # Processing for TYPE_EXTENDED_HASH
        elsif($type == TYPE_EXTENDED_HASH || $type == TYPE_HASHINFO)
        {
            my $content = {};
            $content->{is_image} = $file->is_image() ? 1 : 0;
            $content->{is_flash} = $file->is_flash() ? 1 : 0;
            $content->{is_video} = $file->is_video() ? 1 : 0;
            if ($file->is_video)
            {
                $content->{has_flv} = $file->has_flv($c) ? 1 : 0;
                $content->{flv_failed} = $file->flv_status($c) eq 'FAILURE' ? 1 : 0;
            }
            if ($type == TYPE_HASHINFO)
            {
                $content->{sizeString} = $file->sizeString($c);
                $content->{icon} = $file->get_icon($c);
                $content->{fileName} = $file->file_name;
                $content->{file_id} = $file->file_id;
                if (defined $customCaption)
                {
                    $content->{caption} = $customCaption;
                }
                else
                {
                    $content->{caption} = $file->caption;
                }
            }
            else
            {
                $content->{iconItem} = $file->get_iconItem($c);
            }
            $hashContents{$file->file_id} = $content;
        }
        # Processing for TYPE_HASH
        else
        {
            $hashContents{$file->file_id} = $file->get_iconItem($c);
        }

    }
    my $pagerInfo = {};
    if ($pager)
    {
        $pagerInfo->{page} = $pager->current_page;
        $pagerInfo->{pageTotal} = $pager->last_page;
        $pagerInfo->{resultTotal} = $pager->total_entries;
    }
    if (not $foundFiles)
    {
        return json_response($c, { files_grid => undef, files => undef, requestForId => $myId, pager => $pagerInfo});
    }
    # Return data for TYPE_PREFORMATTED
    if ($type == TYPE_PREFORMATTED)
    {
        $html .= '</tr></table>';
        return json_response($c, { files_grid => $html, requestForId => $myId, pager => $pagerInfo });
    }
    # Return data for TYPE_HASH
    else
    {
        return json_response($c, { files => \%hashContents, requestForId => $myId, pager => $pagerInfo });
    }
}

# Summary: Retrieves a list of permissions on an object
sub permList : Local
{
    my($self,$c) = @_;
    my $objType = $c->req->param('permObjType');
    my $objId   = $c->req->param('permObjId');
    if(not $objType or not $objId)
    {
        return json_error($c,'MISSINGPARAMS');
    }
    my $perms = $c->model('LIXUZDB::LzPerms')->search({
            object_id => $objId,
            object_type => $objType,
        });

    my $response = {
        users => {},
        roles => {},
    };
    while(my $p = $perms->next)
    {
        if (defined $p->user_id)
        {
            $response->{users}->{$p->user_id} = $p->permission;
        }
        else
        {
            $response->{roles}->{$p->role_id} = $p->permission;
        }
    }
    return json_response($c,$response);
}

# Summary: Handles setting permissions on folders
sub setPerm : Local
{
    my($self,$c) = @_;
    my $perm     = $c->req->param('perm');
    my $type     = $c->req->param('type');
    my $id       = $c->req->param('id');
    my $object   = $c->req->param('object');
    my $objectId = $c->req->param('objectID');
    my $override = $c->req->param('applyRecursive');

    if(not defined $perm or not defined $type or not defined $id or not defined $object or not defined $objectId)
    {
        return json_error($c,'MISSINGPARAMS');
    }
    
    my $findSet = {
        object_type => $object,
        object_id => $objectId,
    };

    if ($type eq 'user')
    {
        $findSet->{user_id} = $id;
    }
    else
    {
        $findSet->{role_id} = $id;
    }

    if ($perm =~ /\D/ || $perm > 6)
    {
        return json_error($c,'INVALIDPERM');
    }

    if ($object eq 'folder')
    {
        my $folder = $c->model('LIXUZDB::LzFolder')->find({
                folder_id => $objectId,
            });
        if(not $folder)
        {
            return json_error($c,'FOLDER_NOT_FOUND');
        }
        if(not $folder->can_write($c))
        {
            return json_error($c,'PERMISSION_DENIED');
        }

        if ($override)
        {
            my $children = $folder->children_recursive;
            if (@{$children})
            {
                my $searchThese = [];
                foreach my $child (@{$children})
                {
                    push(@{$searchThese}, { object_id => $child });
                }
                my $search = {
                    object_type => 'folder',
                    -OR => $searchThese
                };
                if ($type eq 'user')
                {
                    $search->{user_id} = $id;
                }
                else
                {
                    $search->{role_id} = $id;
                }
                my $perms = $c->model('LIXUZDB::LzPerms')->search($search);
                while(my $p = $perms->next)
                {
                    $p->delete();
                }
            }
        }
    }

    my $pobj = $c->model('LIXUZDB::LzPerms')->find_or_create($findSet);
    $pobj->set_column('added_by_user_id',$c->user->user_id);
    $pobj->set_column('permission',$perm);
    $pobj->update();
    # FIXME: Should have some way to only clear the cache that needs clearing
    $c->default_cache_backend->flush_all();
    return json_response($c);
}

# Summary: Retrieves a list of all roles and users
sub roleAndUserList : Local
{
    my($self,$c) = @_;
    my $response = {
        users => {},
        roles => {},
    };

    my $users = $c->model('LIXUZDB::LzUser')->search({user_status => 'Active'});
    my $roles = $c->model('LIXUZDB::LzRole')->search({role_status => 'Active'});

    while(my $u = $users->next)
    {
        $response->{users}->{$u->user_id} = $u->user_name;
    }
    while(my $r = $roles->next)
    {
        $response->{roles}->{$r->role_id} = $r->role_name;
    }

    return json_response($c,$response);
}

# Summary: Handler for server polling
#
# This will hand over control to backup if the poll request contains backup payload
# data.
sub poll : Local
{
    my($self,$c) = @_;
    my $r = {};
    if(defined $c->req->param('article_id') && length $c->req->param('article_id'))
    {
        my $art = get_latest_article($c,$c->req->param('article_id'));
        if(not $art or not $art->lock($c))
        {
            $r->{keepLock} = 'failed';
            if ($art && $art->locked($c) && $art->lockTable->user && $art->lockTable->user->user_id != $c->user->user_id)
            {
                $r->{lockHeldBy} = $art->lockTable->user->name;
            }
        }
        else
        {
            if ($art->lockTimeoutSoon($c))
            {
                $r->{keepLock} = 'successSoonTimeout';
            }
            else
            {
                $r->{keepLock} = 'success';
            }
        }
    }
    if(defined $c->req->param('timetrackerRunning') && $c->req->param('timetrackerRunning') eq 'true')
    {
        if ($c->user->can_access('/timetracker'))
        {
            $c->forward(qw(LIXUZ::Controller::Admin::TimeTracker pollHandler));
        }
    }
    if (defined $c->req->param('backupData'))
    {
        if ($c->user->can_access('/services/backup'))
        {
            my $b = $self->writeBackup($c);
            if ($b == true)
            {
                $r->{'recievedPayload'} = 'ok';
            }
            else
            {
                return json_error($c,$b);
            }
        }
        else
        {
            return json_error($c,'BACKUP_PERMISSION_DENIED');
        }
    }
    return json_response($c,$r);
}

# Summary: Backup worker function
sub writeBackup : Private
{
    my($self,$c) = @_;
    my $data = $c->req->param('backupData');
    my $source = $c->req->param('backupSource');
    my $uid  = $c->req->param('backupMainUID');
    if(not defined $data or not defined $source)
    {
        return 'MISSING_PARAMS';
    }
    elsif (defined $uid and $uid =~ /\D/ and not $uid eq 'null')
    {
        return 'INVALID_UID';
    }
    elsif (not $source eq 'article')
    {
        return 'UNSUPPORTED_BACKUP_SOURCE';
    }
    my $search_uid;
    if(not defined $uid or $uid eq 'null' or not length $uid)
    {
        $search_uid = \'IS NULL';
    }
    else
    {
        $search_uid = $uid;
    }

    my $object = $c->model('LIXUZDB::LzBackup')->find({
            user_id => $c->user->user_id,
            backup_source => $source,
            backup_source_id => $search_uid,
        });
    if ($object)
    {
        $object->update({
                saved_date => \'NOW()',
                backup_string => $data,
            });
    }
    else
    {
        $object = $c->model('LIXUZDB::LzBackup')->create({
            user_id => $c->user->user_id,
            backup_source => $source,
            backup_string => $data,
            });
        if (defined $uid and not $uid =~ /\D/ and length $uid)
        {
            $object->set_column('backup_source_id',$uid);
            $object->update();
        }
    }
    return true;
}

# Summary: Handler for backup data and information requests
sub backup : Local
{
    my($self,$c) = @_;
    if(defined $c->req->param('wants') && $c->req->param('wants') eq 'list')
    {
        return $self->getBackupList($c);
    }
    elsif (defined $c->req->param('delete'))
    {
        my $backup = $c->model('LIXUZDB::LzBackup')->find({backup_id => $c->req->param('delete'), user_id => $c->user->user_id});
        if (not $backup)
        {
            return json_error($c,'INVALID_BACKUP_ID');
        }
        $backup->delete();
        return json_response($c, {deleted => 1});
    }
    else
    {
        return $self->getBackupData($c)
    }
}

# Summary: Retriever of backup data
sub getBackupData : Private
{
    my($self,$c) = @_;
    my $source = $c->req->param('type');
    my $uid  = $c->req->param('uid');
    if(not defined $source)
    {
        return json_error($c,'MISSING_PARAMS');
    }
    elsif (defined $uid and $uid =~ /\D/ and not $uid eq 'null')
    {
        return json_error($c,'INVALID_UID');
    }
    elsif (not $source eq 'article')
    {
        return json_error($c,'UNSUPPORTED_BACKUP_SOURCE');
    }
    my $search_uid;
    if((not defined $uid) or ($uid =~ /\D/) or (not length $uid))
    {
        $search_uid = \'IS NULL';
    }
    else
    {
        $search_uid = $uid;
    }

    my $object = $c->model('LIXUZDB::LzBackup')->find({
            user_id => $c->user->user_id,
            backup_source => $source,
            backup_source_id => $search_uid,
        });
    if ($object)
    {
        my $jany = JSON::XS->new();
        my $string = $object->backup_string;
        my $json = $jany->decode($string);
        return json_response($c,$json);
    }
    else
    {
        return json_error($c,'NODATA');
    }
}

# Summary: Retriever of backup lists
sub getBackupList : Private
{
    my($self,$c) = @_;
    my $i18n = $c->stash->{i18n};

    my @backupList;

    my $backups = $c->model('LIXUZDB::LzBackup')->search({ user_id => $c->user->user_id });
    while((defined $backups) and (my $backup = $backups->next))
    {
        my $title = $i18n->get('(unnamed)');
        my $folder;
        my $jany = JSON::XS->new();
        my $json;
        try
        {
            $json = $jany->decode($backup->backup_string);
        }
        catch
        {
            my $error = $_;
            if (/undefined/)
            {
                my $string = $backup->backup_string;
                $string =~ s/":undefined/":null/g;
                try
                {
                    $json = $jany->decode($string);
                };
            }
            if (not defined $json)
            {
                $c->log->error('Failed to decode backup string for backup id '.$backup->backup_id.': '.$_);
            }
        };
        next if not defined $json;
        if ($json->{article} && defined $json->{article}->{title})
        {
            $title = $json->{article}->{title};
        }
        if ($json->{article} && defined $json->{article}->{folder})
        {
            $folder = $json->{article}->{folder};
        }
        push(@backupList,{ source => $backup->backup_source, source_id => $backup->backup_source_id, title => $title, backup_id => $backup->backup_id, folder_id => $folder });
    }
    if (@backupList)
    {
        return json_response($c,{ list => \@backupList, hasBackups => 1});
    }
    else
    {
        return json_response($c,{ list => [], hasBackups => 0});
    }
}

# Summary: Handler for elements related code, lists or saves elements
sub elements : Local
{
    my($self,$c) = @_;
    my $action = $c->req->param('action');
    if ($action eq 'htmllist')
    {
        my $elements = $c->model('LIXUZDB::LzKeyValue');
        if ($c->req->param('_submitted_list_search') and $c->req->param('query'))
        {
            $elements = LIXUZ::HelperModules::Search::perform_search($elements,$c->req->param('query'), [ 'thekey','value'],undef,$c);
        }
        my $i18n = $c->stash->{i18n};
        if (not $elements)
        {
            return json_response($c);
        }
        my $result = '<form id="additionalElementsListForm"><table border="0" id="listView" class="listView"><tr><td class="rowHead">&nbsp;</td><td class="rowHead">'.$i18n->get('ID').'</td><td class="rowHead">'.$i18n->get('Element').'</td><td class="rowHead">'.$i18n->get('Value').'</td></tr>';
        my $i = 0;
        while(my $e = $elements->next)
        {
            $i++;
            my $class = ($i % 2 == 0) ? 'even' : 'odd';
            $result .= '<tr class="'.$class.'"><td><input type="checkbox" id="AELF_checkbox_'.$i.'" value="'.$e->keyvalue_id.'" /></td><td><a href="#" onclick="LZ_OS_ObjectClicked('.$e->keyvalue_id.'); return false;">'.$e->keyvalue_id.'</a></td><td><a href="#" onclick="LZ_OS_ObjectClicked('.$e->keyvalue_id.'); return false;">'.$e->thekey.'</a></td><td>'.$e->value.'</td></tr>';
        }
        $result .= '</table></form>';
        return json_response($c, {files_grid => $result});
    }
    elsif($action eq 'info')
    {
        my $element_id = $c->req->param('elementId');
        my $element = $c->model('LIXUZDB::LzKeyValue')->find({ keyvalue_id => $element_id });
        if(not $element_id or not $element)
        {
            return json_error($c,'ELEMENTNOTFOUND');
        }
        return json_response($c, {id => $element->keyvalue_id, key => $element->thekey, value => $element->value, type => $element->type});
    }
    elsif($action eq 'save')
    {
        foreach my $v (qw(key value type))
        {
            if(not defined $c->req->param($v) or not length $c->req->param($v))
            {
                return json_error($c,'INVALIDPARAMS',"$v is missing");
            }
        }
        my $element_id = $c->req->param('elementId');
        my $key = $c->req->param('key');
        my $value = $c->req->param('value');
        my $type = $c->req->param('type');
        if(not $type =~ /^(dictionary)$/)
        {
            return json_error('INVALIDTYPE');
        }
        my $element;
        if(defined $element_id && length $element_id)
        {
            $element = $c->model('LIXUZDB::LzKeyValue')->find({ keyvalue_id => $element_id });
            if(not $element)
            {
                return json_error($c,'ELEMENTNOTFOUND');
            }
        }
        else
        {
            $element = $c->model('LIXUZDB::LzKeyValue')->create({});
        }
        $element->set_column('thekey',$key);
        $element->set_column('value',$value);
        $element->set_column('type',$type);
        $element->update();
        return json_response($c, {elementId => $element->keyvalue_id, key => $key, value => $value, 'type' => $type});
    }
    else
    {
        return json_error($c,'INVALIDACTION');
    }
}

# Summary: Builds a tree of folders into a string of <option></option> pairs
# Usage: $tree = $self->buildtree($c, ($obj), ($currParent));
#
# $folderId is teh folder id to be selected, or undef
#
# $type is the type you want returned, html or array.
#
# $obj is only used internally for recursively calling itself
# $currParent is only used internally for tracking parents
sub buildtree : Private
{
    my ($self, $c, $folderId, $type, $require, $obj, $currParent) = @_;

    $type = defined $type ? $type : 'html';
    $require = defined $require ? $require : 'read';

    if(not $obj)
    {
        return '' if $currParent;
        $obj = $c->model('LIXUZDB::LzFolder')->search({ parent => \'IS NULL' });
    }

    $currParent = defined $currParent ? $currParent.'/' : '/';

    my $str = '';
    my @array;

    while(my $s = $obj->next)
    {
        if ($require eq 'write')
        {
            next if not $s->can_write($c);
        }
        else
        {
            next if not $s->can_read($c);
        }
        my $children = $s->children;
        if ($type eq 'html')
        {
            $str .= '<option value="'.$s->folder_id.'"';
            if (defined $folderId and $s->folder_id == $folderId)
            {
                $str .= ' selected="selected"';
            }
            $str .= '>'.$currParent.$s->folder_name.'</option>';
            $str .= $self->buildtree($c,$folderId,$type,$require,$children,$currParent.$s->folder_name);
        }
        else
        {
            push(@array,{
                value => $s->folder_id,
                label => $currParent.$s->folder_name,
                });
            push(@array, @{$self->buildtree($c,$folderId,$type,$require,$children,$currParent.$s->folder_name)});
        }
    }
    if ($type eq 'html')
    {
        return $str;
    }
    else
    {
        return \@array;
    }
}

# Summary: Returns a JSON object with settings that define how to display
#   filtering options to the user
sub jsFilter: Local
{
    my($self,$c) = @_;
    my $i18n = $c->stash->{i18n};
    my $source = $c->req->param('source');
    my $defaultFolder = $c->req->param('defaultFolder');
    my $folders = $c->forward(qw(LIXUZ::Controller::Admin::Services buildtree),[undef,'array','read']);
    my $includeSearch = 0;
    my @filter;
    push(@filter,{
            name => $i18n->get('In folder'),
            realname => 'folder',
            options => $folders,
            selected => $defaultFolder,
            exclusiveLine => 1,
        });
    my %SourceMap = (
        articles => 'LIXUZ::Controller::Admin::Articles',
        files => 'LIXUZ::Controller::Admin::Files',
        newsletter => 'LIXUZ::Controller::Admin::Newsletter',
    );
    if (not defined $SourceMap{$source})
    {
        if ($source eq 'onlySearch')
        {
            shift(@filter);
            $includeSearch = 1;
        }
        else
        {
            $source = 'onlyFiles';
        }
    }
    else
    {
        if ($source eq 'newsletter')
        {
            shift(@filter);
        }
        $source = $SourceMap{$source};
        $c->forward($source,'init_searchFilters');
        push(@filter, @{$c->stash->{searchFilters}});
        $includeSearch = 1;
    }

    return json_response($c, {
            filterData => \@filter,
            includeSearchBox => $includeSearch,
        });
}

# Summary: Deletes a folder
sub deleteFolder: Local
{
    my ($self,$c) = @_;
    my $folder_id = $c->req->param('folder_id');
    my $folder = $c->model('LIXUZDB::LzFolder')->find({ folder_id => $folder_id });
    if(not defined $folder_id or $folder_id =~ /\D/ or not length $folder_id or not $folder)
    {
        return json_error($c,'INVALID_FOLDER_ID');
    }
    $folder->recursive_delete($c);
    return json_response($c, {} );
}

# Summary: Renames a folder
sub renameFolder: Local
{
    my ($self,$c) = @_;
    my $folder_id = $c->req->param('folder_id');
    my $newName = $c->req->param('folder_name');
    my $folder = $c->model('LIXUZDB::LzFolder')->find({ folder_id => $folder_id });
    if(not defined $folder_id or $folder_id =~ /\D/ or not length $folder_id or not $folder)
    {
        return json_error($c,'INVALID_FOLDER_ID');
    }
    if(not defined($newName) or not length($newName))
    {
        return json_error($c,'INVALID_FOLDER_NAME');
    }
    $folder->set_column('folder_name',$newName);
    $folder->update();
    return json_response($c, {} );
}

__PACKAGE__->meta->make_immutable;
1;
