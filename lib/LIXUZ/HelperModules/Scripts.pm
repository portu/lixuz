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

package LIXUZ::HelperModules::Scripts;
use strict;
use warnings;
use Exporter qw(import);
use Config::Any;
use FindBin;
use Cwd qw(realpath);
use LIXUZ::Schema;
use 5.014;
our @EXPORT_OK = qw(fakeC getConfig getLixuzRoot mockC getDBIC);

our $root;
my $conf;

sub fakeC
{
    my $c = bless({
            stack => [
                bless(
                    {
                        'namespace' => '',
                        name => 'auto',
                        class => 'LIXUZ::Controller::Root',
                        attributes => {
                            'Private' => [],
                        },
                        code => sub {},
                        reverse => 'auto',

                    },
                    'Catalyst::Action'),
            ],
            request => { arguments => {} },
        },'LIXUZ');
    return $c;
}

sub mockC
{
    return LIXUZ::Mocked->new;
}

sub getLixuzRoot
{
    if ($root)
    {
        return $root;
    }
    foreach (qw(./ ../ ../../ ../../../))
    {
        my $dir = $FindBin::RealBin.'/'.$_;
        if (-e $dir.'/lixuz.yml')
        {
            $root = realpath($dir);
            return $root;
        }
    }
    return;
}

sub getConfig
{
    my $root = getLixuzRoot();
    if(not $root)
    {
        die("Failed to locate Lixuz root: Can't load config");
    }
    if ($conf)
    {
        return $conf;
    }
    my $confFile = $root.'/lixuz.yml';
    my $confloader = Config::Any->load_files({ files => [ $confFile ], use_ext => 1 });
    $conf = $confloader->[0]->{$confFile};
    return $conf;
}

sub getDBIC
{
    my $config = getConfig();
	my $cinfo = $config->{'Model::LIXUZDB'}->{'connect_info'};
	$cinfo->{mysql_enable_utf8} = 1;
    return LIXUZ::Schema->connect( $cinfo );
}

# Mocking up classes:
package LIXUZ::HelperModules::Log
{
    use Moo;

    sub _log
    {
        my $type = shift;
        if (!@_)
        {
            warn($type."\n");
        }
        else
        {
            warn($type.': '.join(' ',@_)."\n");
        }
    }

    sub debug { shift->_log(@_) }
    sub warn { shift->_log(@_) }
    sub info { shift->_log(@_) }
}

package LIXUZ::MockCache
{
    use Moo;
    sub get {}
    sub set {}
    sub stash { {} }
}

package LIXUZ::Mocked
{
    use Moo;
    has 'cache' => (
        is => 'ro',
        default => sub { LIXUZ::MockCache->new }
    );
    has 'log' => (
        is => 'ro',
        default => sub { LIXUZ::HelperModules::Log->new }
    );
    has 'dbic' => (
        is => 'ro',
        default => sub { LIXUZ::HelperModules::Scripts::getDBIC() }
    );
    sub config
    {
        LIXUZ::HelperModules::Scripts::getConfig();
    }
    sub model
    {
        my $self = shift;
        my $fetch = shift;
        $fetch =~ s/^LIXUZDB:://;
        return $self->dbic->resultset($fetch);
    }
}

1;
