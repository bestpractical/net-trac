package Net::Trac::Ticket;
use Moose;
use Params::Validate qw(:all);
use Lingua::EN::Inflect qw();
use DateTime::Format::ISO8601;

use Net::Trac::TicketSearch;
use Net::Trac::TicketHistory;
use Net::Trac::TicketAttachment;

has connection => (
    isa => 'Net::Trac::Connection',
    is  => 'ro'
);

has state => (
    isa => 'HashRef',
    is  => 'rw'
);

has _attachments            => ( isa => 'ArrayRef', is => 'rw' );
has _loaded_new_metadata    => ( isa => 'Bool',     is => 'rw' );
has _loaded_update_metadata => ( isa => 'Bool',     is => 'rw' );

has valid_milestones  => ( isa => 'ArrayRef', is => 'rw', default => sub {[]} );
has valid_types       => ( isa => 'ArrayRef', is => 'rw', default => sub {[]} );
has valid_components  => ( isa => 'ArrayRef', is => 'rw', default => sub {[]} );
has valid_priorities  => ( isa => 'ArrayRef', is => 'rw', default => sub {[]} );
has valid_resolutions => ( isa => 'ArrayRef', is => 'rw', default => sub {[]} );
has valid_severities  => ( isa => 'ArrayRef', is => 'rw', default => sub {[]} );

sub basic_statuses {
    qw( new accepted assigned reopened closed )
}

sub valid_props {
    qw( id summary type status priority severity resolution owner reporter cc
        description keywords component milestone version time changetime )
}

sub valid_create_props { grep { !/^(?:resolution|time|changetime)$/i } $_[0]->valid_props }
sub valid_update_props { grep { !/^(?:time|changetime)$/i } $_[0]->valid_props }

for my $prop ( __PACKAGE__->valid_props ) {
    no strict 'refs';
    *{ "Net::Trac::Ticket::" . $prop } = sub { shift->state->{$prop} };
}

sub created       { shift->_time_to_datetime('time') }
sub last_modified { shift->_time_to_datetime('changetime') }

sub _time_to_datetime {
    my ($self, $prop) = @_;
    my $time = $self->$prop;
    $time =~ s/ /T/;
    return DateTime::Format::ISO8601->parse_datetime( $time );
}

sub BUILD {
    my $self = shift;
    $self->_fetch_new_ticket_metadata;
}

sub load {
    my $self = shift;
    my ($id) = validate_pos( @_, { type => SCALAR } );

    my $search = Net::Trac::TicketSearch->new( connection => $self->connection );
    $search->limit(1);
    $search->query( id => $id, _no_objects => 1 );

    return unless @{ $search->results };

    my $tid = $self->load_from_hashref( $search->results->[0] );
    return $tid;
}

sub load_from_hashref {
    my $self = shift;
    my ($hash, $skip_metadata) = validate_pos(
        @_,
        { type => HASHREF },
        { type => BOOLEAN, default => undef }
    );

    return undef unless $hash and $hash->{'id'};

    $self->state( $hash );
    $self->_fetch_update_ticket_metadata unless $skip_metadata;
    return $hash->{'id'};
}

sub _get_new_ticket_form {
    my $self = shift;
    $self->connection->ensure_logged_in;
    $self->connection->_fetch("/newticket") or return;
    my $i = 1; # form number
    for my $form ( $self->connection->mech->forms() ) {
        return ($form,$i) if $form->find_input('field_reporter');
        $i++;
    }
    return undef;
}

sub _get_update_ticket_form {
    my $self = shift;
    $self->connection->ensure_logged_in;
    $self->connection->_fetch("/ticket/".$self->id) or return;
    my $i = 1; # form number;
    for my $form ( $self->connection->mech->forms() ) {
        return ($form,$i) if $form->find_input('field_reporter');
        $i++;
    }
    return undef;
}

sub _fetch_new_ticket_metadata {
    my $self = shift;

    return 1 if $self->_loaded_new_metadata;

    my ($form, $form_num) = $self->_get_new_ticket_form;
    return undef unless $form;

    $self->valid_milestones([ $form->find_input("field_milestone")->possible_values ]);
    $self->valid_types     ([ $form->find_input("field_type")->possible_values ]);
    $self->valid_components([ $form->find_input("field_component")->possible_values ]);
    $self->valid_priorities([ $form->find_input("field_priority")->possible_values ]);

    my $severity = $form->find_input("field_severity");
    $self->valid_severities([ $severity->possible_values ]) if $severity;
    
#    my @inputs = $form->inputs;
#
#    for my $in (@inputs) {
#        my @values = $in->possible_values;
#    }

    $self->_loaded_new_metadata( 1 );
    return 1;
}

sub _fetch_update_ticket_metadata {
    my $self = shift;

    return 1 if $self->_loaded_update_metadata;

    my ($form, $form_num) = $self->_get_update_ticket_form;
    return undef unless $form;

    my $resolutions = $form->find_input("action_resolve_resolve_resolution");
    $self->valid_resolutions( [$resolutions->possible_values] ) if $resolutions;
    
    $self->_loaded_update_metadata( 1 );
    return 1;
}

