package LIXUZ::Controller::Admin::HelloWorld;
use Moose;
BEGIN { extends 'Catalyst::Controller' };

sub default : Public
{
    my($self,$c) = @_;
    $c->stash->{template} = 'adm/helloworld.html';
}

__PACKAGE__->meta->make_immutable;
1;
