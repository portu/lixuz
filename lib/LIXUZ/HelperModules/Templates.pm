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

# LIXUZ::HelperModules::Templates

package LIXUZ::HelperModules::Templates;

use strict;
use warnings;
use Carp;
use Exporter qw(import);
use LIXUZ::HelperModules::Cache qw(get_ckey);
use File::Basename qw(basename);
use constant { 
    true => 1, 
    false => 0,
    CACHE_TIME => 86400
    };
our @EXPORT_OK = qw(smart_parse_templatefile cached_parse_templatefile parse_templatefile resolve_dependencies parse_template_dep get_parsed_template_info);

# Summary: Parse template metadata from a file
# Usage: my $hashref = parse_templatefile(/path/to/file);
# Returns undef if it fails to open the file
# Returns an empty hashref if no LIXUZ_INFOBLOCK is found, OR if it was never ENDed
# Returns a hash of key=value pairs if a LIXUZ_INFOBLOCK was found and parsed
sub parse_templatefile
{
    my $c = shift;
    my $file = shift;

    open(my $i, '<:encoding(UTF-8)', $file) or do
    {
        $c->log->error('ERROR: Failed to open "'.$file.'" for reading: '.$!);
        return undef;
    };

    my $started = false;
    my $ended = false;
    my %infoHash;

    while(<$i>)
    {
        next if /^#\s*#/;
        next if not s/^\s*(%\s*)?#\s*//g;
        if (not $started)
        {
            if (/^\s*BEGIN\s+LIXUZ_INFOBLOCK\s*$/)
            {
                $started = true;
            }
            next;
        }
        if (/^\s*END\s+LIXUZ_INFOBLOCK\s*$/)
        {
            $ended = true;
            last;
        }
        next if not /\=/;
        s/\s*$//g;
        my $o = $_;
        my $v = $_;
        # Retrieve the name
        $o =~ s/^([^=]+)=.*/$1/;
        # Remove any whitespace padding
        $o =~ s/\s+$//;
        # Uppercase the entire string
        $o = uc($o);
        # Drop the legacy TEMPLATE_ prefix
        $o =~ s/^TEMPLATE_//;

        # Retrieve the value
        $v =~ s/^[^=]+=//g;
        # Remove any whitespace prefix
        $v =~ s/^\s+//;

        if(not defined $o or not length($o) or $o =~ /=/)
        {
            next;
        }
        elsif(not defined $v or not length($v) or not $v =~ /\S/)
        {
            next;
        }
        if(defined $infoHash{$o})
        {
            $infoHash{$o} .= ' '. $v;
        }
        else
        {
            $infoHash{$o} = $v;
        }
    }
    close($i);

    if(not $ended)
    {
        $c->log->warn($file.': found no END LIXUZ_INFOBLOCK. Discarding data');
        return {};
    }
    else
    {
        return \%infoHash;
    }
}

# Summary: Wrapper around parse_templatefile that handles basic validation.
# Returns:
#   - undef on failure
#   - hashref with data on success
# It does not validate that the hashref contains required keys, only
# that it is not empty.
sub smart_parse_templatefile
{
    my $c = shift;
    my $file = shift;
    my $data = parse_templatefile($c,$file);
    if(not defined $data or not (keys %{$data}))
    {
        return undef;
    }
    return $data;
}

# Summary: Wrapper around smart_parse_templatefile that queries the cache
# Returns: (same as smart_parse_templatefile)
sub cached_parse_templatefile
{
    my($c,$file) = @_;
    my $ckey = get_ckey('template','parsedFile',$file);
    my $info;
    if ($info = $c->cache->get($ckey))
    {
        return $info;
    }
    my $data = smart_parse_templatefile($c,$file);
    if (defined $data)
    {
        $c->cache->set($ckey,$data,CACHE_TIME);
    }
    return $data;
}

