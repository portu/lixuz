package LIXUZ::HelperModules::Paths;
use strict;
use warnings;
use Method::Signatures;
use Exporter qw(import);
use File::Basename qw(dirname);
our @EXPORT = qw(lixuzFSPathTo lixuzFSRoot);

func lixuzFSPathTo($file)
{
    my $path = lixuzFSRoot();
    $path .= '/'.$file;
    return $path;
}

func lixuzFSRoot ()
{
    my $path;
    no warnings;
    $path = $LIXUZ::PATH;
    use warnings;
    if (!defined $path || !length($path))
    {
        # Use alternate detection
        my $selfPath = $INC{'LIXUZ/HelperModules/Paths.pm'};
        if (!defined $selfPath)
        {
            die('Error: Failed to locate Lixuz root (primary and fallback both failed)'."\n");
        }
        while(!-e $selfPath.'/lib/LIXUZ.pm' || !-e $selfPath.'/lixuz.yml')
        {
            $selfPath = dirname($selfPath);
            if ($selfPath eq '/')
            {
                die('Error: Fallback detection of Lixuz root failed'."\n");
            }
        }
        return $selfPath;
    }
    return $path;
}

1;
__END__

=pod

=head1 DESCRIPTION

This module provides an interface to retrieve the path to where Lixuz is installed
or to a file contained in some subdirectory of Lixuz. For the most part it is just
a small wrapper around $LIXUZ::PATH which is a bit more explicit and avoids
warnings.

=head1 SYNOPSIS

    use LIXUZ::HelperModules::Paths;
    my $lixuzctl = lixuzFSPathTo('/tools/lixuzctl')

=head1 FUNCTIONS

The following functions are available from this module and are exported by default.

=over

=item lixuzFSPathTo(path);

This returns the fully qualified path to a file contained beneath the Lixuz
root tree. This does not check if the provided file actually exists, so that
should be done by the caller. Paths provided must start with /.

=item lixuzFSRoot()

This provides the fully qualified path to the Lixuz root tree.

=back
