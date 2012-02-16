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

package LIXUZ::HelperModules::Indexer;
use 5.010;
use Moose;
use Carp qw(carp croak);
use File::Path qw(mkpath);
use LIXUZ::HelperModules::Cache qw(get_ckey);
use LIXUZ::HelperModules::Indexer::Result;
use LIXUZ::HelperModules::Calendar qw(datetime_from_SQL_to_unix);
use Text::FromAny;
use Try::Tiny;
use LIXUZ::HelperModules::HTMLFilter qw(filter_string);
use HTML::Entities qw(decode_entities);
use Encode qw(_utf8_on is_utf8 decode_utf8 encode_utf8);
use Data::Page;

# KinoSearch components
use KinoSearch1;
use KinoSearch1::InvIndexer;
use KinoSearch1::Analysis::PolyAnalyzer;
use KinoSearch1::Search::PhraseQuery;
use KinoSearch1::Searcher;
use KinoSearch1::Index::Term;
use KinoSearch1::QueryParser::QueryParser;
use KinoSearch1::Search::QueryFilter;

with 'LIXUZ::Role::IndexerData';

use constant {
    CT_15MINUTES => 900
    };

has 'config' => (
    isa => 'Maybe[HashRef]',
    is => 'rw',
    lazy => 1,
    builder => '_getConfig',
);
has 'searchPager' => (
    isa => 'Maybe[Object]',
    is => 'rw',
);
has 'searchType' => (
    isa => 'Str',
    is => 'rw',
    default => 'articles',
);
has 'vectorize' => (
    isa => 'Bool',
    default => 0,
    is => 'ro',
);
has 'storeBasicMeta' => (
    isa => 'Bool',
    default => 0,
    is => 'ro',
);
has '_indexer' => (
    isa => 'Maybe[Object]',
    is => 'rw',
    builder => '_getIndexer',
    lazy => 1,
);
has '_analyzer' => (
    isa => 'Maybe[Object]',
    is => 'rw',
    builder => '_getAnalyzer',
    lazy => 1
);
has '_searcher' => (
    isa => 'Maybe[Object]',
    is => 'rw',
    builder => '_getSearcher',
    lazy => 1
);
has '_indexFile' => (
    isa => 'Str',
    is => 'rw',
    builder => '_getIndexFile',
    lazy => 1,
);
has '_isDirty' => (
    isa => 'Bool',
    is => 'rw',
    default => 0,
);

sub BUILD
{
    my $self = shift;

    if ($self->mode !~ /^(internal|external)$/)
    {
        croak('Invalid mode: '.$self->mode);
    }
}

sub add
{
    my $self = shift;
    my $object = shift;

    if ($self->_isa('article',$object))
    {
        return $self->add_article($object);
    }
    elsif ($self->_isa('file',$object))
    {
        return $self->add_file($object);
    }
    else
    {
        croak('Invalid object supplied to add(): '.ref($object));
    }
}

sub add_autoreplace
{
    my $self = shift;
    my $object = shift;

    try
    {
        $self->delete($object);
    };

    return $self->add($object);
}

sub add_ifmissing
{
    my $self = shift;
    my $object = shift;
    if ($self->is_indexed($object))
    {
        return;
    }
    return $self->add($object);
}

