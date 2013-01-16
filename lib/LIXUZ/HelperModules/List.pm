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

# This role can be applied to controllers that need to return lists to users.
# It can generate the lists in DBIC, Indexer result, JSON or basic HTML, and
# even handle the request completely by returning the data itself.
#
# In practically all cases you will want to apply one of the two submodules
# to your controller, rather than applying this list. ::Database and ::Indexer
package LIXUZ::HelperModules::List;

use Moose;
use List::MoreUtils qw(any);
use LIXUZ::HelperModules::JSON qw(json_response);
use LIXUZ::HelperModules::Forms qw(finalize_form);
use LIXUZ::HelperModules::Search qw(cross parse_search_string);
use Try::Tiny;
use Hash::Merge qw(merge);
use Carp;

has 'c' => (
    is => 'rw',
    weak_ref => 1,
    isa => 'Ref',
    required => 1,
);

has 'searchColumns' => (
    is => 'ro',
);
has 'advancedSearch' => (
    is => 'ro',
);
has 'template' => (
    is => 'ro',
);
has 'autoSearch' => (
    is => 'ro',
    default => 1,
);
has 'orderParams' => (
    is => 'ro',
);
has 'paginate' => (
    is => 'ro',
);
has 'formbuilder' => (
    is => 'ro',
);
has 'object' => (
    is => 'ro',
);
has 'objectName' => (
    is => 'ro'
);
has 'query' => (
    is => 'ro',
);
has 'folderType' => (
    is => 'ro',
    default => 'external'
);

has '_lSearchData' => (
    is => 'rw',
    isa => 'HashRef',
    builder => '_buildSearchData',
);

has '_lDataChanged' => (
    is => 'rw',
    isa => 'Bool',
    default => 0,
    );
has '_handled' => (
    is => 'rw',
    isa => 'Bool',
    default => 0,
    );

sub handleListRequestJSON
{
    my $self = shift;
    my $options = shift;
    my $type = shift;
    my $reply = { URL => $self->c->req->uri->as_string};

    my $object = $self->handleListRequest($options);

    if ($type eq 'list')
    {
        my $contents = [];
        while((defined $object) and (my $oe = $object->next))
        {
            my $instance = {};
            foreach my $ent (@{$options->{actions}})
            {
                $instance->{$ent} = $oe->get_column($ent);
            }
            push(@{$contents},$instance);
        }
        $reply->{contents} = $contents;
    }
    elsif($type eq 'array_grid')
    {
        die('List role: Consumer missing listArrayGridEntry method') if not $self->can('listArrayGridEntry');
        my @data;
        while((defined $object) and (my $gridentry = $object->next))
        {
            my $entry = $self->listArrayGridEntry($gridentry);
            next if not defined $entry;
            push(@data,$entry);
        }
        $reply->{contents} = \@data;
    }
    elsif($type eq 'string_grid')
    {
        die('List role: Consumer missing listStringGridEntry method') if not $self->can('listStringGridEntry');
        my $files_grid;
        while((defined $object) and (my $gridentry = $object->next))
        {
            my $addContent = $self->listStringGridEntry($gridentry);
            next if not defined $addContent;
            $files_grid .= $addContent;
        }
        $reply->{files_grid} = $files_grid;
    }
    else
    {
        croak('Unknown type: '.$type);
    }
    my $pager = $self->c->stash->{pager};
    $pager //= $object->pager;
    if(not $pager)
    {
        $self->c->log->error('Lists role handleListRequestJSON(): pager missing!');
        return json_error($self->c,'INTERNALPAGERMISSING');
    }
    $reply->{pager} = {};
    $reply->{pager}->{page} = $pager->current_page;
    $reply->{pager}->{pageTotal} = $pager->last_page;
    $reply->{pager}->{resultTotal} = $pager->total_entries;
    return json_response($self->c,$reply);
}

