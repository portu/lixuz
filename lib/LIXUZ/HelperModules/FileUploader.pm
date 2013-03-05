package LIXUZ::HelperModules::FileUploader;
use Moose;
use Graphics::Magick;
use constant {
    ERR_DIRNOTFOUND  => 1,
    ERR_WRITEFAILURE => 3,
    };
use 5.010;
use Exporter qw(import);
our @EXPORT_OK = qw(ERR_DIRNOTFOUND ERR_WRITEFAILURE);

has 'c' => (
    is => 'rw',
    weak_ref => 1,
    isa => 'Ref',
    required => 1,
    writer => '_set_c',
);

has 'standalone' => (
    is => 'ro',
    required => 0,
    default => 0,
);

has 'dbic' => (
    is => 'ro',
    required => 0,
);

sub model
{
	my $self = shift;
    my $model = shift;
    if ($self->dbic)
    {
        $model =~ s/^LIXUZDB:://;
        return $self->dbic->resultset($model);
    }
    return $self->c->model($model);
}

sub upload
{
    my($self,$fileName,$upload,$settings) = @_;
    my $fileObj = $self->model('LIXUZDB::LzFile');

    if ($fileName =~ /\\/)
    {
        my $newName = $fileName;
        $newName =~ s/^.*\\([^\\]+)$/$1/;
        if(length($newName) > 4 && $newName ne $fileName)
        {
            $fileName = $newName;
        }
    }

    my $owner = $settings->{owner};
    if (!$self->standalone)
    {
        $owner //= $self->c->user;
    }
    if (! defined $owner)
    {
        $owner = $self->model('LIXUZDB::LzUser')->first;
    }

    my $fileClass = $settings->{class_id} // $self->c->stash->{fileClassID};

    # Create the file
    $fileObj = $fileObj->create
    (
        {
            upload_time => \'now()',
            file_name => $fileName,
            owner => $owner->user_id,
            class_id => $fileClass,
        }
    );
    # Read in content from form and write the file
    if(not -d $self->c->config->{LIXUZ}->{file_path} or not -w $self->c->config->{LIXUZ}->{file_path})
    {
        return(undef,{ error => ERR_DIRNOTFOUND });
    }
    my $targetFile = $fileObj->get_path($self->c);
    if(ref($upload))
    {
        if(not ($upload->link_to($targetFile) || $upload->copy_to($targetFile)))
        {
            return(undef,{ error => ERR_WRITEFAILURE, system => $! });
        }
    }
    else
    {
        my $err;
        open(my $f,'>',$targetFile) or $err = $!;
        if ($err)
        {
            return(undef,{ error => ERR_WRITEFAILURE, system => $err, target => $targetFile });
        }
        print {$f} $upload;
        close($f);
    }
    if ($fileObj->is_image())
    {
        $self->populateImageFields($fileObj);
    }
    else
    {
        # TODO: Maybe this should just be a schema default,
        # or we should override the methods (better)
        $fileObj->set_column('height',0);
        $fileObj->set_column('width',0);
    }
    $fileObj->set_column('size', -s $fileObj->get_path($self->c));
    $fileObj->update();

    if (!$self->standalone)
    {
        $self->c->forward(qw/LIXUZ::Controller::Admin::Files::Edit handleFolders/, [ $fileObj ]);
    }

    # Ensure an identifier is generated
    $fileObj->identifier();

    if ($fileObj->is_video())
    {
        $fileObj->create_FLV($self->c);
    }
    if ($settings->{asyncUpload} && !$self->standalone)
    {
        $self->c->stash->{uploadedMeta} //= [];
        push(@{$self->c->stash->{uploadedMeta}}, $fileObj->serialize);
    }
	if (!$self->standalone)
	{
		$fileObj->set_tags_from_param($self->c->req->param('formTags'));
	}
    return($fileObj,undef);
}

sub populateImageFields
{
    my ($self, $fileObj) = @_;
    my $gm = Graphics::Magick->new;
    my ($width, $height, $size, $format) = $gm->Ping($fileObj->get_path($self->c));
    $fileObj->set_column('height',$height);
    $fileObj->set_column('width',$width);
    if (not $format)
    {
        $format = $fileObj;
        $format =~ s/^.*\.([^\.]+)$/$1/;
        if(length($format) > 4)
        {
            return;
        }
    }
    $format =~ tr/[A-Z]/[a-z]/;
    $fileObj->set_column('format',$format);
    # Explicitly destroy Graphics::Magick
    undef $gm;
}

1;
