package Net::Trac::TicketHistory;
use Net::Trac::TicketHistoryEntry;
use Moose;

has connection => (
    isa => 'Net::Trac::Connection',
    is  => 'ro'
);

has ticket => (
    isa => 'Str',
    is  => 'ro'
);

has entries => (
    isa => 'ArrayRef',
    is  => 'rw'
);

sub load {
    my $self = shift;
    my $feed = $self->connection->_fetch_feed(
        "/ticket/" . $self->ticket . "?format=rss" );

    my @entries = $feed->entries;
    my @history;
    foreach my $entry (@entries) {
        my $e = Net::Trac::TicketHistoryEntry->new(
            { connection => $self->connection } );
        $e->parse_feed_entry($entry);
        push @history, $e;
    }

    # http://barnowl.mit.edu/ticket/1?format=rss
    $self->entries( \@history );
    return 1;
}

=head1 NAME

Net::Trac::TicketHistory

=head1 DESCRIPTION

This class represents a trac ticket's history

=head1 METHODS

=head2 load

=head2 entries

=head2 ticket

Returns the ticket's id

=cut

1;
