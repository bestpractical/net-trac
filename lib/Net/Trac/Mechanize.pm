package Net::Trac::Mechanize;
use Moose;
extends 'WWW::Mechanize';

has trac_user     => ( isa => 'Str', is => 'rw' );
has trac_password => ( isa => 'Str', is => 'rw' );

sub get_basic_credentials {
    my $self = shift;
    return ( $self->trac_user => $self->trac_password );
}

# This is commented because it breaks the class, causing it to
# seemingly not follow HTTP redirects.
#__PACKAGE__->meta->make_immutable;
no Moose;

1;
