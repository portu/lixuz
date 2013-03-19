package LIXUZ::HelperModules::ProxiedResultSet;
use Moose;
use Carp qw(croak confess);

has 'orderedBuilder' => (
    isa => 'CodeRef',
    required => 1,
    is => 'ro',
    weak_ref => 0,
);

has 'normalBuilder' => (
    isa => 'CodeRef',
    required => 1,
    is => 'ro',
    weak_ref => 0,
);

has 'entriesPerPage'=> (
    isa => 'Int',
    required => 0,
    default => sub { 20 },
    is => 'rw',
);

has 'instanceOfPage' => (
    isa => 'Int',
    required => 0,
    default => sub { 1 },
    is => 'rw',
);

has 'ordered' => (
    required => 0,
    builder => '_autoOrdered',
    is => 'rw',
    lazy => 1,
);

has 'normal' => (
    required => 0,
    builder => '_autoNormal',
    is => 'rw',
    lazy => 1,
);

has 'current' => (
    required => 0,
    builder => '_autoCurrent',
    is => 'rw',
    lazy => 1,
);

sub _errOut
{
    my $why = shift;
    croak('Use of ->'.$why.' on ProxiedResultSet (ProxiedResultSets, generated by using LAYOUTs are read-only, due to being sorted in software)');
}

# -- BEGIN: Unsupported DBIC methods --

sub search
{
    _errOut('search');
}

sub search_rs
{
    _errOut('search_rs');
}

sub reset
{
    _errOut('reset');
}

sub first
{
    _errOut('first');
}

# -- END: Unsupported DBIC methods --

sub page
{
    my $self = shift;
    my $page = shift;
    $page //= 0;
    $self->instanceOfPage($page);
    # XXX: We may want to at some point create a new instance of ourselves
    # with this instanceOfPage value, to closer mimick the DBIC API. For now
    # this is "good enough(tm)".
    return $self;
}

sub pager
{
    my $self = shift;
    my $pager = Data::Page->new;
    my $total = 0;
    if ($self->normal)
    {
        $total += $self->normal;
    }
    if ($self->ordered)
    {
        $total += $self->ordered;
    }
    $pager->total_entries($total);
    $pager->entries_per_page($self->entriesPerPage);
    $pager->current_page($self->instanceOfPage);
    return $pager;
}

sub count
{
    my $self = shift;
    return $self->pager->total_entries;
}

sub next
{
    my $self = shift;
    return $self->current->next;
}

# Purpose: This method is primarily as an internal interface so that objects
# that return ProxiedResultSets can ensure that ordered objects are not
# included in the unordered list. It returns the article IDs of all objects
# that are in our ordered resultset.
sub getOrderedArticleIDs
{
    my $self = shift;
    my @IDs;
    if(my $ordered = $self->ordered)
    {
        $ordered = $ordered->get_cache;
        foreach my $entry (@{ $ordered })
        {
            push(@IDs, $entry->article_id);
        }
    }
    return @IDs;
}

sub _autoCurrent
{
    my $self = shift;
    if ( $self->ordered )
    {
        return $self->ordered;
    }
    return $self->normal;
}

sub _autoNormal
{
    my $self = shift;
    my $normal = $self->normalBuilder;
    return $self->_runCB($self->normalBuilder, 'normal');
}

sub _autoOrdered
{
    my $self = shift;
    return $self->_runCB($self->orderedBuilder, 'ordered');
}

sub _runCB
{
    my $self = shift;
    my $sub = shift;
    my $name = shift;
    if (!defined $sub)
    {
        confess('Callback for '.$name.' is undefined'."\n");
    }
    return $sub->($self);
}

1;