# Summary: Resolve dependencies of a template and its dependencies
# Returns:
#   - On success if wantarray():
#       (\%uniqueidToFileMap, \@infoDepsList)
#       uniqueidToFileMap is a hashref containing uniqueid => file
#           keyvalue pairs
#       infoDepsList is the list of all info that needs to be stashed
#           for the template to render
#   - On success if not wantarray():
#       \%uniqueidToFileMap
#   - undef on failure
sub resolve_dependencies
{
    my($c,$template) = @_;
    if(not defined $template or not length $template)
    {
        $c->log->warn('resolve_dependencies() called without any template arg (or possibly with a missing $c) - giving up and returning failure');
        return undef;
    }
    my $ckey = get_ckey('template','deps',$template);

    if(my $cached = $c->cache->get($ckey))
    {
        if(wantarray())
        {
            return ($cached->{resolved},$cached->{finalInfoDeps});
        }
        else
        {
            return $cached->{resolved};
        }
    }

    # The deps which has been resolved
    my %resolved;
    my %infoDeps;
    my %pending;
    my %pendingDeps;
    my $hadWarn = 0;

    my @processing = ($template);
    if ($template =~ m{^/} && -e $template)
    {
        my $dbEntry = $c->model('LIXUZDB::LzTemplate')->search({uniqueid => $template});
        if (not $dbEntry->count)
        {
            my $info = cached_parse_templatefile($c,$template);
            my @inc = split(/\s+/,$info->{INCLUDES});
            push(@processing, @inc);
            if ($info->{NEEDSINFO})
            {
                foreach my $p (split(/\s+/,$info->{NEEDSINFO}))
                {
                    $infoDeps{$p} = 1;
                }
            }
        }
        else
        {
            $c->log->info($template.': found in databse as a uniqueid, but it looks like a path to me...');
        }
    }

    while(@processing)
    {
        my $curr = shift(@processing);
        
        my $dbEntry = $c->model('LIXUZDB::LzTemplate')->search({uniqueid => $curr});
        my $found = $dbEntry->count;
        if ($found == 0)
        {
            $c->log->warn('resolve_dependencies('.$template.'): Failed to locate any template with uniqueid '.$curr);
            if (-e $curr)
            {
                $c->log->warn($curr.': appears to be a file path');
                $c->log->warn('caller: '.join(' ',caller()));
            }
            if (%resolved)
            {
                $c->log->warn('Managed to resolve: '.join(' ',keys(%resolved)));
            }
            if (@processing)
            {
                $c->log->warn('Pending deps to process: '.join(' ',@processing));
            }
            if (%pending)
            {
                $c->log->warn('Templates pending resolving of their deps: '.join(' ',keys(%pending)));
            }
            return undef;
        }
        elsif($found > 1)
        {
            $c->log->warn('resolve_dependencies(): Found more than one template with uniqueid '.$curr.'. Database contains duplicates! I will pick the first one returned');
            $hadWarn = 1;
        }
        $dbEntry = $dbEntry->next;

        my $file = $dbEntry->path_to_template_file($c);
        if(not -e $file)
        {
            $c->log->warn('resolve_dependencies(): The file for the template with uniqueid '.$curr.' which should be located at '.$file.' does not exist! Unable to resolve dependencies, giving up.');
            return undef;
        }

        my $info = cached_parse_templatefile($c,$file);
        # No info, can't resolve dep, give up.
        if(not $info)
        {
            $c->log->warn('resolve_dependencies(): Failed to locate template information for file: '.$file.' ('.$curr.')');
            return undef;
        }

        if ($info->{NEEDSINFO})
        {
            foreach my $p (split(/\s+/,$info->{NEEDSINFO}))
            {
                $infoDeps{$p} = 1;
            }
        }

        if (not defined $info->{INCLUDES} or not length $info->{INCLUDES})
        {
            $resolved{$curr} = $dbEntry->file;
            next;
        }
        $pending{$curr} = $dbEntry->file;
        $pendingDeps{$curr} = [];
        my @inc = split(/\s+/,$info->{INCLUDES});
        push(@processing,@inc);
        push(@{$pendingDeps{curr}},@inc);
    }

    if(%pending)
    {
        foreach my $pendingSet (keys %pendingDeps)
        {
            foreach my $dep (@{$pendingDeps{$pendingSet}})
            {
                if ($resolved{$dep})
                {
                    delete($pendingDeps{$pendingSet});
                }
            }
            if(! $pendingDeps{$pendingSet} || ! @{$pendingDeps{$pendingSet}})
            {
                delete($pendingDeps{$pendingSet});
                $resolved{$pendingSet} = $pending{$pendingSet};
                delete($pending{$pendingSet});
            }
        }
        if (%pending)
        {
            $c->log->warn('resolve_dependencies(): Failed to resolve dependencies for: '.join(' ',keys(%pending)));
            return undef;
        }
    }
    if(not %resolved)
    {
        $c->log->warn('resolve_dependencies(): Ended without pending dependencies, but also with zero resolved dependencies. Counting it as a success, but the template might crash. This happened when processing the template '.$template);
        $hadWarn = 1;
    }
    my @finalInfoDeps;
    if(%infoDeps)
    {
        push(@finalInfoDeps,keys %infoDeps);
    }
    if(not $hadWarn)
    {
        my $cache = {
            resolved => \%resolved,
            finalInfoDeps => \@finalInfoDeps,
        };
        $c->cache->set($ckey,$cache,CACHE_TIME);
    }
    if(wantarray())
    {
        return (\%resolved,\@finalInfoDeps);
    }
    else
    {
        return \%resolved;
    }
}

# Summary: Parses a template dependency
# Returns: ($source,$action,\%settings)
sub parse_template_dep
{
    my $dep = shift;

    if(not defined $dep or not length $dep or not $dep =~ /\S/)
    {
        return;
    }

    my($source,$action,$settings);

    $source = $dep;
    $source =~ s/^([^_]+)_.*$/$1/;

    $action = $dep;
    $action =~ s/^[^_]+_([^_]+)_.*$/$1/;

    $settings = parse_squareParams($dep);

    return($source, $action, $settings);
}

