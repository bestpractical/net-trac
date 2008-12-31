package Net::Trac::TicketAttachment;
use Moose;
use Moose::Util::TypeConstraints;
use DateTime::Format::ISO8601;

has connection => (
    isa => 'Net::Trac::Connection',
    is  => 'ro'
);

subtype 'DateTime' => as 'Object' => where { $_->isa('DateTime') };
coerce  'DateTime' => from 'Str'  => via {
    # Trac formats ISO8601 dates wrong
    s/Z//;
    s/([+-]\d\d)(\d\d)$/$1:$2/;
    DateTime::Format::ISO8601->parse_datetime( $_ );
};

has ticket      => ( isa => 'Int',      is => 'ro' );
has date        => ( isa => 'DateTime', is => 'rw', coerce => 1 );
has filename    => ( isa => 'Str',      is => 'rw' );
has description => ( isa => 'Str',      is => 'rw' );
has url         => ( isa => 'Str',      is => 'rw' );
has author      => ( isa => 'Str',      is => 'rw' );
has size        => ( isa => 'Int',      is => 'rw' );

sub _parse_html_chunk {
    my $self = shift;
    my $html = shift;

#      <a href="/trac/attachment/ticket/1/xl0A1UDD4i" title="View attachment">xl0A1UDD4i</a>
#      (<span title="27 bytes">27 bytes</span>) - added by <em>hiro</em>
#      <a class="timeline" href="/trac/timeline?from=2008-12-30T15%3A45%3A24Z-0500&amp;precision=second" title="2008-12-30T15:45:24Z-0500 in Timeline">0 seconds</a> ago.
#    </dt>
#                <dd>
#                  Test description
#                </dd>
    
    $self->filename($1) if $html =~ qr{<a (?:.+?) title="View attachment">(.+?)</a>};
    $self->url( "/raw-attachment/ticket/" . $self->ticket . "/" . $self->filename )
        if defined $self->filename;

    $self->size($1)         if $html =~ qr{<span title="(\d+) bytes">};
    $self->author($1)       if $html =~ qr{added by <em>(.+?)</em>};
    $self->date($1)         if $html =~ qr{<a (?:.+?) title="(.+?) in Timeline">};
    $self->description($1)  if $html =~ qr{<dd>\s*(\S.*?)\s*</dd>\s*$};

    return 1;
}

sub content {
    my $self = shift;
    return $self->connection->_fetch( $self->url );
}

=head1 NAME

Net::Trac::TicketAttachment

=head1 DESCRIPTION

This class represents a single attachment for a trac ticket.

=head1 METHODS

=head2 filename

=head2 description

=head2 content

=head2 size

=head2 url

=head2 author

=head2 date

=cut

1;
