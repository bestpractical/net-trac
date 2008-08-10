package Net::Trac::Ticket;
use Moose;
use Params::Validate qw(:all);
use Net::Trac::TicketHistory;

has connection => (
    isa => 'Net::Trac::Connection',
    is  => 'ro'
);

has state => (
    isa => 'HashRef',
    is  => 'rw'
);

has valid_milestones => ( isa => 'ArrayRef', is => 'rw' );
has valid_types      => ( isa => 'ArrayRef', is => 'rw' );
has valid_components => ( isa => 'ArrayRef', is => 'rw' );
has valid_priorities => ( isa => 'ArrayRef', is => 'rw' );

our @PROPS = qw(cc component description id keywords milestone
    owner priority reporter resolution status summary type);

for my $prop (@PROPS) {
    no strict 'refs';
    *{ "Net::Trac::Ticket::" . $prop } = sub { shift->state->{$prop} };
}

sub load {
    my $self = shift;
    my ($id) = validate_pos( @_, { type => SCALAR } );
    $self->connection->_fetch( "/ticket/" . $id . "?format=csv" );

    my $content = $self->connection->mech->content;

    my $stateref
        = $self->connection->_csv_to_struct( data => \$content, key => 'id' );
    return undef unless $stateref;
    $self->state( $stateref->{$id} );
    return $id;

}

sub _get_new_ticket_form {
    my $self = shift;
    $self->connection->ensure_logged_in;
    $self->connection->_fetch("/newticket");
    for my $form ( $self->connection->mech->forms() ) {
        return $form if $form->find_input('field_reporter');

    }

    return undef;
}

sub _fetch_new_ticket_metadata {
    my $self = shift;
    my $form = $self->_get_new_ticket_form;

    return undef unless $form;

    $self->valid_milestones(
        [ $form->find_input("field_milestone")->possible_values ] );
    $self->valid_types( [ $form->find_input("field_type")->possible_values ] );
    $self->valid_components(
        [ $form->find_input("field_component")->possible_values ] );
    $self->valid_priorities(
        [ $form->find_input("field_priority")->possible_values ] );

    my @inputs = $form->inputs;

    for my $in (@inputs) {
        my @values = $in->possible_values;
    }
    return 1;
}

sub create {
    my $self = shift;
    my %args = validate(
        @_,
        {   summary     => 0,
            reporter    => 0,
            description => 0,
            owner       => 0,
            type        => 0,
            priority    => 0,
            milestone   => 0,
            component   => 0,
            version     => 0,
            keywords    => 0,
            cc          => 0,
            status      => 0

        }
    );

    my $form = $self->_get_new_ticket_form();

    my %form = map { 'field_' . $_ => $args{$_} } keys %args;

    $self->connection->mech->submit_form(
        form_number => 2,                  # BRITTLE
        fields => { %form, submit => 1 }
    );

    my $reply = $self->connection->mech->response;
}

sub history {
    my $self = shift;
    my $hist = Net::Trac::TicketHistory->new(
        { connection => $self->connection, ticket => $self->id } );
    $hist->load;

}

#http://barnowl.mit.edu/ticket/36?format=tab
1;
