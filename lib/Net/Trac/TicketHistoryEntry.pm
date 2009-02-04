use strict;
use warnings;

package Net::Trac::TicketHistoryEntry;

use Moose;
use Net::Trac::TicketPropChange;

=head1 NAME

Net::Trac::TicketHistoryEntry - A single history entry for a Trac ticket

=head1 DESCRIPTION

This class represents a single item in a Trac ticket history.

=head1 ACCESSORS

=head2 connection

Returns a L<Net::Trac::Connection>.

=head2 author

=head2 date

Returns a L<DateTime> object.

=head2 category

=head2 content

=head2 prop_changes

Returns a hashref (property names as the keys) of
L<Net::Trac::TicketPropChange>s associated with this history entry.

=cut

has connection => (
    isa => 'Net::Trac::Connection',
    is  => 'ro'
);

has prop_changes => ( isa => 'HashRef', is => 'rw' );

has author   => ( isa => 'Str',      is => 'rw' );
has date     => ( isa => 'DateTime', is => 'rw' );
has category => ( isa => 'Str',      is => 'rw' );
has content  => ( isa => 'Str',      is => 'rw' );

=head1 METHODS

=head2 parse_feed_entry

Takes an L<XML::Feed::Entry> from a ticket history feed and parses it to fill
out the fields of this class.

=cut

sub parse_feed_entry {
    my $self = shift;
    my $e    = shift;    # XML::Feed::Entry

    $self->author( $e->author );
    $self->date( $e->issued );
    $self->category( $e->category );

    my $desc = $e->content->body;
    if ( $desc =~ s|^\s*?<ul>(.*)</ul>||is) {
        my $props = $1;
        $self->prop_changes( $self->_parse_props($props) );
    }

    $self->content($desc);
    return 1;
}

sub _parse_props {
    my $self       = shift;
    my $raw        = shift || '';
    # throw out the wrapping <li>
   $raw =~ s|^\s*?<li>(.*)</li>\s*?$|$1|is;
    my @prop_lines = split( m#</li>\s*<li>#s, $raw );
    my $props      = {};

    foreach my $line (@prop_lines) {
        my ($prop, $old, $new);
        if ( $line =~ m{<strong>(.*?)</strong>\s+changed\s+from\s+<em>(.*)</em>\s+to\s+<em>(.*)</em>}is ) {
            $prop = $1;
            $old  = $2;
            $new  = $3;
        } elsif ( $line =~ m{<strong>(.*?)</strong>\s+set\s+to\s+<em>(.*)</em>}is ) {
            $prop = $1;
            $old  = '';
            $new  = $2;
        } elsif ( $line =~ m{<strong>(.*?)</strong>\s+<em>(.*?)</em>\s+deleted}is ) {
            $prop = $1;
            $old = $2;
            $new  = '';
        } elsif ( $line =~ m{<strong>(.*?)</strong>\s+deleted}is ) {
            $prop = $1;
            $new  = '';
        } else {
            warn "could not  parse ". $line;
        }

        if ( $prop ) {
            my $pc = Net::Trac::TicketPropChange->new(
                property  => $prop,
                new_value => $new,
                old_value => $old
            );
            $props->{$prop} = $pc;
        } else {
            warn "I found no prop in $line";
        }
    }
    return $props;
}

=head1 LICENSE

Copyright 2008-2009 Best Practical Solutions.

This package is licensed under the same terms as Perl 5.8.8.

=cut

__PACKAGE__->meta->make_immutable;
no Moose;

1;
