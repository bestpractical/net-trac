package Net::Trac::TicketPropChange;
use Moose;

has property => (isa => 'Str', is => 'rw');
has old_value => (isa => 'Str', is => 'rw');
has new_value => (isa => 'Str', is => 'rw');

1;
