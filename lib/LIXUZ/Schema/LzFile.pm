package LIXUZ::Schema::LzFile;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';


=head1 NAME

LIXUZ::Schema::LzFile

=cut

__PACKAGE__->table("lz_file");

=head1 ACCESSORS

=head2 file_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 file_name

  data_type: 'varchar'
  is_nullable: 1
  size: 100

=head2 path

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 owner

  data_type: 'integer'
  is_nullable: 1

=head2 title

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 caption

  data_type: 'text'
  is_nullable: 1

=head2 width

  data_type: 'smallint'
  is_nullable: 1

=head2 height

  data_type: 'smallint'
  is_nullable: 1

=head2 size

  data_type: 'integer'
  is_nullable: 1

=head2 format

  data_type: 'char'
  is_nullable: 1
  size: 5

=head2 last_edited

  data_type: 'timestamp'
  default_value: current_timestamp
  is_nullable: 0

=head2 upload_time

  data_type: 'timestamp'
  default_value: '0000-00-00 00:00:00'
  is_nullable: 0

=head2 clone

  data_type: 'integer'
  is_nullable: 1

=head2 status

  data_type: 'enum'
  default_value: 'Active'
  extra: {list => ["Active","Inactive"]}
  is_nullable: 1

=head2 trashed

  data_type: 'tinyint'
  is_nullable: 1

=head2 identifier

  data_type: 'varchar'
  is_nullable: 1
  size: 10

=head2 class_id

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "file_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "file_name",
  { data_type => "varchar", is_nullable => 1, size => 100 },
  "path",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "owner",
  { data_type => "integer", is_nullable => 1 },
  "title",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "caption",
  { data_type => "text", is_nullable => 1 },
  "width",
  { data_type => "smallint", is_nullable => 1 },
  "height",
  { data_type => "smallint", is_nullable => 1 },
  "size",
  { data_type => "integer", is_nullable => 1 },
  "format",
  { data_type => "char", is_nullable => 1, size => 5 },
  "last_edited",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 0,
  },
  "upload_time",
  {
    data_type     => "timestamp",
    default_value => "0000-00-00 00:00:00",
    is_nullable   => 0,
  },
  "clone",
  { data_type => "integer", is_nullable => 1 },
  "status",
  {
    data_type => "enum",
    default_value => "Active",
    extra => { list => ["Active", "Inactive"] },
    is_nullable => 1,
  },
  "trashed",
  { data_type => "tinyint", is_nullable => 1 },
  "identifier",
  { data_type => "varchar", is_nullable => 1, size => 10 },
  "class_id",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("file_id");


# Created by DBIx::Class::Schema::Loader v0.07002 @ 2012-03-12 13:16:25
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:1UOKxXzwNJbkZrCEtHMjwA

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

use Graphics::Magick;
use Carp;
use LIXUZ::HelperModules::Cache qw(get_ckey CT_24H);
use LIXUZ::HelperModules::Files qw(get_new_aspect get_new_aspect_constrained fsize);
use File::MMagic::XS qw(:compat);
use URI::Escape qw(uri_escape);
use Math::Int2Base qw( int2base );

__PACKAGE__->belongs_to('ownerUser' => 'LIXUZ::Schema::LzUser', { 'foreign.user_id' => 'self.owner' });
__PACKAGE__->has_many('clones' => 'LIXUZ::Schema::LzFile', { 'foreign.clone' => 'self.file_id' });
__PACKAGE__->has_many('folders' => 'LIXUZ::Schema::LzFileFolder', 'file_id');
__PACKAGE__->has_many('articles' => 'LIXUZ::Schema::LzArticleFile', 'file_id');
__PACKAGE__->has_many(tags => 'LIXUZ::Schema::LzFileTag',{
    'foreign.file_id' => 'self.file_id',
    });

use 5.010;
use Moose;
with 'LIXUZ::Role::Serializable';
with 'LIXUZ::Role::IndexTriggers';
with 'LIXUZ::Role::Taggable';

around identifier => sub
{
    my $orig = shift;
    my $self = shift;

    my $ret = $self->$orig(@_);
    if(not defined $ret)
    {
        $ret = $self->_addIdentifier;
    }
    return $ret;
};

sub _addIdentifier
{
    my $self = shift;
    my $exists = 1;
    my $identifier;

    while($exists)
    {
        $identifier = int2base( $self->file_id + int(rand(9999999)) + $$, 62);

        # Anti-profanity filter
        $identifier =~ s/(i|l|q|u|f)//gi;
        # Don't allow only-numeric ones, because they can be easily confused
        # with ID numbers
        next if not $identifier =~ /\D/;
        # Don't allow too short ones
        next if not length($identifier) > 2;

        my $existing = $self->result_source->schema->resultset('LzFile')->find({ identifier => $identifier });
        if (not $existing)
        {
            $exists = 0;
        }
    }
    $self->update({ identifier => $identifier });

    return $identifier;
}

