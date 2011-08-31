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

package LIXUZ::Controller::Admin::Settings::Admin::Info;
use Moose;
BEGIN { extends 'Catalyst::Controller' };
use IO::Socket::INET;

sub memcached_flush : Path('/admin/settings/admin/info/memcached/flush')
{
    my($self,$c) = @_;
    foreach my $host (@{$c->config->{'Plugin::Cache'}->{backend}->{servers}})
    {
        my $sock = IO::Socket::INET->new(
            PeerAddr => $host,
            Type => SOCK_STREAM,
            Timeout => 1,
        );
        print {$sock} "flush_all\n";
        my $r = <$sock>;
        chomp($r);
        if(not $r =~ /^\s*OK\s*$/)
        {
            $c->log->debug('flush_all failed for host '.$host.': '.$r);
        }
        close($sock);
    }
    $c->stash->{content} = $c->stash->{i18n}->get('Memcached has been flushed.');
    $c->stash->{template} = 'adm/core/dummy.html';
}

1;