sub add_article
{
    my $self = shift;
    my $object = shift;
    my $id = $self->indexerIdFor($object);
    my $doc = $self->_indexer->new_doc($id);
    foreach my $f (qw(title body lead author))
    {
        if (defined $object->get_column($f))
        {
            $self->_set_value_on_doc($doc,$f,
                $self->_cleanString($object->get_column($f))
            );
        }
    }
    $self->_set_value_on_doc($doc,'id',$id);
    $self->_set_value_on_doc($doc,'object_type','article');
    if ($self->mode eq 'internal')
    {
        $self->_set_value_on_doc($doc,'status_id',$object->status_id);
        if ($object->workflow && defined $object->workflow->assigned_to_user)
        {
            $self->_set_value_on_doc($doc,'assigned_to',$object->workflow->assigned_to_user);
        }
    }

    my $months_since_2k = $self->_getMonthsSince2k($object->get_column('publish_time'));
    if ($months_since_2k)
    {
        # XXX: Does not scale well beyond 2040
        my $date_modifier = ( $months_since_2k * 0.01 ) +1;
        $doc->set_boost($date_modifier);
    }
    $self->_set_value_on_doc($doc,'date', datetime_from_SQL_to_unix($object->get_column('publish_time')) );
    $self->_addDocToIndexer($doc);
    return 1;
}

sub add_file
{
    my $self = shift;
    my $object = shift;
    my $id = $self->indexerIdFor($object);
    my $doc = $self->_indexer->new_doc($id);
    foreach my $f (qw(file_name title caption file_id))
    {
        if (defined $object->get_column($f))
        {
            $self->_set_value_on_doc($doc,$f,$object->get_column($f));
        }
    }
    if (-e $object->get_path($self->c))
    {
        try
        {
            my $text = Text::FromAny->new(file => $object->get_path($self->c));
            if (defined $text->text)
            {
                $self->_set_value_on_doc($doc,'body',$text->text);
            }
        };
    }
    $self->_set_value_on_doc($doc,'id',$id);
    $self->_set_value_on_doc($doc,'object_type','file');
    my $ft = 'unknown';
    if ($object->is_image())
    {
        $ft = 'image';
    }
    elsif($object->is_video())
    {
        $ft = 'video';
    }
    $self->_set_value_on_doc($doc,'file_type',$ft);

    my $months_since_2k = $self->_getMonthsSince2k($object->get_column('upload_time'));
    if ($months_since_2k)
    {
        # XXX: Does not scale well beyond 2040
        my $date_modifier = ( $months_since_2k * 0.01 ) +1;
        $doc->set_boost($date_modifier);
    }
    $self->_addDocToIndexer($doc);
    return 1;
}

sub is_indexed
{
    my $self = shift;
    my $object = shift;
    my $id = $self->indexerIdFor($object);

    my $query = KinoSearch1::Search::PhraseQuery->new;
    $query->add_term( KinoSearch1::Index::Term->new( 'id', $id) );
    my $hits = $self->_searcher->search( query => $query );
    while(my $href = $hits->fetch_hit_hashref)
    {
        if ($href->{id} eq $id)
        {
            return 1;
        }
    }
    return 0;
}

# Usage: search(QUERY HASH, OPTIONS)
# QUERY HASH is a hashref in the following form:
# {
#   # REQUIRED:
#   query => 'Freetext search query'
#   # OPTIONAL:
#   # .. any additional settings will be a TermQuery on those fields
#   # with an occur=MUST rule.
#   #
#   # Keep in mind that certain object parameters also affect the results,
#   # such as 'searchType'
# }
#
# OPTIONS is an optional hashref in the following form:
# {
#   # If true the searcher will cache results in memcached
#   cache => BOOL, default false
#   # The number of returned results per page in the resultset
#   entriesPerPage => 10
# }
sub search
{
    my $self = shift;
    my $search = shift;
    my $options = shift;

    croak("No search query supplied") if not defined $search->{query};
    return $self->_getSearchResult($search,$options);
}

sub commit
{
    my $self = shift;
    my $optimize = shift;
    $optimize = $optimize ? 1 : 0;

    $self->_indexer->finish(
        optimize => $optimize
    );
    $self->_reInitSelf();
}

sub commit_ifneeded
{
    my $self = shift;
    if ($self->_isDirty)
    {
        return $self->commit(@_);
    }
    return;
}

sub _reInitSelf
{
    my $self = shift;

    $self->_isDirty(0);

    # (no need to re-init the analyzer)
    $self->_indexer( undef );
    $self->_searcher( undef );
    $self->_indexer( $self->_getIndexer );
    $self->_searcher( $self->_getSearcher );
}

