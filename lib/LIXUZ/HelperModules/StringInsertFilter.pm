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

# This is a HTML filter class designed to insert arbitrary strings/html
# at automatically generated locations throughout an article/html string.
#
# Its usage is simple, but note that you really SHOULD cache the result to
# speed up subsequent requests.
#
# Usage:
# my $obj = LIXUZ::HelperModules::StringInsertFilter('[ ORIGINAL STRING ]',
#   \@ARRAYREF_OF_STRINGS_TO_INSERT, { OPTIONAL PARAMETERS });
# OPTIONAL PARAMETERS can be:
#   c => $c # to enable logging support
# my $newString = $obj->get_filtered;
package LIXUZ::HelperModules::StringInsertFilter;
use constant { true => 1, false => 0 };
use Moose;

has 'c' => (
    is => 'rw',
    weak_ref => 1,
    isa => 'Ref',
    required => 1,
    writer => '_set_c',
);

has 'string' => (
    is => 'rw',
    required => 1,
);

has 'insertStr' => (
    is => 'rw',
    required => 1,
    isa => 'Maybe[ArrayRef]',
);

sub log
{
    my ($self,$type,$message) = @_;
    my $c = $self->c;
    if(not $c)
    {
        return;
    }
    eval('$c->log->'.$type.'($message)');
}

sub get_filtered
{
    my $self = shift;
    my @split = $self->_splitString;
    my @slots;
    my @joinWith = @{$self->insertStr};
    if (@split <= @joinWith)
    {
        for(0..@split)
        {
            push(@slots,$_);
        }
    }
    elsif(scalar(@joinWith) == 1)
    {
        if(scalar(@split) % 2 == 0)
        {
            push(@slots, (int(scalar(@split)/ 2)+1));
        }
        else
        {
            push(@slots, (scalar(@split / 2)));
        }
    }
    else
    {
        if (int (scalar @split/2) >= @joinWith)
        {
            for(0..@split)
            {
                push(@slots,$_) if $_ % 2 == 0;
            }
        }
        else
        {
            for(0..@split)
            {
                push(@slots,$_);
            }
        }
    }
    
    foreach my $str (@joinWith)
    {
        next if not defined $str;
        my $slot = shift(@slots);
        if(defined $slot)
        {
            if(defined $split[$slot])
            {
                $split[$slot] = $str.$split[$slot];
            }
            else
            {
                $split[$slot] = $str;
            }
        }
        else
        {
            $split[-1] .= $str;
        }
    }

    my $final = join('',@split);
    return $final;
}

sub _splitString
{
    my($self) = @_;
    my $str = $self->string;
    chomp($str);

    if ($str =~ /<\s*pre\s*>/i)
    {
        $self->log('warn','String supplied to _splitString contained one or more <pre> blocks. Output might be garbled!');
    }

    my @tmpResult;
    # Split on >
    foreach my $p (split(/>/,$str))
    {
        $p .= '>';
        if (@tmpResult && $p =~ /^<.*>$/)
        {
            $tmpResult[-1] .= $p;
        }
        else
        {
            push(@tmpResult,$p);
        }
    }
    # Now, merge strings that does not denote paragraphs
    my $canMergeParent = false;

    my @result;
    foreach my $p (@tmpResult)
    {
        if ($p =~ /(br|p)\s*\/?>$/i)
        {
            $canMergeParent = false;
            push(@result,$p);
        }
        elsif($canMergeParent)
        {
            $result[-1] .= $p;
        }
        else
        {
            $canMergeParent = true;
            push(@result,$p);
        }
    }

    return @result;
}

__PACKAGE__->meta->make_immutable;
1;
