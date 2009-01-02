package Net::Trac::Connection;
use Moose;

use XML::Feed;
use URI;
use Text::CSV_XS;
use IO::Scalar;
use Params::Validate;
use Net::Trac::Mechanize;

has url => (
    isa => 'Str',
    is  => 'ro'
);
has user => (
    isa => 'Str',
    is  => 'ro'
);

has password => (
    isa => 'Str',
    is  => 'ro'
);

has logged_in => (
    isa => 'Bool',
    is  => 'rw'
);

has mech => (
    isa     => 'Net::Trac::Mechanize',
    is      => 'ro',
    lazy    => 1,
    default => sub {
        my $self = shift;
        my $m    = Net::Trac::Mechanize->new();
        $m->cookie_jar( {} );
        $m->trac_user( $self->user );
        $m->trac_password( $self->password );
        return $m;

    }
);

sub _fetch {
    my $self    = shift;
    my $query   = shift;
    my $abs_url = $self->url . $query;
    $self->mech->get($abs_url);

    if ( $self->_warn_on_error($abs_url) ) { return }
    else { return $self->mech->content }
}

sub _warn_on_error {
    my $self = shift;
    my $url  = shift;
    my $die  = 0;

    if ( !$self->mech->response->is_success ) {
        warn "Server threw an error "
             . $self->mech->response->status_line . " for "
             . $url . "\n";
        $die++;
    }

    if (
        $self->mech->content =~ qr{
    <div id="content" class="error">
          <h1>(.*?)</h1>
            <p class="message">(.*?)</p>}ism
        )
    {
        warn "$1 $2\n";
        $die++;
    }

    # Returns TRUE if it got an error, for nicer conditionals when calling
    if ( $die ) { warn "Request errored out.\n"; return 1; }
    else        { return }
}

sub ensure_logged_in {
    my $self = shift;
    if ( !defined $self->logged_in ) {
        $self->_fetch("/login") or return;
        $self->logged_in(1);
    }
    return $self->logged_in;

}

sub _fetch_feed {
    my $self  = shift;
    my $query = shift;
    my $feed  = XML::Feed->parse( URI->new( $self->url . $query ) );

    if ( not $feed ) {
        warn XML::Feed->errstr;
        return;
    }

    return $feed;
}

sub _csv_to_struct {
    my $self = shift;
    my %args = validate( @_, { data => 1, key => 1, type => { default => 'hash' } } );
    my $csv  = Text::CSV_XS->new( { binary => 1 } );
    my $x    = $args{'data'};
    my $io   = IO::Scalar->new($x);
    my @cols = @{ $csv->getline($io) || [] };
    return unless defined $cols[0];
    $csv->column_names(@cols);
    my $data;

    if ( lc $args{'type'} eq 'hash' ) {
        while ( my $row = $csv->getline_hr($io) ) {
            $data->{ $row->{ $args{'key'} } } = $row;
        }
    }
    elsif ( lc $args{'type'} eq 'array' ) {
        while ( my $row = $csv->getline_hr($io) ) {
            push @$data, $row;
        }
    }
    return $data;
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;