sub delete
{
    my $self = shift;
    my $object = shift;
    my $id;
    if(ref($object))
    {
        $id = $self->indexerIdFor($object);
    }
    else
    {
        $id = $object;
    }

    if(not defined $id)
    {
        return;
    }
    $self->_indexer->delete_docs_by_term( KinoSearch1::Index::Term->new( 'id', $id) );
}

sub indexerIdFor
{
    my $self = shift;
    my $type = shift;
    my $id = shift;
    my $revision = shift;
    my $gen;
    if(ref($type) eq 'HASH')
    {
        my $info = $type;
        $type = $info->{type};
        $id = $info->{id};
        $revision = $info->{revision};
    }
    elsif(ref($type))
    {
        my $object = $type;
        if ($self->_isa('article',$object))
        {
            $gen = 'article_'.$object->article_id;
            if ($self->mode eq 'internal')
            {
                $gen .= '_'.$object->revision;
            }
        }
        elsif ($self->_isa('file',$object))
        {
            $gen = 'file_'.$object->file_id;
        }
        else
        {
            croak('Invalid object type ('.ref($object).')');
        }
        return $gen;
    }
    if(not defined $gen)
    {
        if ($type ne 'article' && $type ne 'file')
        {
            croak('Invalid type: '.$type);
        }
        $gen = $type.'_'.$id;
        if ($revision)
        {
            $gen .= '_'.$revision;
        }
    }
    return $gen;
}

sub _addDocToIndexer
{
    my $self = shift;
    my $doc = shift;
    $self->_indexer->add_doc($doc);
    $self->_isDirty(1);
}

sub _buildQuery
{
    my $self = shift;
    my $search = shift;

    if (not ref($search))
    {
        $search = {
            query => $search
        };
    }
    my $filter;
    my $booleanFilter = KinoSearch1::Search::BooleanQuery->new;
    my $freeText = $search->{query};

    delete($search->{query});

    ($search->{object_type} = $self->searchType) =~ s/s$//;;

    while(my($field,$searchV) = each(%{$search}))
    {
        my $term_query =  KinoSearch1::Search::TermQuery->new(
            term => KinoSearch1::Index::Term->new( $field,$searchV )
        );
        $booleanFilter->add_clause(query => $term_query, occur => 'MUST');
    }

    # Don't bother building a filter when we don't have any queries
    if (%{$search})
    {
        $filter = KinoSearch1::Search::QueryFilter->new( query => $booleanFilter);
    }

    my $fields = $self->_getFields;
    my $parser = KinoSearch1::QueryParser::QueryParser->new(
        analyzer => $self->_analyzer,
        fields => $fields,
    );
    my $query = $parser->parse($freeText);
    return($query,$filter);
}

sub _getHits
{
    my $self = shift;
    my $search = shift;

    my($query,$filter) = $self->_buildQuery($search);
    my $hits = $self->_searcher->search(
        query => $query,
        filter => $filter,
    );
    $hits->seek(0,999999);
    return $hits;
}

sub _getSearchResult
{
    my $self    = shift;
    my $search  = shift;
    my $options = shift;

    my ($start,$stop) = (0,10);

    my @result;

    if(not defined $options->{cache})
    {
        $options->{cache} = 1;
    }

    if (not $options->{cache})
    {
        @result = $self->_runSearchCacheable($search);
    }
    else
    {
        @result = $self->_runSearch($search);

    }
    if(not $options->{entriesPerPage})
    {
        $options->{entriesPerPage} = 10;
    }

    my $pager = Data::Page->new();
    $self->searchPager($pager);
    $pager->total_entries(scalar @result);
    $pager->entries_per_page($options->{entriesPerPage});
    $pager->current_page($options->{page});

    my $result = $self->_getResultObject(
        mode => $self->mode,
        c => $self->c,
        entriesPerPage => $options->{entriesPerPage},
        _result => \@result,
        _currentPage => $options->{page} // 1,
    );

    return $result;
}