sub _metadata_validation_rules {
    my $self = shift;
    my $type = lc shift;

    # Ensure that we've loaded up metadata
    $self->_fetch_new_ticket_metadata;
    $self->_fetch_update_ticket_metadata if $type eq 'update';

    my %rules;
    for my $prop ( @_ ) {
        my $method = "valid_" . Lingua::EN::Inflect::PL($prop);
        if ( $self->can($method) ) {
            # XXX TODO: escape the values for the regex?
            my $values = join '|', grep { defined and length } @{$self->$method};
            if ( length $values ) {
                my $check = qr{^(?:$values)$}i;
                $rules{$prop} = { type => SCALAR, regex => $check, optional => 1 };
            } else {
                $rules{$prop} = 0;
            }
        }
        else {
            $rules{$prop} = 0; # optional
        }
    }
    return \%rules;
}

sub create {
    my $self = shift;
    my %args = validate(
        @_,
        $self->_metadata_validation_rules( 'create' => $self->valid_create_props )
    );

    my ($form,$form_num)  = $self->_get_new_ticket_form();

    my %form = map { 'field_' . $_ => $args{$_} } keys %args;

    $self->connection->mech->submit_form(
        form_number => $form_num,
        fields => { %form, submit => 1 }
    );

    my $reply = $self->connection->mech->response;
    $self->connection->_warn_on_error( $reply->base->as_string ) and return;

    if ($reply->title =~ /^#(\d+)/) {
        my $id = $1;
        $self->load($id);
        return $id;
    } else {
        return undef;
    }
}

sub update {
    my $self = shift;
    my %args = validate(
        @_,
        {
            comment         => 0,
            no_auto_status  => { default => 0 },
            %{$self->_metadata_validation_rules( 'update' => $self->valid_update_props )}
        }
    );

    # Automatically set the status for default trac workflows unless
    # we're asked not to
    unless ( $args{'no_auto_status'} ) {
        $args{'status'} = 'closed'
            if $args{'resolution'} and not $args{'status'};
        
        $args{'status'} = 'assigned'
            if $args{'owner'} and not $args{'status'};
        
        $args{'status'} = 'accepted'
            if $args{'owner'} and $args{'owner'} eq $self->connection->user
               and not $args{'status'};
    }

    my ($form,$form_num)= $self->_get_update_ticket_form();

    # Copy over the values we'll be using
    my %form = map  { "field_".$_ => $args{$_} }
               grep { !/comment|no_auto_status/ } keys %args;

    # Copy over comment too -- it's a pseudo-prop
    $form{'comment'} = $args{'comment'};

    $self->connection->mech->submit_form(
        form_number => $form_num,
        fields => { %form, submit => 1 }
    );

    my $reply = $self->connection->mech->response;
    if ( $reply->is_success ) {
        return $self->load($self->id);
    }
    else {
        return undef;
    }
}

sub comment {
    my $self = shift;
    my ($comment) = validate_pos( @_, { type => SCALAR });
    $self->update( comment => $comment );
}

sub history {
    my $self = shift;
    my $hist = Net::Trac::TicketHistory->new({ connection => $self->connection });
    $hist->load( $self->id );
    return $hist;
}

sub comments {
    my $self = shift;
    my $hist = $self->history;

    my @comments;
    for ( @{$hist->entries} ) {
        push @comments, $_ if $_->content =~ /\S/;
    }
    return wantarray ? @comments : \@comments;
}

sub _get_add_attachment_form {
    my $self = shift;
    $self->connection->ensure_logged_in;
    $self->connection->_fetch("/attachment/ticket/".$self->id."/?action=new") or return;
    my $i = 1; # form number;
    for my $form ( $self->connection->mech->forms() ) {
        return ($form,$i) if $form->find_input('attachment');
        $i++;
    }
    return undef;
}

sub attach {
    my $self = shift;
    my %args = validate( @_, { file => 1, description => 0 } );

    my ($form, $form_num)  = $self->_get_add_attachment_form();

    $self->connection->mech->submit_form(
        form_number => $form_num,
        fields => {
            attachment  => $args{'file'},
            description => $args{'description'},
            replace     => 0
        }
    );

    my $reply = $self->connection->mech->response;
    $self->connection->_warn_on_error( $reply->base->as_string ) and return;

    return $self->attachments->[-1];
}

sub _update_attachments {
    my $self = shift;
    $self->connection->ensure_logged_in;
    my $content = $self->connection->_fetch("/attachment/ticket/".$self->id."/")
        or return;
    
    if ( $content =~ m{<dl class="attachments">(.+?)</dl>}is ) {
        my $html = $1 . '<dt>'; # adding a <dt> here is a hack that lets us
                                # reliably parse this with one regex

        my @attachments;
        while ( $html =~ m{<dt>(.+?)(?=<dt>)}gis ) {
            my $fragment = $1;
            my $attachment = Net::Trac::TicketAttachment->new({
                connection => $self->connection,
                ticket     => $self->id
            });
            $attachment->_parse_html_chunk( $fragment );
            push @attachments, $attachment;
        }
        $self->_attachments( \@attachments );
    }
}

sub attachments {
    my $self = shift;
    $self->_update_attachments;
    return wantarray ? @{$self->_attachments} : $self->_attachments;
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;

