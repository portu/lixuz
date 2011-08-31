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

package LIXUZ::Role::IndexTriggers;
use Moose::Role;

requires 'insert';

has '__disableItrig' => (
    is => 'rw',
    isa => 'Bool',
    default => 0
);

after 'insert' => sub
{
    my $self = shift;
    $self->__iTrig_run();
};
after 'delete' => sub
{
    my $self = shift;
    $self->__iTrig_run('--delete');
};

sub __triggerIndex
{
    my $self = shift;
    $self->__disableItrig(0);
    return $self->__iTrig_run();
}

sub __iTrig_run
{
    my $obj = shift;
    my $id;
    if ($obj->__disableItrig)
    {
        return;
    }
    if ($obj->can('article_id'))
    {
        $id = $obj->article_id;
    }
    elsif($obj->can('file_id'))
    {
        $id = $obj->file_id;
    }
    else
    {
        warn('IndexTriggers used without trigger support');
        return;
    }
    my @cmd = ('perl',$LIXUZ::PATH.'/tools/lixuzIndexer.pl','--fork','--id',$id,'--type',$obj->result_source->from);
    if ($obj->can('revision'))
    {
        push(@cmd,'--revision',$obj->revision);
    }
    if (@_)
    {
        push(@cmd,@_);
    }
    system(@cmd);
}

1;