sub _serializeExtra
{
    # Extra fields or values to serialize. See LIXUZ::Role::Serializable for
    # the format.
    return [ 'is_image','is_flash','is_video', 'is_audio',
    { saveAs => 'format', source => 'get_format'},
    { saveAs => 'icon', source => 'get_icon'},
    { saveAs => 'folder', source => 'get_folder_path'}
    ];
}

# Summary: Get the folder path for this file
# Usage: folder = file->get_folder_path
sub get_folder_path
{
    my($self) = @_;
    if ($self->folder)
    {
        return $self->folder->get_path;
    }
    return '';
}

# Summary: Check if the current user can edit this file
# Usage: article->can_edit($c);
sub can_edit
{
    my($self,$c) = @_;
    # A super user can do anything she likes
    if ($c->user->can_access('EDIT_OTHER_FILES'))
    {
        return 1;
    }
    elsif($c->user->user_id == $self->owner)
    {
        return 1;
    }
    return 0;
}

# Summary: Check if the current user can read this file
# Usage: file->can_read($c);
sub can_read
{
    my($self,$c) = @_;
    if ($self->status eq 'Active')
    {
        return 1;
    }
    if (not $c->user)
    {
        return;
    }
    return 1 if $c->user->super_user;
    if ($self->owner == $c->user->user_id)
    {
        return 1;
    }

    if(not $self->folder)
    {
        return 1;
    }
    return $self->folder->can_read($c);
}

# This is an alias for ->primary_folder->folder
sub folder
{
    my($self) = @_;
    if ($self->primary_folder)
    {
        return $self->primary_folder->folder;
    }
    return;
}

