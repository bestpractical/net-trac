use strict;
use warnings;

package Net::Trac::TicketHistoryEntry;

use Any::Moose;
use Net::Trac::TicketPropChange;
use DateTime;
use HTTP::Date;

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

Takes a feed entry from a ticket history feed and parses it to fill
out the fields of this class.

=cut

sub parse_feed_entry {
    my $self = shift;
    my $e    = shift; 

    # We use a reference to a copy of ticket state as it was after this feed 
    # entry to interpret what "x added, y removed" meant for absolute values
    # of keywords

    my $ticket_state = shift; 

    if ($e =~ m|<dc:creator>(.*?)</dc:creator>|is) {
        my $author = $1;
        $self->author( $author );
    }

    if ($e =~ m|<pubDate>(.*?)</pubDate>|is) {
        my $date = $1;
        $self->date(DateTime->from_epoch(epoch => str2time($date)));
    }

    if ($e =~ m|<category>(.*?)</category>|is) {
        my $c = $1;
        $self->category($c);
    }

 
    if ($e =~ m|<description>\s*(.*?)\s*</description>|is) {
        my $desc = $1;
        $desc =~ s/&gt;/>/gi;
        $desc =~ s/&lt;/</gi;
        $desc =~ s/&amp;/&/gi;
        
    if ( $desc =~ s|^\s*?<ul>(.*)</ul>||is) {
        my $props = $1;
        $self->prop_changes( $self->_parse_props($props, $ticket_state) );
    }

    $self->content($desc);
    }
}

sub _parse_props {
    my $self       = shift;
    my $raw        = shift || '';
    my $ticket_state = shift;
    # throw out the wrapping <li>
   $raw =~ s|^\s*?<li>(.*)</li>\s*?$|$1|is;
    my @prop_lines = split( m#</li>\s*<li>#s, $raw );
    my $props      = {};

    foreach my $line (@prop_lines) {
        my ($prop, $old, $new);
        if ($line =~ m{<strong>attachment</strong>}) {
            # we can't handle trac's "attahcment changes" messages yet
            next;
        }
        if ($line =~ m{<strong>description</strong>}) {
            # We can't parse trac's crazy "go read a diff on a webpage handling 
            # of descriptions
            next; 
        }
        if ($line =~ m{<strong>(keywords|cc)</strong>(.*)$}is ) {
            my $value_changes = $2;
            $prop = $1;
            my (@added, @removed);
            if ($value_changes =~ m{^\s*<em>(.*?)</em> added}is) {
                    my $added = $1;
                    @added = split(m{</em>\s*<em>}is, $added);
                }  

            if ($value_changes =~ m{(?:^|added;)\s*<em>(.*)</em> removed}is) {
                    my $removed = $1;
                    @removed = split(m{</em>\s*?<em>}is, $removed);

            }
          
           my @before = (); 
           my @after  =  grep defined && length, split (/\s+/,$ticket_state->{keywords});
           for my $value  (@after) {
                next if grep {$_ eq  $value} @added;
                push @before, $value;
            }

            $old = join(' ', sort (@before, @removed));
            $new = join(' ', sort (@after));
            $ticket_state->{$prop} = $old;
        }
        elsif ( $line =~ m{<strong>(.*?)</strong>\s+changed\s+from\s+<em>(.*)</em>\s+to\s+<em>(.*)</em>}is ) {
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
        } 
        else {
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
no Any::Moose;

1;
