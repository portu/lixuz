package LIXUZ::HelperModules::Version;
use strict;
use warnings;
use Method::Signatures;
use Exporter qw(import);
use LIXUZ::HelperModules::Paths qw(lixuzFSPathTo);
our @EXPORT = qw(lixuzVersion);

my $version;

func lixuzVersion ($c = undef)
{
    no warnings;
    if(defined $LIXUZ::VERSION)
    {
        return $LIXUZ::VERSION;
    }
    use warnings;

    if(defined $version)
    {
        return $version;
    }

    if(defined $c && $c->can('stash') && $c->stash && $c->stash->{VERSION})
    {
        $version = $c->stash->{VERSION};
        return $version;
    }

    # HERE THERE BE DRAGONS!
    # This is about as ugly as it gets, but it will "mostly" work when you really
    # need a version number without loading LIXUZ.
    my $path = lixuzFSPathTo('lib/LIXUZ.pm');
    if (!-e $path)
    {
        return '(unknown)';
    }
    open(my $i,'<',$path);
    my($base,$gitrev);
    while(<$i>)
    {
        chomp;
        if (/^my \$VERSION_NO/)
        {
            $base = $_;
            $base =~ s/^\D+//;
            $base =~ s/\D+$//;
        }
        elsif(/^our \$GITREV/)
        {
            $gitrev = $_;
            $gitrev =~ s/^our\s+\S+\s*=\s*\S//;
            $gitrev =~ s/\S;.*//;
        }
    }
    close($i);
    if(defined $base && length($base))
    {
        $version = $base;
        if(defined $gitrev && length($gitrev))
        {
            $version .= ' ('.$gitrev.')';
        }
    }
    else
    {
        $version = '(unknown)';
    }
    return $version;
}

1;
