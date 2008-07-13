package Net::Trac::Connection;
use Moose;
use LWP::Simple;
    use XML::Feed;
use URI;
use Text::CSV_XS;
use IO::Scalar;
use Params::Validate;

has url => (
    isa => 'Str',
    is => 'ro'
    );
has user => (
    isa => 'Str',
    is => 'ro'
    );

has password => (
    isa => 'Str',
    is => 'ro'
);


sub _fetch {
    my $self = shift;
    my $query = shift;
    return LWP::Simple::get($self->url.$query); 

}

sub _fetch_feed {
    my   $self = shift;
    my  $query = shift;
    my $feed = XML::Feed->parse(URI->new($self->url .$query))
        or die XML::Feed->errstr;

    return $feed;
}
sub _csv_to_struct {
    my $self = shift;
    my %args = validate( @_, { data => 1, key => 1 } );
    my $csv  = Text::CSV_XS->new( { binary => 1 } );
    my $io   = IO::Scalar->new( $args{'data'} );
    $csv->column_names( $csv->getline($io) );
    my $hashref;
    while ( my $row = $csv->getline_hr($io) ) {
        $hashref->{ $row->{ $args{'key'} } } = $row;
    }
    return $hashref;
}


1;