# This is an alias for ->primary_folder->folder_id
sub folder_id
{
    my($self) = @_;
    if ($self->primary_folder)
    {
        return $self->primary_folder->folder_id;
    }
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

# ---
# TEMPLATE METHODS
# ---
# These methods are meant for use within Lixuz templates, to ease use of
# file spots

# Summary: Get HTML for showing an image
# Usage: html = file->get_imghtml($c, height, width, align?);
# align is optional and defaults to center
# either or both of height/width can be undef
sub get_imghtml
{
    my $self = shift;
    my $c = shift;
    if (!$self->is_image)
    {
        return '';
    }
    my $height = shift;
    my $width = shift;
    ($height,$width) = $self->_fullSizeSanitize($c,$height,$width);
    my $align = shift;
    $align = $align ? $align : 'center';

    my $style = '';
    my $addHTML = ' alt="" title="" align="'.$align.'"';

    my $str = '<img src="'.$self->get_url($c,$height,$width).'" ';
    if(defined $height)
    {
        $style = 'height:'.$height.';';
        $addHTML .= ' height="'.$height.'"';
    }
    if (defined $width)
    {
        $style = 'width:'.$width.';';
        $addHTML .= ' width="'.$width.'"';
    }
    $str .= 'style="'.$style.'"'.$addHTML;
    $str .= ' />';
    return $str;
}

# Summary: Get HTML for shoing an image including its caption
# Usage: html = file->get_imghtmlWithCaption($c, { PARAMS })
# 
# PARAMS is a hashref with zero or more of the following keys:
#   height => the height of the image
#   width => the width of the image
#   align => the alignment of the image
#   wrap => [] an array of strings to wrap around the entire result,
#       index 0 is prepended, index 1 is appended, anything else is ignored.
#   wrapImg => [] an array of strings to wrap around the <img>,
#       index 0 is prepended, index 1 is appended, anything else is ignored.
#   wrapCaption => [] an array of strings to wrap around the caption text,
#       index 0 is prepended, index 1 is appended, anything else is ignored.
#   appendFields => [] an array of additional field IDs that should be appended
#       to the end of the caption
#   wrapFields => [] an array of string to wrap around any appended fields,
#       index 0 is prepended, index 1 is appended, anything else is ignored.
#   EITHER:
#   artid => The article ID this image is associated with. If undef, the images
#       default caption will be used.
#   revision => The revision of artid this image is associated with
#   OR:
#   article => The LzArticle object this image is associated with. This will
#               auto-populate the artid and revision fields for you
sub get_imghtmlWithCaption
{
    my $self = shift;
    my $c = shift;
    my $options = shift;
    if (!$self->is_image)
    {
        return '';
    }

    my $ckey;

    if ($options->{article})
    {
        $options->{artid} = $options->{article}->article_id;
        $options->{revision} = $options->{article}->revision;
    }

    if($ckey = $options->{artid})
    {
        my $revision = $options->{revision};
        $revision //= 0;
        $ckey = get_ckey('file','imageHTMLString'.$self->file_id,'artid-'.$ckey.'-'.$revision);
        if (my $result = $c->cache->get($ckey))
        {
            return $result;
        }
    }

    my ($width,$height,$align) = ($options->{width}, $options->{height}, $options->{align});
    my $imgHtml = $self->get_imghtml($c,$height,$width,$align);
    if ($options->{wrapImg})
    {
        my $w = $options->{wrapImg};
        $imgHtml = $w->[0].$imgHtml.$w->[1];
    }

    my $caption = $self->get_caption($c,$options->{artid},$options->{revision});
    $caption = defined $caption ? $caption : '';

    if(defined $options->{appendFields})
    {
        foreach my $fieldId (@{$options->{appendFields}})
        {
            my $content = $self->getFieldContents($c,$fieldId);
            if(defined $content)
            {
                if ($options->{wrapFields})
                {
                    my $w = $options->{wrapFields};
                    $content = $w->[0].$content.$w->[1];
                }
                $caption .= $content;
            }
        }
    }

    if ($options->{wrapCaption})
    {
        my $w = $options->{wrapCaption};
        $caption = $w->[0].$caption.$w->[1];
    }

    my $final = $imgHtml.$caption;
    if ($options->{wrap})
    {
        my $w = $options->{wrap};
        $final = $w->[0].$final.$w->[1];
    }

    if ($ckey)
    {
        $c->cache->set($ckey,$final,3600);
    }

    return $final;
}

# Summary: Get HTML for showing a flash file
# Usage: html = file->get_flashhtml($c,$extraParams?, $settings?);
# extraParams is a hsahref of strings, the strings are complete attrib="value" pairs
# that you want put into the tag returned
#
# settings is a hashref of key => value pairs, used to define specific settings
# for the flash file. The following are available and recognized:
#   clickTAG => the link to use as clicktag value.
#
# FIXME: $extraParams is *not* working and needs fixing asap
#         do not use them. The API also needs changing.
sub get_flashhtml
{
    my $self = shift;
    my $c = shift;
    my $extra = shift;
    my $settings = shift;
    my $flashURL = shift;
    if (!$self->is_flash)
    {
        return '';
    }
    if(not $flashURL)
    {
        $flashURL = $self->get_url($c);
    }
    my $width = $self->width ? $self->width : 300;
    my $height = $self->height ? $self->height : 300;
    my $url = $flashURL;
    if ($settings && ref($settings) && $settings->{clickTAG})
    {
        $url .= '?';
        my $f = 1;
        my $tag = uri_escape($settings->{clickTAG});
        foreach my $t (qw(clickTAG clickTag ClickTag ClickTAG))
        {
            $url .= '&' if not $f;
            $url .= $t.'='.$tag;
            $f = 0;
        }
    }
    my $html = '<object classid="clsid:D27CDB6E-AE6D-11cf-96B8-444553540000" codebase="http://download.macromedia.com/pub/shockwave/cabs/flash/swflash.cab#version=6,0,40,0" width="'.$width.'" height="'.$height.'">';
    $html .= '<param name="movie" value="'.$url.'" />';
    $html .= '<param name="allowscriptaccess" value="name" />';
    $html .= '<param name="allowfullscreen" value="false" />';
    $html .= '<embed src="'.$url.'" width="'.$width.'" height="'.$height.'" allowscriptaccess="never" allowfullscreen="false" type="application/x-shockwave-flash" pluginspage="http://www.macromedia.com/go/getflashplayer"';
    if($extra && ref($extra) eq 'ARRAY')
    {
        $html .= ' ';
        $html .= join(' ',@{$extra});
    }
    $html .= '></embed>';
    $html .= '</object>';
    return $html;
}

# Purpose: Get the contents of an additional field associated with this file
# Usage: content = file->getFieldContents($c,field_id);
sub getFieldContents
{
    my($self,$c,$fieldId) = @_;

    my $field = $c->model('LIXUZDB::LzFieldValue')->find({ 
            field_id => $fieldId,
            module_id => $self->file_id,
            module_name => 'files',
        });
    if(not $field)
    {
        return;
    }
    return $field->value;
}

# Purpose: Get a list of all fields associated with this file and their values
# Usage: hashref = file->getAllFields($c);
#
# If a field has no value, it will not be returned in the hashref - even
# if the field is associated with files.
sub getAllFields
{
    my($self,$c) = @_;
    my $href = {};
    my $fields = $c->model('LIXUZDB::LzFieldValue')->search({ module_id => $self->file_id, module_name => 'files' });
    while(my $f = $fields->next)
    {
        $href->{$f->field_id} = $f->value;
    }
    return $href;
}

# ---
# File format methods
# ---

# Summary: Check if the current file is an image
# Usage: bool = file->is_image()
# Returns: true if it is an image, false otherwise
sub is_image
{
    my $self = shift;
    my $format = $self->get_format;
    if(defined $format)
    {
        if ($format =~ /(tiff?|bmp|png|jpe?g|gif)$/i)
        {
            return 1;
        }
    }
    return;
}

# Summary: Check if the current file is a flash file
# Usage: bool = file->is_flash()
# Returns: true if it is a flash file, false otherwise
sub is_flash
{
    my $self = shift;
    my $format = $self->get_format;
    if (defined $format)
    {
        if ($format =~ /(swf)$/i)
        {
            return 1;
        }
    }
    return;
}

# Summary: Check if the current file is a video
# Usage: bool = file->is_video()
# Returns: true if it is a video, false otherwise
sub is_video
{
    my $self = shift;
    my $format = $self->get_format;
    if (defined $format)
    {
        # TODO: We should support proper video for ogm
        if ($format =~ /(avi|wmv|mpe?g4?|mov|flv|divx|xvid|ogm|mp4)$/i)
        {
            return 1;
        }
    }
    return;
}

# Summary: Check if the current file is a audio file
# Usage: bool = file->is_audio(ALL?)
# If ALL is false (default), then the only audio type recognized is MP3 (because that's
#   what Lixuz can play), if ALL is true then it will also return true for audio
#   files that Lixuz can't play.
# Returns: true if it is a audio file, false otherwise
sub is_audio
{
    my $self = shift;
    my $allTypes = shift;
    my $format = $self->get_format;
    if (defined $format)
    {
        if ($allTypes)
        {
            return $format =~ /(ogg|mp3|wma|mp2|aac)$/i;
        }
        else
        {
            return $format =~ /(mp3)$/i;
        }
    }
    return;
}

# Summary: Get the file format of the current file
# Usage: format = file->get_format
# Returns: The filename extension associated with the format (ie. png, zip, xml)
#
# This may fail, in which case it will return the full file name instead
sub get_format
{
    my $self = shift;
    if ($self->format)
    {
        return $self->format;
    }
    my $newFormat = $self->file_name;
    if(not $newFormat =~ s/^.*\.([^\.]+)$/$1/)
    {
        # Confused, giving up
        return $newFormat;
    }
    $self->set_column('format',$newFormat);
    $self->update();
    return $newFormat;
}

# Summary: Get the mimetype of the current file
# Usage: mimetype = file->get_mimetype($c);
sub get_mimetype
{
    my($self,$c) = @_;
    my $ckey = get_ckey('file','mimetype',$self->file_id);
    my $type;
    if ($type = $c->cache->get($ckey))
    {
        return $type;
    }
    eval
    {
        my $magic = File::MMagic::XS->new;
        #my $magic = File::MMagic->new;
        $type = $magic ->checktype_filename($self->get_path($c));
        $c->cache->set($ckey,$type,CT_24H);
        1;
    }
        or do
    {
        my $err = $@;
        $type = 'application/octet-stream';
        $ckey = undef;
        $c->log->error('File::MMagic crashed, defaulting to application/octet-stream and refusing to cache info');
        $c->log->debug('Error from perl: '.$err);
    };
    return $type;
}

# Summary: Get all fields from this file in a hash
# Usage: object->get_everything();
# Returns: Hash with field => value pairs.
sub get_everything
{
    my $self = shift;
    my %Return;
    foreach my $col( qw(file_id file_name path owner title caption width height size format last_edited upload_time clone status) )
    {
        $Return{$col} = $self->get_column($col);
    }
    return(\%Return);
}

# ---
# Path/icon methods
# ---

# Summary: Get the local file path to the file
# Usage: object->get_path($c);
# Returns: String, path to file
sub get_path
{
    my $self = shift;
    my $c = shift;
    if(not $c)
    {
        croak('$c not supplied to file->get_path');
    }
    my $path = $c->config->{LIXUZ}->{file_path};
    $path .= '/'.$self->file_id;
    return $path;
}

# Summary: Get the filesize as a string
# Usage: string = file->sizeString
# Returns: A human readable string representing the size of the file. (ie. 2 MB, 23 KB)
sub sizeString
{
    my $self = shift;
    my $c = shift or die;
    return $self->_sizeStringForPath($c);
}

# Summary: Get the (web server visible) path to the icon for this file
# Usage: path_string = file->get_icon($c);
sub get_icon
{
    my $self = shift;
    my $c = shift;
    my $icon;
    if ($self->is_image && $c)
    {
        $icon = $self->get_url_aspect($c,150,150);
    }
    elsif($self->is_video)
    {
        $icon = '/static/images/icons/mimetypes/video.png';
    }
    elsif($self->is_audio(1))
    {
        $icon = '/static/images/icons/mimetypes/audio.png';
    }
    elsif($self->is_flash)
    {
        $icon = '/static/images/icons/mimetypes/flash.png';
    }
    elsif($self->file_name =~ /\.pdf$/i)
    {
        $icon = '/static/images/icons/mimetypes/pdf.png';
    }
    elsif($self->file_name =~ /\.(odt|sxw|docx?|rtf|txt)$/i)
    {
        $icon = '/static/images/icons/mimetypes/document.png';
    }
    elsif($self->file_name =~ /\.(sxc|ods|csv|xls[xmb]?)$/i)
    {
        $icon = '/static/images/icons/mimetypes/spreadsheet.png';
    }
    else
    {
        $icon = '/static/images/icons/mimetypes/unknown.png';
    }
    return $icon;
}

# Summary: Get a HTML version of the file that looks like a file in a file manager
# Usage: html = file->get_iconItem($c)
# Returns: HTML
sub get_iconItem
{
    my $self = shift;
    my $c = shift or die;
    my $iconItem = $self->get_iconItemBasic($c);
    $iconItem .= '<br /><span class="fileInfo">';
    $iconItem .= $c->stash->{i18n}->get('File ID:');
    $iconItem .= ' '.$self->file_id;
    $iconItem .= '<br />Size: '.$self->sizeString($c).'</span>';
    return $iconItem;
}

# Summary: iconItem that builds upon a table
# Usage: html = file->get_iconItemTable($c, includeObjChildJS);
#
# If includeObjChildJS is true, the returned string will contain a 'View other versions'
# link that has an onclick that calls currObjSelectorAddFilter(childOf='.$file->file_id)
sub get_iconItemTable
{
    my $self = shift;
    my $c = shift or die;
    my $includeObjChildJS = shift;
    my $i18n = $c->stash->{i18n};
    my $iconItem = '<table><tr><td style="min-height: 84px;"><center><img class="filePreview" style="border:0;" src="'.$self->get_icon($c).'" /></center></td></tr><tr><td>';
    $iconItem .= '<span class="fileInfo">';
    my $name = $self->file_name;
    $name =~ s/(.{17})/$1<br \/>/g;
    $iconItem .= $name.'</td></tr><tr><td>';
    $iconItem .= $c->stash->{i18n}->get('File ID:');
    $iconItem .= ' '.$self->file_id;
    $iconItem .= '<br />Size: '.$self->sizeString($c);
    my $folderpath = $i18n->get('(none)');
    if ($self->folder && $self->folder->get_path)
    {
       $folderpath = $self->folder->get_path;    
    }    
    if(length($folderpath) > 12)
     {
       $iconItem .= '<br />'.$i18n->get('Folder:');
       $iconItem .= '<span class="useTipsy" original-title="'.$folderpath.'"> '.substr($folderpath,1,10).'...</span>';
     }
     else
    {
       $iconItem .= '<br />'.$i18n->get('Folder:');     
       $iconItem .= '<span> '.$folderpath.'</span>';
    }

    if ($includeObjChildJS && $self->clones->count)
    {
        $iconItem .= '<br /><a href="#" style="text-decoration:none;" onclick="currObjSelectorAddDestructiveFilter(\'childOf='.$self->file_id.'\');">';
        $iconItem .= $c->stash->{i18n}->get('View other versions');
        $iconItem .= '</a>';
    }
    $iconItem .= '</span>';
    $iconItem .= '</td></tr></table>';
    return $iconItem;
}

# Summary: Get a HTML version of the file that looks like a file in a file manager
# Usage: html = file->get_iconItem
# Returns: HTML
# 
# This is simply a stripped down version of get_iconItem (in fact, get_iconItem builds
#  upon this one), this includes less information.
sub get_iconItemBasic
{
    my $self = shift;
    my $c = shift or die;
    my $onlyImage = shift;
    my $iconItem;
    my $icon = $self->get_icon($c);
    $iconItem = '<div class="fileEntryPreview" name="fileEntry" style="height:150px; width:150px;"><img class="filePreview" style="border:0;" src="';
    $iconItem .= $icon;
    $iconItem .='" /></div>';
    if ($onlyImage)
    {
        return $iconItem;
    }
    $iconItem .= '<span class="fileName">';
    # Ensure filenames aren't too long
    my $name = $self->file_name;
    $name =~ s/([^<]{15})/$1<br \/>/;
    $iconItem .= $name;
    $iconItem .= '</span>';
}

# ----------------------
# IMAGE SPECIFIC METHODS
# ----------------------

# Summary: Get the image caption. Either an article-specific one, or the image one.
# Usage: caption = self->get_caption($c,artid,revision);
sub get_caption
{
    my($self,$c,$artid,$revision) = @_;

    if(defined $artid)
    {
        my $search =  { file_id => $self->file_id, article_id => $artid };
        if(defined $revision)
        {
            $search->{revision} = $revision;
        }
        my $rel = $c->model('LIXUZDB::LzArticleFile')->find($search);
        if (defined $rel && $rel->caption)
        {
            return $rel->caption;
        }
    }
    return $self->caption;
}

# Summary: Detects width and height of an image and sets them
# Usage: file->detectImageFields
# Returns: Nothing
sub detectImageFields
{
    my ($self, $c) = @_;
    if ($self->is_image)
    {
        my $gm = Graphics::Magick->new;
        my ($width, $height, $size, $format) = $gm->Ping($self->get_path($c));
        if(not defined $height or not defined $width)
        {
            if ($format)
            {
                $c->log->warn('Failed to detect height/width for file '.$self->file_id.'. GraphicsMagick said the format was '.$format.' - get_format() said it was '.$self->get_format());
            }
            elsif(defined($width) and $width =~ /\D/)
            {
                $c->log->warn('Failed to detect height/width for file '.$self->file_id.'. GraphicsMagicks Ping function appears to have failed: '.$width);
            }
            else
            {
                $c->log->warn('Failed to detect height/width for file '.$self->file_id.'. GraphicsMagick failed to even detect the format - get_format() said it was '.$self->get_format());
            }
            return;
        }
        $self->set_column('height',$height);
        $self->set_column('width',$width);
        $self->update();
    }
}

# Summary: Get the url to the image (or even file)
# Usage: url = object->get_url($c, height, width);
# height and width are optional parameters that only affect images
# Returns: String, URL to file
sub get_url
{
    my $self = shift;
    my $c = shift;
    my($height,$width) = @_;
    my $URL = '/files/get/'.$self->identifier;
    my $params = {};
    if ($self->is_image)
    {
        if ($height)
        {
            $params->{height} = $height;
        }
        if ($width)
        {
            $params->{width} = $width;
        }
    }
    else
    {
        my $fnam;
        if(not $fnam = $self->file_name)
        {
            $c->log->warn('Non-image file didn\'t have a file_name');
        }
        $fnam =~ s/\s+/_/g;
        $URL .= '/'.$fnam;
    }
    if ($c)
    {
        return $c->uri_for($URL, $params)->as_string;
    }
    else
    {
        return($URL);
    }
}

# Summary: Get a resized version of the file with dimensions as close to the
#           specified size as possible
# Usage: url = obj->get_url_aspect($c, height,width);
#          OR
#        (url,height,width) = obj->get_url_aspect($c, height,width);
sub get_url_aspect
{
    my($self, $c, $height, $width) = @_;

    # Die if this isn't an image file
    if (!$self->is_image)
    {
        carp('get_url_aspect called on non-image file '.$self->file_id);
    }

    # If we only got either height or width, then hand control to get_url,
    # as we don't need to do any calculation
    if ( !defined($height) || !defined($width) )
    {
        my $URL = $self->get_url($c,$height,$width);
        return $self->_returnStringAndAspect(wantarray,$URL,$height,$width);
    }

    # Detect height/width if needed
    if (not $self->height or not $self->width)
    {
        $self->detectImageFields($c);
        if (not $self->height or not $self->width)
        {
            $c->log->warn('Failed to detect height/width for '.$self->file_id.' - unable to generate url with aspect ratio. Returning original image size instead.');
            my $URL = $self->get_url($c);
            return $self->_returnStringAndAspect(wantarray,$URL);
        }
    }
    # If both the height and the width exceed the original height/width, then
    # return the original size instead of the resized size
    if ($width >= $self->width && $height >= $self->height)
    {
        return $self->get_url($c);
    }

    # If either the height or width exceed the original, then use the original
    if ($height > $self->height)
    {
        $height = $self->height;
    }
    if ($width > $self->width)
    {
        $width = $self->width;
    }

    ($width,$height) = get_new_aspect_constrained($self->width,$self->height,$width,$height);

    my $URL = $self->get_url($c, $height,$width);

    return $self->_returnStringAndAspect(wantarray,$URL,$height,$width);
}

# Summary: Get a resized version of this file
# Usage: path = object->get_resized($c,height,width);
# Both height and width are optional
# Returns: String, path to resized file
sub get_resized
{
    my($self, $c, $height, $width) = @_;

    ($height,$width) = $self->_fullSizeSanitize($c,$height,$width);
    # Keep track of if we were supplied both or not
    my $had_height = (defined $height and length $height) ? 1 : 0;
    my $had_width = (defined $width and length $width) ? 1 : 0;

	my $path = $self->get_path($c);
    if(not $self->is_image)
    {
        $c->log->error('get_resized() called on non-image, returning raw file (file ID '.$self->file_id.')!');
        return $self->_path_or_undef($c,$self->get_path($c));
    }
    elsif(not defined $height and not defined $width)
    {
        return $self->_path_or_undef($c,$self->get_path($c));
    }

    if ($had_height and $height =~ /\D/)
    {
        $c->log->warn('get_resized() called with nondigit height ("'.$height.'"), ignoring height request');
        $height = undef;
    }

    if($had_width and $width =~ /\D/)
    {
        if ($had_height and not defined $height)
        {
            $c->log->warn('get_resized() called with nondigit/invalid width and height, erroring out');
            return undef;
        }
        $c->log->warn('get_resized() called with nondigit width ("'.$width.'"), ignoring width request');
        $width = undef;
    }

    if(defined $height and $height == 0)
    {
        $c->log->warn('get_resized() cowardly refusing to use a height that is zero');
        $height = undef;
    }
    elsif(defined $width and $width == 0)
    {
        $c->log->warn('get_resized() cowardly refusing to use a width that is zero');
        $width = undef;
    }

    if((not $height or not $width) && (not $self->height or not $self->width))
    {
        $c->log->warn('File '.$self->file_id.' was missing height and/or width, detecting and adding them');
        $self->detectImageFields($c);
    }
    if(not $height and not $width)
    {
        $c->log->warn('get_resized(): Recieved useless height and width, unable to resize without at least one. Ignoring request.');
        return;
    }

    my $fname = $path.'-';
    # Get new aspect params if needed
    if (not $height)
    {
        $height = get_new_aspect($self->width,$self->height,$width);
    }
    if (not $width)
    {
        $width = get_new_aspect($self->width,$self->height,undef,$height);
    }

    # If we don't have a height nor a width then something went wrong
    if(int($height) <= 0 && int($width) <= 0)
    {
        $c->log->warn('Ended up with zero width and zero height, this can\'t be right. Ignoring request');
        return;
    }

    $fname .= 'h'.int($height).'w'.int($width);
    $fname .= '.imgcache';
    # If it already exists then just return the path to it
    if (-e $fname)
    {
        return $fname;
    }

    # Okay, the file didn't exist, so we need to create it
    my $gm = Graphics::Magick->new;

    if(not -r $path)
    {
        if(not -e $path)
        {
            $c->log->error('get_resized(): failed to locate the original image on-disk ('.$path.'): Giving up.');
        }
        else
        {
            $c->log->error('get_resized(): '.$path.': is for some reason not reaable by me: Giving up.');
        }
        return;
    }
    my $e = $gm->Read($path);
    if ($e)
    {
        $c->log->error('get_resized(). GraphicksMagick failed to read the file: '.$e);
        return;
    }
    if ($height and $width)
    {
        $e = $gm->Scale(
            height => $height,
            width => $width,
        );
        if ($e)
        {
            $c->log->error('get_resized(). GraphicksMagick failed to scale the file: '.$e);
            return;
        }
    }
    my $format = $self->get_format;
    # If it's a tiff-file, write a png file, if we don't then browsers
    # can't read it
    if ($format && $format =~ /tiff?$/)
    {
        $gm->Write('png:'.$fname);
    }
    else
    {
        $gm->Write($fname);
    }
    return $fname;
}

# Summary: Remove all files associated with this file and delete the database entry
# Usage: object->removeAndDelete($c);
sub removeAndDelete
{
    my $self = shift;
    my $c = shift;
    foreach my $f (glob($self->get_path($c).'-*'))
    {
        unlink($f);
    }
    unlink($self->get_path($c));
    return $self->delete();
}

# Summary: Sanitize both height and width, returning smaller if needed
# Usage: (height,width) = file->_fulLSizeSanitize($c,height,width);
sub _fullSizeSanitize
{
    my($self,$c,$height,$width) = @_;
    $height = $self->_sizeSanitize($c,$height);
    $width = $self->_sizeSanitize($c,undef,$width);
    return($height,$width);
}

# Summary: Sanitize a height or width, returning smaller if needed
# Usage: height = file->_sizeSanitize($c,height);
# Usage: width  = file->_sizeSanitize($c,undef,width);
sub _sizeSanitize
{
    my($self,$c,$height,$width) = @_;
    my $mode;
    my $value;
    if(defined $height)
    {
        $mode = 'height';
        $value = $height;
    }
    elsif(defined $width)
    {
        $mode = 'width';
        $value = $width;
    }
    else
    {
        return;
    }
    if (not $self->height or not $self->width)
    {
        $self->detectImageFields($c);
    }
    my $orig = $self->get_column($mode);

    if(
        (not defined $orig) or
        ($orig >= $value)
    )
    {
        return $value;
    }
    else
    {
        return $orig;
    }
}

# Summary: Check if a path exists, returning the path if it does, or
#   undef (plus logging an error) if it doesn't
# Usage: path = file->_path_or_undef($c,$path);
#
# This is for internal use.
sub _path_or_undef
{
    my($self,$c,$path) = @_;
    if (-e $path)
    {
        return $path;
    }
    else
    {
		$c->log->error('get_resized(): WARNING: '.$path.': does not exist for file ID '.$self->file_id.'! Bailing out');
        return undef;
    }
}

# ----------------------
# VIDEO SPECIFIC METHODS
# ----------------------

# Summary: Get the path to the FLV
# Usage: path = file->get_flv_path($c);
sub get_flv_path
{
    my($self,$c) = @_;
    my $path = $self->get_path($c);
    $path .= '.flv';
    return $path;
}

# Summary: Get the path to the FLV preview image
# Usage: path = file->get_flv_preview_path($c);
sub get_flv_preview_path
{
    my($self,$c) = @_;
    my $path = $self->get_path($c);
    $path .= '.flvpreview.jpg';
    return $path;
}

# Summary: Check if a video file has an flv
# Usage: bool = file->has_flv($c);
sub has_flv
{
    my($self,$c) = @_;
    if (-e $self->get_flv_path($c))
    {
        return 1;
    }
    return;
}

# Summary: Get the path to the flvConvert info file
# Usage: path = file->get_flv_tmpFile($c);
sub get_flv_tmpFile
{
    my($self,$c) = @_;
    my $tmpFile = $c->config->{LIXUZ}->{temp_path}.'/lixuz_flvProgress-file_id-'.$self->file_id.'.log';
    return $tmpFile;
}

# Summary: Get the current flv conversion status
# Usage: status = file->get_flv_tmpFile($c);
#   The status is returned as a string. One of:
#       SUCCESS    - FLV conversion successfully completed
#       FAILURE    - FLV conversion failed
#       INPROGRESS - FLV conversion still running
#   On FAILURE a sysadmin may inspect flv_tmpFile to see what
#   went wrong.
sub flv_status
{
    my($self,$c) = @_;
    my $tempFile = $self->get_flv_tmpFile($c);
    if ($self->has_flv($c) and not -e $tempFile)
    {
        return 'SUCCESS';
    }
    elsif(not -e $tempFile)
    {
        return 'FAILURE';
    }
    else
    {
        open(my $f,'<',$tempFile);
        my $l = <$f>;
        close($f);
        chomp($l);
        if ($l =~ /INPROGRESS/)
        {
            return 'INPROGRESS';
        }
        else
        {
            return 'FAILURE';
        }
    }
}

# Summary: Create a FLV for this video file
# Usage: file->create_FLV($c);
#   This will fork off the Lixuz FLV converter (tools/flvConverter), which
#   will convert the file to FLV. Use flv_status() to find out when it has completed
#   (or if you don't care about completion success/errors, use has_flv() to check
#   if the file has an flv).
sub create_FLV
{
    my($self,$c) = @_;
    if ($self->has_flv($c))
    {
        $c->log->warn('create_FLV() called on file '.$self->file_id.' that already has an flv, ignoring request');
        return;
    }
    my $r = system($LIXUZ::PATH.'/tools/flvConverter',$self->get_path($c),$self->get_flv_path($c),$self->get_flv_tmpFile($c));
    # XXX: It for some reason returns -1, even though the thing got executed just fine. Assume all is well if it does.
    if ($r == -1)
    {
        $r = 0;
    }
    else
    {
        $r = sprintf('%d',$r >> 8);
    }
    if ($r != 0)
    {
        $c->log->warn('Running: "'.$LIXUZ::PATH.'/tools/flvConverter" "'.$self->get_path($c).'" "'.$self->get_flv_path($c).'" "'.$self->get_flv_tmpFile($c).'" for file '.$self->file_id.' failed - returned '.$r);
    }
    return;
}

# Summary: Get the file size for the flv file associated with this file object (if any)
# Usage: size_string = file->flv_size($c);
sub flv_size
{
    my $self = shift;
    my $c = shift or die;

    return('(unknown)') if not $self->has_flv($c);

    return $self->_sizeStringForPath($c,$self->get_flv_path($c));
}

# ---
# Internal methods
# ---

# Summary: Get the size string for a path, or for the original file
# Usage: string = file->_sizeStringForPath($c,$path?);
# if $path is undef then it provides the size for this file
sub _sizeStringForPath
{
    my $self = shift;
    my $c = shift or die;
    my $path = shift;
    my $bytes;

    if ($path)
    {
        if ( -e $path )
        {
            $bytes = -s $path;
        }
    }
    else
    {
        $bytes = $self->size;
        if(not defined $bytes)
        {
            if (-e $self->get_path($c))
            {
                $bytes = -s $self->get_path($c);
                $self->set_column('size' => $bytes);
                $self->update();
            }
        }
    }
    if(not defined $bytes or not length $bytes)
    {
        return '(unknown)';
    }

    my($s, $t) = fsize($bytes);
    return $s.' '.$t;
}

# Summary: Return the height+width of this image along with a string
# Usage: (string,height,width) = self->_returnStringAndAspect(wantarray,STRING,HEIGHT?,WIDTH?);
sub _returnStringAndAspect
{
    my($self,$wantArray,$string,$height,$width) = @_;

    if (!$wantArray)
    {
        return $string;
    }

    if (!defined($height) && !defined($width))
    {
        return ($string,$self->height,$self->width);
    }
    $height //= get_new_aspect($self->width,$self->height,$width);
    $width  //= get_new_aspect($self->width,$self->height,undef,$height);
    return ($string,$height,$width);
}

# ---
# Deprecated methods
# ---

sub get_thumbnail
{
    my $self = shift;
    my($c) = @_;
    $c->log->debug('Deprecated method "get_thumbnail" on LzFile called. Use get_url_aspect instead. This will be removed in a later version.');
    return $self->get_url_aspect(@_);
}

1;


# You can replace this text with custom content, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
