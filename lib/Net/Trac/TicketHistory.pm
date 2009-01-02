package Net::Trac::TicketHistory;

use Moose;
use Params::Validate qw(:all);
use Net::Trac::TicketHistoryEntry;

has connection => (
    isa => 'Net::Trac::Connection',
    is  => 'ro'
);

has ticket  => ( isa => 'Str',      is => 'rw' );
has entries => ( isa => 'ArrayRef', is => 'rw' );

sub load {
    my $self = shift;
    my ($id) = validate_pos( @_, { type => SCALAR } );

    $self->ticket( $id );

    my $feed = $self->connection->_fetch_feed( "/ticket/$id?format=rss" )
        or return;

    my @entries = $feed->entries;
    my @history;
    foreach my $entry (@entries) {
        my $e = Net::Trac::TicketHistoryEntry->new({ connection => $self->connection });
        $e->parse_feed_entry($entry);
        push @history, $e;
    }

    $self->entries( \@history );
    return 1;
}

=head1 NAME

Net::Trac::TicketHistory

=head1 DESCRIPTION

This class represents a trac ticket's history

=head1 METHODS

=head2 load ID

=head2 entries

=head2 ticket

Returns the ticket's id

=cut

__PACKAGE__->meta->make_immutable;
no Moose;

1;