# Summary: Parse parameters set in between brackets (ie. for NEEDSINFO and FILESPOT)
# Usage: my $hashref = parse_squareParams(str);
# Note: Expects a single set, not a space-separated string of sets.
sub parse_squareParams
{
    my $string = shift;

    $string =~ s/^[^\[]*\[([^\]]+)\].*/$1/;
    my %settings;

    foreach my $s (split(/,+/,$string))
    {
        my ($k,$v) = ($s,$s);

        $k =~ s/^([^=]+)=.*/$1/g;
        $v =~ s/^[^=]+=//g;
        $v =~ s/([^%])%20/$1 /g;
        $settings{$k} = $v;
    }
    return \%settings;
}

# Summary: Retrieve parsed template information
# Returns: hashref, in the form:
# {
#   template_info => (data from cached_parse_templatefile),
#   template_deps => raw dependencies,
#   includes_map => { hashref, map like returned from resolve_dependencies() },
#   template_deps_parsed => parsed dependencies,
#   spots_parsed => parsed spot list,
#   layout => [ arrayref, each entry specifies the number of articles on that line ],
#   layout_spots => int, total number of layout spots available,
# }
sub get_parsed_template_info
{
    # TODO: More error handling
    my($c,$template) = @_;
    my $saveCache = true;
    my $templateFile;
    if(not -e $template)
    {
        my $tfckey = get_ckey('template','file',$template);
        if(my $f = $c->cache->get($tfckey))
        {
            $templateFile = $f;
        }
        else
        {
            my $tObj = $c->model('LIXUZDB::LzTemplate')->search({ uniqueid => $template});
            if ($tObj && $tObj->count)
            {
                $templateFile = $tObj->next->path_to_template_file($c);
                $c->cache->set($tfckey,$template,CACHE_TIME);
            }
            else
            {
                $c->log->error('get_parsed_template_info(): Wanted to parse nonexisting template: '.$template);
                return;
            }
        }
    }
    else
    {
        $template =~ s{/+}{/}g;
        $templateFile = $template;
        $template = $c->model('LIXUZDB::LzTemplate')->find({ file => basename($template) });
        if(not $template)
        {
            $c->log->error('get_parsed_template_info() failed to resolve the path "'.$template.'" to a file in lz_template. Returning empty hash.');
            return {};
        }
        $template = $template->uniqueid;
    }
    my $info = {};
    my $ckey = 'templateInfoParsedList_'.$template;
    if ($info = $c->cache->get($ckey))
    {
        return $info;
    }

    my $parsed = cached_parse_templatefile($c,$templateFile);
    $info->{template_info} = $parsed;
    my ($idToFile, $deps) = resolve_dependencies($c, $template);
    if(not defined $idToFile)
    {
        $c->log->error('resolve_dependencies($c,'.$template.'); failed (returned undef). get_parsed_template_info() is confused but attempting to continue (refusing to cache the result though).');
        $c->log->info('The requested URL was: '.$c->req->uri->as_string);
        $saveCache = false;
    }
    $info->{template_deps} = $deps;
    $info->{includes_map} = $idToFile;
    my @spots;
    my $spotlist = $info->{template_info}->{FILESPOT};
    if ($spotlist)
    {
        foreach my $spot (split(/\[/,$spotlist))
        {
            next if not defined $spot or not length $spot;
            $spot = '['.$spot;
            push(@spots,parse_squareParams($spot));
        }
    }
    my $size = $info->{template_info}->{MEDIASETTINGS};
    if ($size)
    {
        $info->{mediasettings} = parse_squareParams($size);
    }
    $info->{spots_parsed} = \@spots;

    my $layout = $info->{template_info}->{LAYOUT};
    if ($layout)
    {
        $info->{layout} = [ split(/\|/,$layout) ];
        $info->{layout_spots} = 0;
        foreach my $e (@{ $info->{layout} })
        {
            $info->{layout_spots} += $e;
        }
    }

    my %needinfoParsed;
    foreach my $dep (@{$deps})
    {
        my ($source,$action,$params) = parse_template_dep($dep);
        next if not defined $source;

        if(not defined $needinfoParsed{$source})
        {
            $needinfoParsed{$source} = {};
        }
        if(not defined $needinfoParsed{$source}->{$action})
        {
            $needinfoParsed{$source}->{$action} = [];
        }
        push(@{$needinfoParsed{$source}->{$action}},$params);
    }

    if (%needinfoParsed)
    {
        $info->{template_deps_parsed} = \%needinfoParsed;
    }

    if ($saveCache)
    {
        $c->cache->set($ckey,$info,CACHE_TIME);
    }

    return $info;
}

1;
