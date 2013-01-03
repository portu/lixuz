# LIXUZ content management system
# Copyright (C) Utrop A/S Portu media & Communications 2012
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
#
# --
#
# This is a class that can parse a DOM tree and replace images with
# a rendered template, allowing placement of images to happen within
# the RTE, but to have said images be formatted in a way that fits in
# with the templates.
package LIXUZ::HelperModules::HTMLRenderer;
use Moose;
use Mojo::DOM;
use Hash::Merge qw(merge);
use LIXUZ::HelperModules::Cache qw(get_ckey CT_DEFAULT CT_24H CT_1H);

has 'c' => (
    is => 'ro',
    required => 1,
);

has 'template' => (
    is => 'rw',
    required => 0,
    builder => '_detectTemplate',
    lazy => 1,
);

has 'processString' => (
    is => 'rw',
    required => 0,
    builder => '_buildString',
    lazy => 1,
);

has 'article_id' => (
    is => 'rw',
    required => 0,
    isa => 'Int',
);

has 'article_rev' => (
    is => 'rw',
    required => 0,
    isa => 'Int',
);

has 'noFloat' => (
    is => 'rw',
    required => 0,
    isa => 'Int',
    writer => '_noFloat',
);

has 'maxHeight' => (
    is => 'rw',
    required => 0,
    isa => 'Int',
    writer => '_maxHeight',
);

has 'maxWidth' => (
    is => 'rw',
    required => 0,
    isa => 'Int',
    default => 450,
    writer => '_maxWidth',
);

has '_initialized' => (
    is => 'rw',
);

# Loop through all images in the DOM and render each of them to our
# media template
sub render
{
    my($self) = @_;

    my $body     = Mojo::DOM->new( $self->processString );

    foreach my $img ($body->find('img')->each)
    {
        my $result = $self->renderImg($img);
        $img->replace($result);
    }

    return $body->to_xml;
}

# Render an image
sub renderImg
{
    my($self,$img) = @_;

    # Fetch+parse the src of the original image in order to find the file id,
    # so that we can retrieve the URL directly from LzFile.
    my $fileIdentifier = $img->attrs('src');
    if (! ($fileIdentifier =~ s{^.*/files/get/([^\?/]+).*$}{$1}))
    {
        # If we can't figure out what the ID is - give up
        $self->c->log->warn('HTMLRenderer: Failed to extract file identifier for entry in body with src="'.$fileIdentifier.'" - skipping');
        return $img->to_xml;
    }

    # Locate the file object
    my $image = $self->c->model('LIXUZDB::LzFile')->find({
            identifier => $fileIdentifier,
        });

    # Try to fetch by file_id if fetching by identifier failed
    if (! defined($image) && $fileIdentifier =~ /^\d+$/)
    {
        $image = $self->c->model('LIXUZDB::LzFile')->find({
                file_id => $fileIdentifier,
            });
    }
    # If we still can't find a file, give up.
    if (!defined($image))
    {
        $self->c->log->warn('HTMLRenderer: Failed to locate file with the identifier '.$fileIdentifier.' - skipping');
        return $img->to_xml;
    }

    # Ignore non-images (ie. in the case of videos, which may also have <img>
    # tags in the body)
    if (! $image->is_image)
    {
        return;
    }

    my $attrs       = $img->attrs;
    my $size = $self->_metaSizeExtractor($img,$img->attrs('src'));

    if ($self->maxWidth && $size->{width} && $size->{width} >= $self->maxWidth)
    {
        $size->{width} = $self->maxWidth;
    }
    if ($self->maxHeight && $size->{height} && $size->{height} >= $self->maxHeight)
    {
        $size->{height} = $self->maxHeight;
    }
    $size->{height} ||= $self->maxHeight;
    $size->{width}  ||= $self->maxWidth;

    my($src,$height,$width) = $image->get_url_aspect($self->c,$size->{height},$size->{width});

    delete($attrs->{height});
    delete($attrs->{width});

    # Fetch a DOM object representing the media template
    my $template    = Mojo::DOM->new( $self->templateString($image, $height,$width, $attrs) );

    # Find the tag that we will insert our image into
    my $placeholder = $template->find('.lzImagePlaceholder')->first;

    # If there's no placeholder, assume that it was done on purpose and
    # return an empty string.
    if (!defined $placeholder)
    {
        return '';
    }

    $attrs       = merge($placeholder->attrs, $attrs);
    # Set src to the generated url, instead of the one that's already there
    $attrs->{src} = $src;
    # Clean up the class tag
    $attrs->{class} =~ s/lzImagePlaceholder//;
    $attrs->{class} =~ s/^\s+//;
    $attrs->{class} =~ s/\s+$//;
    
    # Fetch the original image style attribute
    my $style = $self->_styleAttrData($img->attrs('style'), 1);
    # Set the generated width/height
    $style->{width} = $width.'px';
    $style->{height} = $height.'px';
    if ($style->{float} && $self->noFloat)
    {
        delete($style->{float});
    }
    # Prepare the style in attrs for insertion of new rules
    if ($attrs->{style})
    {
        if ($attrs->{style} eq $img->attrs('style'))
        {
            $attrs->{style} = '';
        }
        else
        {
            $attrs->{style} .= ';';
        }
    }
    # Append to the style attribute
    if ($style)
    {
        while(my($key,$value) = each %{$style})
        {
            $attrs->{style} .= $key.':'.$value.';';
        }
    }

    $placeholder->attrs( $attrs );

    # Finally, render the content
    return $template->to_xml;
}