sub _getResultObject
{
    shift;
    return LIXUZ::HelperModules::Indexer::Result->new(@_);
}

sub _runSearchCacheable
{
    my $self = shift;
    my $search = shift;
    my $ckey;
    if ($self->c)
    {
        my $query = $search->{query};
        $query =~ s/\s/_/g;
        $ckey = get_ckey('indexer','search',$query);
        my $result = $self->c->cache->get($ckey);
        if ($result && ref($result) eq 'ARRAY')
        {
            return @{$result};
        }
    }
    my @result = $self->_runSearch($search);
    if ($ckey)
    {
#        $self->c->cache->set($ckey, \@result);
    }
    return @result;
}

sub _runSearch
{
    my $self = shift;
    my $search = shift;
    my $hits = $self->_getHits($search);
    my @hitList;
    while(my $hit = $hits->fetch_hit_hashref)
    {
        push(@hitList,$hit);
    }
    return @hitList;
}

sub _getConfig
{
    my $self = shift;
	if(not defined $self->c->config->{LIXUZ}->{indexer})
	{
		die('indexer not configured in the conf file');
	}
    return $self->c->config->{LIXUZ}->{indexer};
}

sub _getIndexer
{
    my $self = shift;
    my $create = 0;
    if(not -e $self->_indexFile)
    {
        $create = 1;
        mkpath($self->_indexFile) or die("Failed to mkpath ".$self->_indexFile.": $!\n");
    }
    my $indexer = KinoSearch1::InvIndexer->new(
        invindex => $self->_indexFile,
        create   => $create,
        analyzer => $self->_analyzer,
    );
    $indexer->spec_field(
        name => 'title',
        boost => 7,
        indexed => 1,
        # XXX: These might need changing
        stored => $self->storeBasicMeta,
        vectorized => 0,
    );
    $indexer->spec_field(
        name => 'file_name',
        boost => 6,
        indexed => 1,
        # XXX: These might need changing
        stored => 0,
        vectorized => 0,
    );
    $indexer->spec_field(
        name => 'caption',
        boost => 6,
        indexed => 1,
        # XXX: These might need changing
        stored => $self->vectorize,
        vectorized => $self->vectorize,
    );
    $indexer->spec_field(
        name => 'lead',
        boost => 6,
        indexed => 1,
        # XXX: These might need changing
        stored => $self->vectorize,
        vectorized => $self->vectorize,
    );
    $indexer->spec_field(
        name => 'body',
        boost => 2,
        indexed => 1,
        # XXX: These might need changing
        stored => $self->vectorize,
        vectorized => $self->vectorize,
    );
    $indexer->spec_field(
        name => 'author',
        boost => 1,
        indexed => 1,
        # XXX: These might need changing
        stored => $self->storeBasicMeta,
        vectorized => 0,
    );
    $indexer->spec_field(
        name => 'id',
        boost => 0,
        indexed => 1,
        stored => 1,
        analyzed => 0,
        # XXX: This might need changing
        vectorized => 0,
    );
    $indexer->spec_field(
        name => 'object_type',
        boost => 0,
        indexed => 1,
        stored => 1,
        analyzed => 0,
        # XXX: This might need changing
        vectorized => 0,
    );
    $indexer->spec_field(
        name => 'file_type',
        boost => 0,
        indexed => 1,
        stored => 1,
        analyzed => 0,
        # XXX: This might need changing
        vectorized => 0,
    );

    $indexer->spec_field(
        name => 'date',
        boost => 0,
        indexed => 0,
        stored => 1,
        analyzed => 0,
        vectorized => 0
    );

    if ($self->mode eq 'internal')
    {
        $indexer->spec_field(
            name => 'file_id',
            boost => 0,
            indexed => 1,
            stored => 0,
            vectorized => 0,
        );
        $indexer->spec_field(
            name => 'assigned_to',
            boost => 0,
            indexed => 1,
            stored => 0,
            vectorized => 0,
        );
        $indexer->spec_field(
            name => 'status_id',
            boost => 0,
            indexed => 1,
            analyzed => 0,
            stored => 0,
            vectorized => 0,
        );
    }

    return $indexer;
}

