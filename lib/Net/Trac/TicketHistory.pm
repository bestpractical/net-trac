package Net::Trac::TicketHistory;
use Moose;

has connection => (
    isa => 'Net::Trac::Connection',
    is => 'ro'
    );

has ticket => (
    isa => 'Str',
    is => 'ro'
);

sub load {
    my $self = shift;
    my $feed = $self->connection->_fetch_feed("/ticket/".$self->ticket."?format=rss");

    my @entries = $feed->entries;
    die "Found ".$#entries; 
    foreach my $entry (@entries) {
        my $e = Net::Trac::TicektHistory->new( { connection => $self->connection});
        $e->parse_feed_entry($entry);
    }
    # http://barnowl.mit.edu/ticket/1?format=rss
}



1;