# Allows mason to perform the template rendering (if possible) and then
# returns the string that we insert our image into.
sub templateString
{
    my($self, $img, $height, $width, $attrs) = @_;

    # This isn't much of a template, but the end result is that we will return
    # almost the same code as was provided to us by our caller, which needless
    # to say is preferred over dying.
    my $fallback = '<img src="#" class="lzImagePlaceholder" />';
    my $caption;
    my $float;

    my $templateFile;
    if ($self->_template)
    {
        $templateFile = $self->_template->file;
    }
    else
    {
        $self->c->log->warn('HTMLRenderer: Failed to detect a media template. Will return a basic dummy-template');
        return $fallback;
    }

    # Retrieve the caption
    if (defined $self->article_id)
    {
        $caption = $img->get_caption($self->c,$self->article_id,$self->article_rev);
    }

    # Retrieve the float value from the style="" attribute, if any
    if(my $style = $attrs->{style})
    {
        $style = $self->_styleAttrData($style);
        if ($style && $style->{float})
        {
            $float = $style->{float};
        }
        $float //= $attrs->{align};
    }
    if ($self->noFloat)
    {
        $float = '';
    }

    my $content = $self->c->view('Mason')->render($self->c, $templateFile, {
            image => $img,
            type => 'image',
            height => $height,
            width => $width,
            caption => $caption,
            float => $float
        });
    # If we don't do this, Catalyst::View::Mason will get very confused and
    # end up rendering our output to the user as well, which we don't want.
    #
    # XXX: This could be a bug in Catalyst::View::Mason - may need looking
    # into.
    $self->c->view('Mason')->{output} = q//;

    if(ref($content))
    {
        $self->c->log->error('HTMLRenderer: Exception during rendering of media template '.$templateFile.': '.$content->as_brief.' - will return basic dummy-template');
        return $fallback;
    }

    return $content;
}

# Retrieves the size defined in DOM metadata from an element.
sub _metaSizeExtractor
{
    my($self,$domEle) = @_;
    my $size = {
        height => $domEle->attrs('height'),
        width => $domEle->attrs('width')
    };

    if(my $style = $domEle->attrs('style'))
    {
        my $rules = $self->_styleAttrData($style);
        $size->{height} //= $rules->{height};
        $size->{width} //= $rules->{width};
    }

    if ((my $URL = $domEle->attrs('src')) && (!$size->{height} && !$size->{width}) )
    {
        # Fall back to fetching from the url
        my $height = $URL;
        my $width  = $URL;
        if ($height =~ s/.*height=(\d+).*/$1/)
        {
            $size->{height} = $height;
        }
        if ($width =~ s/.*width=(\d+).*/$1/)
        {
            $size->{width} = $width;
        }
    }

    # Strip postfix
    if ($size->{height})
    {
        $size->{height} =~ s/\D+$//;
    }
    if ($size->{width})
    {
        $size->{width} =~ s/\D+$//;
    }
    
    return $size;
}

# A stupid style="" attribute parser.
# This handles no edge cases, and nothing at all fancy. It will
# parse basic rules, and remove quoting if needed (and the $preserveQuotes
# parameter wasn't supplied) but that's it.
sub _styleAttrData
{
    my($self,$attr,$preserveQuotes) = @_;

    my $rules;

    foreach my $rule (split(/;/,$attr))
    {
        my($key,$value) = split(/\s*:\s*/,$rule);
        next if not defined $value;
        $key =~ s/^\s+//;
        if (!$preserveQuotes)
        {
            $value =~ s/^["'](.+)["']$/$1/g;
        }
        $rules->{$key} = $value;
    }

    return $rules;
}

# Performs our template detection, will return the first media template it
# can find.
sub _detectTemplate
{
    my($self) = @_;

    my $template = $self->c->model('LIXUZDB::LzTemplate')->search({ type => 'media' });
    return $template->first;
}

sub _template
{
    my $self = shift;

    my $ret = $self->template(@_);
    if (!@_)
    {
        if(ref($ret) eq '')
        {
            my $template = $self->c->model('LIXUZDB::LzTemplate')->find({ uniqueid => $ret });
            $self->template($template);
            $ret = $template;
        }
    }
    return $ret;
}

sub _initializeMetadata
{
    my($self) = @_;
    if ($self->_initialized)
    {
        return;
    }
    my $template = $self->_template;
    if ($template)
    {
        my $info = $template->get_info($self->c);
        if ($info->{mediasettings})
        {
            $self->_maxHeight($info->{mediasettings}->{maxHeight});
            $self->_maxWidth($info->{mediasettings}->{maxWidth});
            if ($info->{mediasettings}->{noFloat})
            {
                $self->_noFloat(1);
            }
        }
    }
    $self->_initialized(1);
    return;
}

before 'maxWidth' => sub
{
    my $self = shift;
    $self->_initializeMetadata;
};
before 'maxHeight' => sub
{
    my $self = shift;
    $self->_initializeMetadata;
};

__PACKAGE__->meta->make_immutable;
1;
