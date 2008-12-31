package Net::Trac::TicketSearch;
use Moose;
use Params::Validate qw(:all);

use Net::Trac::Ticket;

has connection => (
    isa => 'Net::Trac::Connection',
    is  => 'ro'
);

has limit   => ( isa => 'Int',      is => 'rw', default => sub { 500 } );
has results => ( isa => 'ArrayRef', is => 'rw', default => sub { [] } );

sub query {
    my $self  = shift;
    my %query = @_;

    # Build a URL from the fields we want and the query
    my $url = '/query?format=csv&order=id&max=' . $self->limit;
    $url .= '&' . join '&', map { "col=$_" } @Net::Trac::Ticket::PROPS;
    $url .= '&' . join '&', map { "$_=".$query{$_} } keys %query;

    my $content = $self->connection->_fetch( $url );
    my $data = $self->connection->_csv_to_struct( data => \$content, key => 'id', type => 'array' );

    my @tickets = ();
    for ( @{$data || []} ) {
        my $ticket = Net::Trac::Ticket->new( connection => $self->connection );
        my $id = $ticket->load_from_hashref( $_ );
        push @tickets, $ticket if $id;
    }

    $self->results([]);
    return $self->results( \@tickets );
}

1;