sub _getAnalyzer
{
    my $self = shift;
    return KinoSearch1::Analysis::PolyAnalyzer->new( language => $self->config->{language} );
}

sub _getSearcher
{
    my $self = shift;
    if(not -e $self->_indexFile)
    {
        # Instantiate indexer so it gets created
        $self->_indexer;
    }
    return KinoSearch1::Searcher->new(
        invindex => $self->_indexFile,
        analyzer => $self->_analyzer,
    );
}

sub _getIndexFile
{
    my $self = shift;
    my $file = $self->config->{indexFiles}.'/'.$self->mode;
    return $file;
}

sub _getMonthsSince2k
{
    my $self = shift;
    my $dt = datetime_from_SQL_to_unix(shift);
    return if not $dt;
    my $year2k = 946681200;
    my $diff = $dt-$year2k;
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($diff);
    $year -= 71;
    $mon++;
    $mon += ($year*12);
    return $mon;
}

sub _isa
{
    my $self = shift;
    my $type = shift;
    my $object = shift;

    if ($type eq 'article')
    {
        foreach my $isa (qw(LIXUZ::Model::LIXUZDB::LzArticle LIXUZ::Schema::LzArticle))
        {
            if ($object->isa($isa))
            {
                return 1;
            }
        }
        if ($object->result_source->from eq 'lz_article')
        {
            return 1;
        }
        return;
    }
    elsif($type eq 'file')
    {
        foreach my $isa (qw(LIXUZ::Model::LIXUZDB::LzFile LIXUZ::Schema::LzFile))
        {
            if ($object->isa($isa))
            {
                return 1;
            }
        }
        if ($object->result_source->from eq 'lz_file')
        {
            return 1;
        }
        return;
    }
    return;
}

sub _getFields
{
    my $self = shift;
    my $for = shift;
    $for //= $self->searchType;

    my($stringFields, $specificFields) = (undef,[]);

    given($for)
    {
        when('articles')
        {
           $stringFields = [ qw/title body lead author/ ];
           $specificFields = [ qw/status_id assigned_to/ ];
        }

        when('files')
        {
            $stringFields = [ qw/file_name title caption body/ ];
            if ($self->mode eq 'internal')
            {
                push(@{$stringFields},'file_id');
            }
        }

        default
        {
            die("_getFields: Fatal: Unknown searchType \"$for\"");
        }
    }
    if(wantarray)
    {
        return ($stringFields, $specificFields);
    }
    else
    {
        return $stringFields;
    }
}

# Performs basic string cleaning to remove HTML from the indexed content
# and ensure we don't index metadata that would otherwise be removed by
# our HTML cleaner. It's only used for articles as Text::FromAny does
# something similar for the files automatically.
sub _cleanString
{
    my $self   = shift;
    my $string = shift;

    $string = filter_string($string);
    $string =~ s{<br\s*/?>}{\n}g;
    $string =~ s/<[^>]+>//g;
    $string = decode_utf8($string);
    $string = decode_entities($string);
    $string = encode_utf8($string);

    return $string;
}

sub _set_value_on_doc
{
	my $self  = shift;
	my $doc   = shift;
	my $key   = shift;
	my $value = shift;

	try
	{
		$doc->set_value($key,$value);
	}
	catch
	{
		if (/Can't call method "set_value"/)
		{
			warn("Indexer.pm: Failed to set $key on document: no such field\n");
		}
		else
		{
			die($_);
		}
	};
}

__PACKAGE__->meta->make_immutable;
1;
