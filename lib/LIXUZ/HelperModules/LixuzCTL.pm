package LIXUZ::HelperModules::LixuzCTL;
use strict;
use warnings;
use Method::Signatures;
use LIXUZ::HelperModules::Paths qw(lixuzFSPathTo lixuzFSRoot);
use Exporter qw(import);
our @EXPORT = qw(lixuzctl lixuzctlCommand);

func lixuzctl(@ARGS)
{
    my $success = 0;
    my $r = system(lixuzctlCommand(@ARGS));
    if ($r == 0)
    {
        $success = 0;
    }
    if(wantarray())
    {
        return($success,$r);
    }
    return $success;
}

func lixuzctlCommand (@ARGS)
{
    my $lixuzCTLPath = lixuzFSPathTo('/tools/lixuzctl');
    if (!-e $lixuzCTLPath)
    {
        die($lixuzCTLPath.': does not exist'."\n");
    }
    elsif (!-x $lixuzCTLPath)
    {
        die($lixuzCTLPath.': is not executable'."\n");
    }
    my @command = (lixuzFSPathTo('/tools/lixuzctl'), qw(--quiet --web-chained), '--lixuzdir',lixuzFSRoot());
    push(@command,@ARGS);
    return @command;
}

1;
__END__

=pod

=head1 DESCRIPTION

This module provides access to run lixuzctl() commands from inside the Lixuz web
application.

Note: if the /tools/lixuzctl file is missing or has wrong permissions when
either of the functions within this module is called the function will die with
an error message.

=head1 SYNOPSIS

    use LIXUZ::HelperModules::LixuzCTL;
    lixuzctl(..)

=head1 FUNCTIONS

The following functions are available from this module and are exported by default.

=over

=item lixuzctl(arg1,arg2,..)

This provides access to running lixuzctl commands within Lixuz. It takes any
parameters that lixuzctl normally takes. It will then execute lixuzctl with
said parameters and return the status from lixuzctl. In scalar context it
returns a boolean value, where true means lixuzctl completed successfully and
false means lixuzctl failed. In list context it will reeturn
($success,$returnValue) where $success is the previously mentioned boolean, and
$returnValue is the raw return value as returned from the system() call.

=item lixuzctlCommand(arg1,arg2,..)

This is similar to lixuzctl(), but instead of executing lixuzctl it will instead
return an array containing the parameters that would have been provided to system()
by lixuzctl() in order to run lixuzctl with the provided parameters.

=back
