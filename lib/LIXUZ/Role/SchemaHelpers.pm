package LIXUZ::Role::SchemaHelpers;
use Moose::Role;

sub model_resultset
{
    my $self = shift;
    return $self->result_source->schema->resultset(@_);
}

1;
