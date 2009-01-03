use strict;
use warnings;

package Net::Trac::TicketHistory;

use Moose;
use Params::Validate qw(:all);
use Net::Trac::TicketHistoryEntry;

=head1 NAME

Net::Trac::TicketHistory - A Trac ticket's history

=head1 SYNOPSIS

    my $history = Net::Trac::TicketHistory->new( connection => $trac );
    $history->load( 13 );

    # Print the authors of all the changes to ticket #13
    for ( @{ $history->entries } ) {
        print $_->author, "\n";
    }

=head1 DESCRIPTION

This class represents a Trac ticket's history and is really just a collection
of L<Net::Trac::TicketHistoryEntries>.

=head1 ACCESSORS

=head2 connection

=head2 ticket

Returns the ID of the ticket whose history this object represents.

=head2 entries

Returns an arrayref of L<Net::Trac::TicketHistoryEntry>s.

=cut

has connection => (
    isa => 'Net::Trac::Connection',
    is  => 'ro'
);

has ticket  => ( isa => 'Int',      is => 'rw' );
has entries => ( isa => 'ArrayRef', is => 'rw' );

=head1 METHODS

=head2 load ID

Loads the history of the specified ticket.

=cut

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

=head1 LICENSE

Copyright 2008-2009 Best Practical Solutions.

This package is licensed under the same terms as Perl 5.8.8.

=cut

__PACKAGE__->meta->make_immutable;
no Moose;

1;
