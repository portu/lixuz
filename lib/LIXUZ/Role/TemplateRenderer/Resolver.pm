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

package LIXUZ::Role::TemplateRenderer::Resolver;

use Moose::Role;

has 'c' => (
    isa => 'Object',
    weak_ref => 1,
    required => 1,
    is => 'ro'
    );

has 'renderer' => (
    isa => 'Object',
    required => 1,
    is => 'ro',
    );

sub log
{
    my($self,$msg) = @_;
    $self->c->log->warn($msg);
}

sub ckey
{
    my $self = shift;
    my $template = $self->renderer->_templateInfo;
    if ($template)
    {
        $template = $template->{template_info}->{UNIQUEID};
    }
    else
    {
        $template = 'default';
    }
    return join('-',@_,$template);
}

1;
