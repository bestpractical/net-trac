package Net::Trac::TicketHistoryEntry;
use Moose;

has connection => (
    isa => 'Net::Trac::Connection',
    is => 'ro'
    );


sub parse_feed_entry {
    my $self = shift;
    my $xml_feed_entry = shift;
    warn YAML::Dump($xml_feed_entry);
    
    return 1;
}


1;
