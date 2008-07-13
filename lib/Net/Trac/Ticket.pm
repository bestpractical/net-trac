package Net::Trac::Ticket;
use Moose;
use Params::Validate qw(:all);
use Net::Trac::TicketHistory;

has connection => (
    isa => 'Net::Trac::Connection',
    is => 'ro'
    );

has state => (
    isa => 'HashRef',
    is => 'rw'
);

our @PROPS = qw(cc component description id keywords milestone
                owner priority reporter resolution status summary type);


for my $prop (@PROPS) {
    no strict 'refs';
    *{"Net::Trac::Ticket::".$prop} = sub { shift->state->{$prop}};
}


sub load {
    my $self = shift;
    my ($id) = validate_pos( @_, { type => SCALAR } );
    my $state = $self->connection->_fetch( "/ticket/" . $id . "?format=csv" );
    my $stateref = $self->connection->_csv_to_struct(data => \$state, key => 'id');
    $self->state($stateref->{$id});
}

sub history {
    my $self = shift;
    my $hist = Net::Trac::TicketHistory->new( {connection => $self->connection, ticket => $self->id });
    $hist->load;

}




#http://barnowl.mit.edu/ticket/36?format=tab
1;
