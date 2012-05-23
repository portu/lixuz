package LIXUZ::Schema::LzArticle;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';


=head1 NAME

LIXUZ::Schema::LzArticle

=cut

__PACKAGE__->table("lz_article");

=head1 ACCESSORS

=head2 article_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 status_id

  data_type: 'integer'
  is_nullable: 1

=head2 title

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 lead

  data_type: 'text'
  is_nullable: 1

=head2 body

  data_type: 'text'
  is_nullable: 1

=head2 author

  data_type: 'varchar'
  is_nullable: 1
  size: 100

=head2 creator

  data_type: 'integer'
  is_nullable: 1

=head2 assignee

  data_type: 'integer'
  is_nullable: 1

=head2 template_id

  data_type: 'integer'
  is_nullable: 1

=head2 modified_time

  data_type: 'timestamp'
  default_value: current_timestamp
  is_nullable: 0

=head2 created_time

  data_type: 'timestamp'
  default_value: '0000-00-00 00:00:00'
  is_nullable: 0

=head2 publish_time

  data_type: 'timestamp'
  is_nullable: 1

=head2 expiry_time

  data_type: 'timestamp'
  is_nullable: 1

=head2 trashed

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 1

=head2 live_comments

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 1

=head2 revision

  data_type: 'integer'
  default_value: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "article_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "status_id",
  { data_type => "integer", is_nullable => 1 },
  "title",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "lead",
  { data_type => "text", is_nullable => 1 },
  "body",
  { data_type => "text", is_nullable => 1 },
  "author",
  { data_type => "varchar", is_nullable => 1, size => 100 },
  "creator",
  { data_type => "integer", is_nullable => 1 },
  "assignee",
  { data_type => "integer", is_nullable => 1 },
  "template_id",
  { data_type => "integer", is_nullable => 1 },
  "modified_time",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 0,
  },
  "created_time",
  {
    data_type     => "timestamp",
    default_value => "0000-00-00 00:00:00",
    is_nullable   => 0,
  },
  "publish_time",
  { data_type => "timestamp", is_nullable => 1 },
  "expiry_time",
  { data_type => "timestamp", is_nullable => 1 },
  "trashed",
  { data_type => "tinyint", default_value => 0, is_nullable => 1 },
  "live_comments",
  { data_type => "tinyint", default_value => 0, is_nullable => 1 },
  "revision",
  { data_type => "integer", default_value => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("article_id", "revision");


# Created by DBIx::Class::Schema::Loader v0.07002 @ 2012-03-12 12:51:38
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ynrNGV2QwGeUqJzDOYeiQA

# LIXUZ content management system
# Copyright (C) Utrop A/S Portu media & Communications 2008-2012
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

use LIXUZ::HelperModules::HTMLRenderer;
use LIXUZ::HelperModules::Calendar qw(datetime_from_SQL datetime_from_SQL_to_unix);
use LIXUZ::HelperModules::Cache qw(get_ckey CT_DEFAULT CT_24H CT_1H);
use LIXUZ::HelperModules::StringInsertFilter;
use constant { true => 1, false => 0 };
use 5.010;
use Carp;
use Try::Tiny;
use LIXUZ::HelperModules::HTMLFilter qw(filter_string);
use HTML::Entities qw(decode_entities);

__PACKAGE__->belongs_to('status' => 'LIXUZ::Schema::LzStatus', 'status_id');
__PACKAGE__->belongs_to('lockTable' => 'LIXUZ::Schema::LzArticleLock', 'article_id');
__PACKAGE__->belongs_to('template','LIXUZ::Schema::LzTemplate', 'template_id');
__PACKAGE__->belongs_to('workflow' => 'LIXUZ::Schema::LzWorkflow',{
    'foreign.article_id' => 'self.article_id',
    'foreign.revision' => 'self.revision'
    });
__PACKAGE__->has_many(relationships => 'LIXUZ::Schema::LzArticleRelations', {
    'foreign.article_id' => 'self.article_id',
    'foreign.revision' => 'self.revision'
    });
__PACKAGE__->has_many(comments => 'LIXUZ::Schema::LzLiveComment',{
    'foreign.article_id' => 'self.article_id',
    });
__PACKAGE__->has_many(files => 'LIXUZ::Schema::LzArticleFile',{
    'foreign.article_id' => 'self.article_id',
    'foreign.revision' => 'self.revision'
    });
__PACKAGE__->has_many(folders => 'LIXUZ::Schema::LzArticleFolder',{
    'foreign.article_id' => 'self.article_id',
    'foreign.revision' => 'self.revision'
    });
__PACKAGE__->has_many(additionalElements => 'LIXUZ::Schema::LzArticleElements',{
    'foreign.article_id' => 'self.article_id',
    'foreign.revision' => 'self.revision'
    });
__PACKAGE__->has_many(tags => 'LIXUZ::Schema::LzArticleTag',{
    'foreign.article_id' => 'self.article_id',
    'foreign.revision' => 'self.revision'
    });
__PACKAGE__->belongs_to('revisionMeta' => 'LIXUZ::Schema::LzRevision', {
    'foreign.type_id' => 'self.article_id',
    # As all revision entries currently are articles, it is safe not to use this. However
    # it needs to be used in the future. A new version of DBIx::Class will be released soon (as of 2010-10-01)
    # that supports defining enum entries in relationships.
#    'foreign.type' => 'article',
    'foreign.type_revision' => 'self.revision',
    });

use Moose;
with 'LIXUZ::Role::Serializable';
with 'LIXUZ::Role::URLGenerator';
with 'LIXUZ::Role::IndexTriggers';

# This is an alias for ->primary_folder
sub folder
{
    my($self) = @_;
    return $self->primary_folder;
}

# This is in place of
# __PACKAGE__->belongs_to('folder' => 'LIXUZ::Schema::LzArticleFolder','article_id');
#
# As that can't have additional conditionals in a belongs_to
sub primary_folder
{
    my($self) = @_;
    if(not defined $self->{lz_primary_folder})
    {
        $self->{lz_primary_folder} = $self->folders->find({primary_folder => 1});
    }
    return $self->{lz_primary_folder};
}

# This is in place of
# __PACKAGE__->has_many('secondary_folders' => 'LIXUZ::Schema::LzArticleFolder','article_id');
#
# As that can't have additional conditionals in a has_many
sub secondary_folders
{
    my($self) = @_;
    if(not defined $self->{lz_secondary_folders})
    {
        $self->{lz_secondary_folders} = $self->folders->search({primary_folder => 0});
    }
    return $self->{lz_secondary_folders};
}

# Summary: Get all fields from this user in a hash
# Usage: object->get_everything();
# Returns: Hash with field => value pairs.
sub get_everything
{
    my $self = shift;
    my %Return;
    foreach my $col( qw(article_id status_id title lead body author creator assignee hits template_id article_order modified_time created_time publish_time expiry_time) )
    {
        $Return{$col} = $self->get_column($col);
    }
    return(\%Return);
}

# Summary: Retrieve category names in an array, highest level first. 
# Primarily used by the URLGenerator role.
sub get_category_tree
{
    my $self  = shift;
    my $c     = shift;
    my $notIn = shift;
    my @tree;

    if(my $cat = $self->_get_best_category($c,$notIn))
    {
        push(@tree,$cat->category_name);
        while($cat = $cat->parent)
        {
            push(@tree,$cat->category_name);
        }
    }
    return @tree;
}

# Summary: Get the absolute URL for this article (with hostname)
# Usage: absolute_url = article->get_absoluteURL($c);
sub get_absoluteURL
{
    my $self = shift;
    my $c = shift or die('get_absoluteURL: needs $c');
    my $url = $self->get_url($c,@_);
    return $c->uri_for($url);
}

# Summary: Get a shortened title for this article
# Usage: title = article->shorttitle(length = 30);
sub shorttitle
{
    my $self = shift;
    return $self->shortText('title',@_);
}

# Summary: Get a shortened text entry for this article
# Usage: string = article->shortText('COLUMN',length = 30);
sub shortText
{
    my $self = shift;
    my $column = shift;
    my $length = shift;
    $length = $length ? $length : 30;

    my $str = $self->get_column($column);

    if(not defined $str or not length($str) > $length)
    {
        return $str;
    }

    $str = substr($str, 0, $length - 3);
    $str .='...';
    return $str;
}

# Summary: Get a title for this article with XHTML <br />'s separating words that are too long so that
#   the browser can properly wrap the words
# Usage: title = article->wrappedtitle(LENGTH = 12);
# 
# What this does is add <br />'s to split up words that are longer than LENGTH characters
# so that the browser does not let the text overflow.
sub wrappedtitle
{
    my $self = shift;
    my $length = shift;
    $length = $length ? $length : 12;

    my $title = $self->title;
    if(not defined $title or not length($title) > $length)
    {
        return $title;
    }

    $title =~ s/(\w{$length})(\w{2})/$1-<br \/>$2/g;
    return $title;
}

# Summary: Get the publish time in a human format
# Usage: string = article->human_publish_time();
sub human_publish_time
{
    my $self = shift;
    return datetime_from_SQL($self->publish_time);
}

# Summary: Get the publish *date* in a human format
# Usage: string = article->human_publish_date();
sub human_publishdate
{
    my $self = shift;
    my $val = $self->human_publish_time();
    $val =~ s/\s+.*//;
    return $val;
}

# Summary: Get the file for the spot supplied
# Usage: lzArticleFile object = article->get_fileSpot(SPOT_NO);
# Returns undef if no file exists at that spot.
sub get_fileSpot
{
    my($self,$spotId) = @_;

    my $spot = $self->files->search({spot_no => $spotId});
    if ($spot && $spot->count)
    {
        return $spot->next;
    }
    return;
}

# Summary: Get the body as plaintext (HTML stripped)
# Usage: body = article->text_body();
sub text_body
{
    my $self = shift;
    return $self->_text_field($self->body);
}

# Summary: Get the lead as plaintext (HTML stripped)
# Usage: lead = article->text_lead();
sub text_lead
{
    my $self = shift;
    return $self->_text_field($self->lead);
}

# Summary: Convert a HTML string to plaintext
# Usage: plaintext = article->_text_field( html );
sub _text_field
{
    my($self,$string) = @_;
    $string = filter_string($string);
    $string =~ s{<br\s*/?>}{\n}gi;
    $string =~ s/<[^>]+>//g;
    $string = decode_entities($string);
    return $string;
}

# Summary: Get the body with dynamically placed content
# Usage: body = article->filteredBody($c,IMGOPTS,RENDEROPTS)
#
# IMGOPTS is the same hash as you would supply to get_imghtmlWithCaption in LzFile.
# RENDEROPTS is the same hash as you would supply to renderedBody.
sub filteredBody
{
    my $self = shift;
    my $c = shift;
    my $imgOpts = shift;
    $imgOpts //= {};
    my $renderOpts = shift;

    my $ckey = get_ckey('article','filteredBody',$self->article_id);

    my $result;

    if ($result = $c->cache->get($ckey))
    {
        return $result;
    }

	# TODO: Once strings are properly cleaned on save, and older strings are cleaned
	#       cleaned on upgrade, remove the call to filter_string()
	my $body = filter_string($self->renderBody($c,$renderOpts));

    my $infolist = $c->stash->{infolist};
    if(not $infolist->{spots_parsed})
    {
        $c->cache->set($ckey,$body,CT_DEFAULT);
        return $body;
    }
    my @spots;
    foreach my $spot (@{$infolist->{spots_parsed}})
    {
        if (defined $spot->{dynamicContent})
        {
            $spots[$spot->{dynamicContent}] = $spot;
        }
    }
    if(not @spots)
    {
        $c->cache->set($ckey,$body,CT_DEFAULT);
        return $body;
    }

    my @content;
    $imgOpts->{artid} //= $self->article_id;
    $imgOpts->{revision} //= $self->revision;

    foreach my $spot (@spots)
    {
        next if not defined $spot;
        my $file = $c->stash->{$spot->{as}};
        if(not $file)
        {
            next;
        }
        # $file is a LzArticleFile object, get the LzFile
        $file = $file->file;
        if(not $file->status eq 'Active') 
        {
            $c->log->warn('LzArticle: A file (id '.$file->file_id.') was selected for inclusion in article id '.$self->article_id.', but was marked as inactive. Refusing to include.');
            next;
        }
        my $cont = $file->get_imghtmlWithCaption($c,$imgOpts);
        push(@content,$cont);
    }
    if(not @content)
    {
        $c->cache->set($ckey,$body,CT_DEFAULT);
        return $body;
    }

    my $filter = LIXUZ::HelperModules::StringInsertFilter->new( string => $body, insertStr => \@content, c => $c );

    my $filtered = $filter->get_filtered;
    $c->cache->set($ckey,$filtered,CT_DEFAULT);

    return $filtered;
}

# Summary: Retrieve the body of an article, rendered with Lixuz image
#       components via a template
# Usage: body = article->renderedBody($c, OPTIONS);
#
# OPTIONS is a hashref with the following settings:
#
# - template -
# A string, the template to use to render the images. this can be omitted in
# which case Lixuz will do a best case guess from the data defined in the
# current article template, or, if there is none, pick the default image
# renderer from the database.
#
# - height - || - width -
# An int, force the size of the image. Optional, if omitted the size already
# defined will be used.
#
# - maxHeight - || - maxWidth -
# An int, the maximum width/height an image can have. If omitted, the max is
# the size of the original image.
sub renderBody
{
    my ($self,$c,$options) = @_;
    my $ckey = get_ckey('article','renderedBody',$self->id.'_'.$self->revision);
    if ($options->{template})
    {
        $ckey .= '-'.$options->{template};
    }

    if (my $cached = $c->cache->get($ckey))
    {
        return $cached;
    }

    my $HTMLR = LIXUZ::HelperModules::HTMLRenderer->new(
        processString => $self->body,
        c => $c,
        article_id => $self->article_id,
        article_rev => $self->revision
    );
    my $rendered = $HTMLR->render;

	$c->cache->set($ckey,$rendered);
	return $rendered;
}

# Summary: Check if the current user can edit this article
# Usage: article->can_edit($c);
sub can_write
{
    my($self,$c) = @_;
    # A super user can do anything she likes
    if ($c->user->can_access('SUPER_USER'))
    {   
        return 1;
    }
    if (!$self->workflow)
    {
        $c->log->error('Article '.$self->article_id.' has no workflow object!');
        return 0;
    }

    return $self->workflow->can_write($c);
}

# Alias for can_write
sub can_edit
{
    my $self = shift;
    return $self->can_write(@_);
}

# Summary: Check if the current user can read this article
# Usage: article->can_read($c);
sub can_read
{
    my($self,$c) = @_;

    return 1 if ($c->user->super_user);

    if (!$self->folder)
    {
        return 1;
    }

    # Allow access if this article is assigned to the current user
    if (
         (
             defined $self->workflow->assigned_to_user &&
             $self->workflow->assigned_to_user == $c->user->user_id
         )
                    or
         (
             defined $self->workflow->assigned_to_role &&
             $self->workflow->assigned_to_role == $c->user->role_id
         )
     )
     {
         return 1;
     }

    return $self->folder->can_read($c);
}

# Summary: Clear all cached data for this article
# Usage: article->clearCache();
#
# Note: This attempts to clear everything, but in certain cases, in particular
# if several different combinations of "NOT_IN_CATEGORY" is used, it is
# likely to miss something.
sub clearCache
{
    my($self,$c) = @_;
    my @keys = (
        get_ckey('article','filteredBody',$self->article_id),
        get_ckey('article','bestCategoryID','-'.$self->article_id),
        get_ckey('article','categoryName','-'.$self->article_id),
        get_ckey('article','allCategories',$self->article_id),
        get_ckey('article','lastChronologyKey',$self->article_id),
        get_ckey('template','artid',$self->article_id),
        get_ckey('template','fileSpotsForArt',$self->article_id),
        get_ckey('live','infolist',$self->article_id),
    );

    my $cats = $c->model('LIXUZDB::LzCategory')->search({}, { columns => [ 'category_id' ]});
    while(my $cat = $cats->next)
    {
        push(@keys, get_ckey('article','bestCategoryID',$cat->category_id.'-'.$self->article_id));
        push(@keys, get_ckey('article','categoryName',$cat->category_id.'-'.$self->article_id));
    }

    # Last chronology key fetched. Delete it if it is available.
    if(my $lastC = get_ckey('article','lastChronologyKey',$self->article_id))
    {
        push(@keys,
            $lastC,
        );
    }

    # Files
    my $files = $self->files;
    while(my $f = $files->next)
    {
        $c->cache->remove(get_ckey('file','imageHTMLString'.$f->file_id,'artid-'.$self->article_id));
    }

    # Clear what we have now
    foreach my $k (@keys)
    {
        $c->cache->remove($k);
    }
    # Clear infolist values that are for a certain URL
    my @infolists;
    # Default URL
    push(@infolists,$self->url($c));
    foreach my $ilistE (@infolists)
    {
        $c->cache->remove(get_ckey('live','infolist',$ilistE));
        if ($ilistE =~ s{^/+}{}g)
        {
            $c->cache->remove(get_ckey('live','infolist',$ilistE));
        }
    }
    # Clear URL caches
    $self->url_empty_cache($c);
    return true;
}

sub is_live
{
    my $self = shift;
    my $c = shift;

    my $extraLiveStatus = shift;
    my $overrideLive = shift;
    my $liveStatus = $overrideLive ? $overrideLive : 2;

    my @liveStatuses = ($liveStatus);

    if(ref($extraLiveStatus))
    {
        push(@liveStatuses,@{$extraLiveStatus});
    }
    elsif(defined $extraLiveStatus)
    {
        push(@liveStatuses,$extraLiveStatus);
    }

    my $ckey = get_ckey('article','livestatus',$self->article_id.'_'.join('_',@liveStatuses));
    my $return = $c->cache->get($ckey);
    if(defined $return)
    {
        return $return;
    }

    my $isLive = false;

    if(defined $self->status_id)
    {
        foreach my $status (@liveStatuses)
        {
            if ($self->status_id == $status)
            {
                $isLive = true;
                last;
            }
        }
    }
    if(not $isLive)
    {
        $return = false;
    }
    else
    {
        if (datetime_from_SQL_to_unix($self->publish_time) <= time())
        {
            $return = true;
            if(defined $self->expiry_time && 
                (datetime_from_SQL_to_unix($self->expiry_time) < time())
              )
            {
                $return = false;
            }
        }
        else
        {
            $return = false;
        }
    }

    if ($self->trashed)
    {
        $return = false;
    }

    my $cacheTime = CT_1H;

    if(not $return)
    {
        my $ptime = datetime_from_SQL_to_unix($self->publish_time);
        if(time() <= $ptime)
        {
            $cacheTime = $ptime-time();
        }
    }

    $c->cache->set($ckey,$return,$cacheTime);

    return $return;
}

# Summary: Retrieve the value of an additional field associated with this article
# Usage: article->getField($c,field_id);
# Returns an empty string if the field is empty or not associated with this article
#
# This method *will* resolve the field into its actual value, so you will get the
# text string associated with pulldowns, rather than the pulldown ID.
# If you need the ID/raw data, use getFieldRaw()
#
# TODO: Caching
sub getField
{
    my ($self,$c,$field_id) = @_;
    croak('$c missing in getField call') if not ref $c;
    my $value = $self->getFieldRaw($c,$field_id);
    
    return '' if not defined $value;

    my $field = $c->model('LIXUZDB::LzField')->find({ field_id => $field_id });

    if ($field->field_type =~ /^(singleline|multiline|meta-.+|date.*)$/)
    {
        # Raw value field, just return the data
        return $value;
    }
    elsif($field->field_type =~ /^(user-pulldown|multi-select)$/)
    {
        my @vals = split(/,/,$value);
        my @resolved;
        foreach my $v (@vals)
        {
            my $val = $c->model('LIXUZDB::LzFieldOptions')->find({
                    field_id => $field_id,
                    option_id => $v,
                });
            if(not defined $val)
            {
                $c->log->warn('Failed to locate value for option_id='.$v.' for field_id='.$field_id);
            }
            else
            {
                push(@resolved,$val->option_name);
            }
        }
        return(join(', ',@resolved));
    }
    else
    {
        $c->log->warn('Unhandled getField() field type "'.$field->field_type.'" - returning raw value');
        return $value;
    }
}

# Summary: Retrieve the raw/internal value of a field associated with this article
# Usage: article->getFieldRaw($c,field_id);
# Returns undef if the field has no value or does not have any associations with this
# article.
#
# This method will not return the user-facing value of a field, if you need
# the user-facing value use getField()
#
# TODO: Caching
sub getFieldRaw
{
    my ($self,$c,$field_id) = @_;
    my $value = $c->model('LIXUZDB::LzFieldValue')->find({
            module_id => $self->article_id,
            revision => $self->revision,
            field_id => $field_id,
        });
    if ($value)
    {
        return $value->value;
    }
    return;
}

# ---
# Category-related methods
# ---
#
# As an article can have more than one category, we refer to the "best"
# category here. The best category is the first category that is on the
# deepest level of subcategories for a folder.
#
# Ie.
# folder A is in the categories E, F, G/H/I, G/H/J
# Then the category "I" will be picked, as its the first one of a selection
# of deepest levels. If you later add the folder to G/H/J/K, then "I" will be
# replaced by "K".
#
# As a rule, the primary folder is the one used to resolve the category.
# If the primary isn't in any folder, then it will process each secondary folder
# until it finds one that is.

# Summary: Get the name of the best category
# Usage: name = $self->_get_best_category_name($c);
# 
# This can be fully cached, so use this if you don't need the object.
sub _get_best_category_name
{
    my($self,$c,$notIn) = @_;
    my $cat = $self->_get_best_category($c,$notIn);
    if ($cat)
    {
        return $cat->category_name;
    }
    else
    {
        return '';
    }
}

# Summary: Get the best category
# Usage: catObj = $self->_get_best_category($c,$notCat);
sub _get_best_category
{
    my($self,$c,$notCat) = @_;

    my $notCatK = defined $notCat ? $notCat : '';
    my $ckey =  get_ckey('article','bestCategoryID',$notCatK.'-'.$self->article_id);

    if (my $id = $c->cache->get($ckey))
    {
        return $c->model('LIXUZDB::LzCategory')->find({ category_id => $id });
    }

    my $folder;

    # Yes, we do need to fetch the folder twice (once to get the LzArticleFolder, then once more to get the LzFolder)
    my $bestCat;
    if($folder = $self->primary_folder)
    {
        $bestCat = $self->_get_best_category_for_folder($folder,$c,$notCat);
    }
    my $otherFolders = $self->secondary_folders;
    while((not defined $bestCat) and (defined $otherFolders) and (my $f = $otherFolders->next))
    {
        $bestCat = $self->_get_best_category_for_folder($f,$c,$notCat);
    }
    if ($bestCat)
    {
        $c->cache->set($ckey,$bestCat->category_id,3600);
        return $bestCat;
    }
    return undef;
}

# Summary: Get the best category for a folder
# Usage: catObj = $self->_get_best_category_for_folder($c);
#
# This uses a cached value if present.
sub _get_best_category_for_folder
{
    my($self,$folder,$c,$notCat) = @_;
    my $categories;
    # Get the LZFolder from the LZArticleFolder
    if(not $folder = $folder->folder)
    {
        return;
    }
    my $bestCategory;
    my $notCatK = defined $notCat ? $notCat : '';
    my $ckey = get_ckey('folder','bestCategory',$notCatK.'-'.$folder->folder_id);
    if (my $b = $c->cache->get($ckey))
    {
        if ($bestCategory = $c->model('LIXUZDB::LzCategory')->find({ category_id => $b }))
        {
            return $bestCategory;
        }
    }
    if(not $categories = $folder->categoryfolders->search(undef,{prefetch => 'category',columns => []}))
    {
        return;
    }
    while(my $cat = $categories->next)
    {
        $cat = $cat->category;
        if (defined $notCat && $cat->category_id == $notCat)
        {
            next;
        }
        if(not $bestCategory)
        {
            $bestCategory = $cat;
            next;
        }
        else
        {
            if (not defined $cat->parent)
            {
                next;
            }
            elsif(not defined $bestCategory->root_parent or not defined $bestCategory->parent)
            {
                $bestCategory = $cat;
                next;
            }
            elsif ($cat->root_parent == $bestCategory->category_id)
            {
                $bestCategory = $cat;
                next;
            }
            elsif ($cat->parent == $bestCategory->category_id)
            {
                $bestCategory = $cat;
                next;
            }
        }
    }
    if(not $bestCategory)
    {
        return;
    }
    $c->cache->set($ckey,$bestCategory->category_id,3600);
    return $bestCategory;
}

# Summary: Get all categories for a folder
# Usage: arrayOfIds = $self->_get_categories_for_folder($c,$folder);
sub _get_categories_for_folder
{
    my($self,$c,$folder) = @_;

    if(not $folder)
    {
        $c->log->warn('_get_categories_for_folder was called without a folder on '.$self->article_id);
        return [];
    }

    my $ckey = get_ckey('folder','allCategories',$folder->folder_id);

    if (my $categories = $c->cache->get($ckey))
    {
        return @{$categories};
    }

    my $categories;
    my @catIds;

    if(not $categories = $folder->categoryfolders->search(undef,{columns => ['category_id']}))
    {
        return undef;
    }
    while(my $cat = $categories->next)
    {
        push(@catIds,$cat->category_id);
    }
    $c->cache->set($ckey,\@catIds,3600);
    return @catIds;
}

# Summary: Get the name of the (best) category this article lives in
# Usage: name = article->category_name($c,$notInCategory);
sub category_name
{
    my $self = shift;
    my $c = shift or croak('$c missing');
    my $notIn = shift;
    my $notInK = defined $notIn ? $notIn : '';
    my $ckey = get_ckey('article','categoryName',$notInK.'-'.$self->article_id);


    if (my $value = $c->cache->get($ckey))
    {
        return $value;
    }

    if(my $bestCategory = $self->_get_best_category_name($c,$notIn))
    {
        $c->cache->set($ckey,$bestCategory,CT_DEFAULT);
        return $bestCategory;
    }
    else
    {
        $c->cache->set($ckey,'',CT_DEFAULT);
        return '';
    }
}

# Summary: Get the ID of the (best) category this article lives in
# Usage: id = article->category_id($c)
sub category_id
{
    my $self = shift;
    my $c = shift or croak('$c missing');

    my $cat = $self->_get_best_category($c);
    if ($cat)
    {
        return $cat->category_id;
    }
    return;
}

# Summary: Get the object of the (best) category this article lives in
# Usage: obj = article->category($c);
sub category
{
    my $self = shift;
    my $c = shift or croak('$c missing');

    my $cat = $self->_get_best_category($c);
    return $cat;
}

# Summary: Check if this article is in the category_id supplied
# Usage: bool = article->in_category($c, catid)
sub in_category
{
    my($self,$c,$catid) = @_;

    my $specific_ckey = get_ckey('article','inCategory',$self->article_id.'-'.$catid);
    my $generic_ckey  = get_ckey('article','allCategories',$self->article_id);
    my $bool = $c->cache->get($specific_ckey);

    if(defined $bool)
    {
        return $bool;
    }

    my @categories;

    if(my $cats = $c->cache->get($generic_ckey))
    {
        @categories = @{$cats};
    }
    else
    {
        if(my $folder = $self->primary_folder)
        {
            $folder = $folder->folder;
            push(@categories, $self->_get_categories_for_folder($c,$folder));
        }
        my $otherFolders = $self->secondary_folders;
        while(my $f = $otherFolders->next)
        {
            $f = $f->folder;
            push(@categories, $self->_get_categories_for_folder($c,$f));
        }
        $c->cache->set($generic_ckey,\@categories,3600);
    }

    $bool = 0;
    foreach my $cid (@categories)
    {
        if (defined($cid) && $cid == $catid)
        {
            $bool = 1;
            last;
        }
    }
    $c->cache->set($specific_ckey,$bool,3600);
    return $bool;
}

# ---
# Lock methods
# ---

# Summary: Check to see if the article is locked
# Usage: bool = article->locked($c);
# Returns true if the article is locked, false otherwise.
sub locked
{
    my $self = shift;
    my $c = shift or die('$c missing');
    my $lockEntry = $self->lockTable;
    # No lock? Then it's not locked.
    if(not $lockEntry)
    {
        return;
    }
    # Locked by us? Then it's not really locked
    if ($lockEntry->user->user_id == $c->user->user_id)
    {
        return;
    }
    # TODO: Check how these time()-based checks behave when switching forward/back from DST
    # Maybe simply an int column with gmtime() would be better.
    if (datetime_from_SQL_to_unix($lockEntry->locked_at) <= (time() - (60*4)))
    {
        return;
    }
    # Locked for more than an hour without changing?
    if ($lockEntry->updated_at and
        datetime_from_SQL_to_unix($lockEntry->updated_at) <= (time() - (60*60)))
    {
        return;
    }
    # Ok, it's locked.
    return true;
}

# Summary: Lock an article (or update an existing lock)
# Usage: locked = $art->lock($c,saved?,force?);
# Returns true if the article was successfully locked, false otherwise
# If saved is true then it will also update the updated_at column, bumping
#  the time until it forcefully expires to one hour from now.
# If force is true then it will forcefully take the lock, even if some
#  other user is currently holding it.
sub lock
{
    my $self = shift;
    my $c = shift or die('$c missing');
    my $saved = shift;
    my $forceSteal = shift;
    if (not $forceSteal and $self->locked($c))
    {
        return;
    }
    my $lock;
    my $update = {
        locked_by_user => $c->user->user_id,
        locked_at => \'now()',
    };
    if(not $lock = $self->lockTable)
    {
        try
        {
            $lock = $c->model('LIXUZDB::LzArticleLock')->create({ article_id => $self->article_id,
                    locked_by_user => $c->user->user_id,
                    updated_at => \'now()',
                });
        }
        catch
        {
            # Locking failed, check again for our lock, and if it's still
            # not there, give up.
            $lock = $self->lockTable;
        };
        if (not $lock)
        {
            $c->log->warn('Failed to aquire lock for '.$self->article_id.' for '.$c->user->user_id);
            return false;
        }
    }
    # If we just saved (or opened) the article or the article was previously not locked by us
    # then update updated_at
    elsif($saved or $lock->locked_by_user != $c->user->user_id)
    {
        $update->{updated_at} = \'now()';
    }
    # If we're not updating the update_at entry and it is outdated, refuse to
    # keep the lock.
    elsif (datetime_from_SQL_to_unix($lock->updated_at) <= (time() - (60*60)))
    {
        return false;
    }
    $lock->update($update);
    return true;
}

# Summary: Return the user name of the user that currently holds the lock on
#   this article
# Usage: user = article->locked_by($c);
#
# Returns undef if the article isn't locked.
sub locked_by
{
    my $self = shift;
    my $c = shift or die('$c missing');
    return if not $self->locked($c);
    my $lockEntry = $self->lockTable;
    return $lockEntry->user->user_name;
}

# Summary: Unlock an article
# Usage: article->unlock($c);
# XXX: Use with care, this doesn't do ANY ACL, it is assumed that when you
#   call this you already know that the user should be allowed to unlock it.
sub unlock
{
    my $self = shift;
    my $c = shift or die('$c missing');
    my $lockEntry = $self->lockTable;
    if(not $lockEntry)
    {
        return true;
    }
    elsif(not $self->locked($c))
    {
        $lockEntry->delete();
        return true;
    }
    return;
}

# Summary: Check if the article lock will time out soon
# Usage: bool = article->lockTimeoutSoon($c);
sub lockTimeoutSoon
{
    my $self = shift;
    my $c = shift or die('$c missing');
    my $lock = $self->lockTable;
    if (datetime_from_SQL_to_unix($lock->updated_at) <= (time() - (60*50)))
    {
        return true;
    }
    return false;
}

# You can replace this text with custom content, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