sub handleListRequest
{
    my $self = shift;

    if(not $self->object)
    {
        croak("Fatal: Object is missing");
    }

    $self->_handled(1);

    # Get the form
    my $form;
    my $query = $self->query;
    if ($self->formbuilder)
    {
        $form = $self->formbuilder;
    }
    else
    {
        $self->c->log->warn('no formbuilder');
    }
    # I18n object
    my $i18n = $self->c->stash->{i18n};
    # Get query from the URL (or the form if there's nothing there)
    if ($form && $form->submitted)
    {
        $query ||= $form->field('query');
        $self->c->stash->{query} = $query;

        if ($self->searchColumns)
        {
            if ($self->advancedSearch)
            {
                $self->list_advanced_search({
                        string => $query,
                        columns => $self->searchColumns,
                    }, $self->advancedSearch);
            }
            else
            {
                $self->list_search($query, $self->searchColumns);
            }
        }
        elsif($self->can('listSearcher'))
        {
            $self->listSearcher({ query => $query });
        }
        else
        {
            # FIXME
                $self->c->log->warn('List role: wanted to search but couldn\'t, object has no listSearcher method and no searchColumns (and advancedSearch) supplied through the options hash');
        }

        if ($self->c->req->param('_JSON_Submit'))
        {
            $self->listFolderFilter();
        }
    }
    else
    {
        # If we have a folder parameter, attempt to handle it
        $self->listFolderFilter();

        # Prepare pagination

        # If there's a ListMessage in the flash, fetch it and stash it
        if ($self->c->flash->{'ListMessage'})
        {
            $self->c->stash->{message} = $self->c->flash->{'ListMessage'};
        }
    }

    $self->listPrepSearchForm($form,$query);

    if ($self->template)
    {
        $self->c->stash->{template} = $self->template;
    }

    if ($self->autoSearch)
    {
        return $self->listGetResultObject({ paginate => $self->paginate });
    }
}

sub listGetOrderFromParam
{
    my $self = shift;
    my @allowed = @{$self->orderParams};
    my $orderby = $self->c->req->param('orderby');
    my $ordertype = $self->c->req->param('ordertype');
    my %OrderRemap = (
        DESC => 'ASC',
        ASC => 'DESC',
    );
    if(not defined $ordertype)
    {
        $ordertype = 'ASC';
    }
    elsif(not ($ordertype eq 'DESC' or $ordertype eq 'ASC'))
    {
        $self->c->log->warn('Attempted use of illegal ordertype='.$ordertype.' - resetting to ASC');
        $ordertype = 'ASC';
    }
    # Stash a reversed version of ordertype
    $self->c->stash->{ordertype} = $OrderRemap{$ordertype};
    if(not defined $orderby)
    {
        return;
    }
    if(not any {$_ eq $orderby} @allowed)
    {
        $self->c->log->warn('Attempted use of illegal orderby='.$orderby.' ignoring ordering');
        return;
    }
    return { 
        '-'.lc($ordertype) => $orderby 
    };
}

sub listFolderFilter
{
    my($self) = @_;
    my $folder = $self->c->req->param('folder') || $self->c->req->param('filter_folder');
    my $fobj = $self->c->model('LIXUZDB::LzFolder')->find({folder_id => $folder });
    my $type =  $self->folderType;
    if(defined $folder and $fobj)
    {
        $fobj->check_read($self->c);

        my $folders = [];
        if ($self->c->req->param('folder_recursive') or $self->c->stash->{folder_recursive})
        {
            $folders = $fobj->children_recursive(1);
        }
        push(@{$folders},$fobj->folder_id);
        for(0..@{$folders})
        {
            if(defined $folders->[$_])
            {
                if ($type eq 'builtin')
                {
                    $folders->[$_] = { 'folder_id' => $folders->[$_] };
                }
                else
                {
                    $folders->[$_] = { 'folders.folder_id' => $folders->[$_] };
                }
            }
        }
        if ($type ne 'builtin')
        {
            $self->listAddJoin('folders');
        }
        $self->listAddExpr({ -or => $folders });
    }
}

sub listPrepSearchForm
{
    my($self,$form,$query) = @_;
    # There is no reason for this to get executed in json requests
    if ($self->c->req->param('_JSON_Submit'))
    {
        return;
    }
    my $i18n = $self->c->stash->{i18n};
    my $value = '';
    if(defined $query)
    {
        $value = $query;
    }
    # Finalize the search form
    finalize_form($form,undef,
        {
            submit => $i18n->get('Search'),
            fields =>
            {
                query => $i18n->get('Filter'),
            },
            fieldvalues =>
            {
                query => $value,
            },
        }
    );
}

sub listSetParam
{
    my $self = shift;
    my $param = shift;
    my $setting = shift;
    my $ignoreIfExists = shift;

    if ($ignoreIfExists && exists($self->_lSearchData->{settings}->{$param}))
    {
        return;
    }

    if (
        !(defined($setting)) ||
        !(defined($self->_lSearchData->{settings}->{$param})) ||
        $self->_lSearchData->{settings}->{$param} ne $setting
    )
    {
        $self->_lSearchData->{settings}->{$param} = $setting;
        $self->_lDataChanged(1);
    }
}

sub _buildSearchData
{
    return { join => [], expression => {}, settings => {} };
}

1;
