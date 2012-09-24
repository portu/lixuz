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
use Test::MockClass;
use LIXUZ::Schema;
our @EXPORT_OK = qw(fakeC getConfig getLixuzRoot mockC getDBIC);

my ($root,$conf);

sub fakeC
{
    eval
    {
        package LIXUZ::HelperModules::Log;
        sub _out { shift; warn(join(' ',@_)."\n") };
        sub error { my $s = shift or return; return $s->_out(@_) };
        sub debug { my $s = shift or return; return $s->_out(@_) };
        sub info { my $s = shift or return; return $s->_out(@_) };
        sub warn { my $s = shift or return; return $s->_out(@_) };
        sub _log { my $s = shift or return; return $s->_out(@_) };
    };
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
    my $mockLog = Test::MockClass->new('LIXUZ::HelperModules::Log');
    foreach my $type (qw(debug info warn _log))
    {
        $mockLog->addMethod($type, sub
            {
                warn($type.': '.join(' ',@_)."\n");
            });
    }

    my $logger = $mockLog->create;

    my $mockClass = Test::MockClass->new('LIXUZ');
    $mockClass->defaultConstructor();
    $mockClass->addMethod('config',sub { getConfig() });
    $mockClass->addMethod('log', sub { return $logger });
    return $mockClass->create;
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
    return undef;
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
    return LIXUZ::Schema->connect( $config->{'Model::LIXUZDB'}->{connect_info} );
}

1;
