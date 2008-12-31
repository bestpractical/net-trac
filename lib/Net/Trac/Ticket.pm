package Net::Trac::Ticket;
use Moose;
use Params::Validate qw(:all);

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

has _attachments     => ( isa => 'ArrayRef', is => 'rw' );

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
        description keywords component milestone version )
}

for my $prop ( __PACKAGE__->valid_props ) {
    no strict 'refs';
    *{ "Net::Trac::Ticket::" . $prop } = sub { shift->state->{$prop} };
}

sub load {
    my $self = shift;
    my ($id) = validate_pos( @_, { type => SCALAR } );
    $self->connection->_fetch( "/ticket/" . $id . "?format=csv" );

    my $content  = $self->connection->mech->content;
    my $stateref = $self->connection->_csv_to_struct( data => \$content, key => 'id' );
    return undef unless $stateref;
    return $self->load_from_hashref( $stateref->{$id} );
}

sub load_from_hashref {
    my ($self, $hash) = @_;
    return undef unless $hash and $hash->{'id'};
    $self->state( $hash );
    return $hash->{'id'};
}

sub _get_new_ticket_form {
    my $self = shift;
    $self->connection->ensure_logged_in;
    $self->connection->_fetch("/newticket");
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
    $self->connection->_fetch("/ticket/".$self->id);
    my $i = 1; # form number;
    for my $form ( $self->connection->mech->forms() ) {
        return ($form,$i) if $form->find_input('field_reporter');
        $i++;
    }
    return undef;
}

sub _fetch_new_ticket_metadata {
    my $self = shift;
    my ($form, $form_num) = $self->_get_new_ticket_form;

    return undef unless $form;

    $self->valid_milestones(
        [ $form->find_input("field_milestone")->possible_values ] );
    $self->valid_types( [ $form->find_input("field_type")->possible_values ] );
    $self->valid_components(
        [ $form->find_input("field_component")->possible_values ] );
    $self->valid_priorities(
        [ $form->find_input("field_priority")->possible_values ] );

    my $severity = $form->find_input("field_severity");
    $self->valid_severities( $severity->possible_values ) if $severity;
    
#    my @inputs = $form->inputs;
#
#    for my $in (@inputs) {
#        my @values = $in->possible_values;
#    }

    return 1;
}

sub _fetch_update_ticket_metadata {
    my $self = shift;
    my ($form, $form_num) = $self->_get_update_ticket_form;

    return undef unless $form;

    my $resolutions = $form->find_input("action_resolve_resolve_resolution");
    $self->valid_resolutions( $resolutions->possible_values ) if $resolutions;
    
    return 1;
}

sub create {
    my $self = shift;
    my %args = validate(
        @_,
        { map { $_ => 0 } grep { !/resolution/ } $self->valid_props }
    );

    my ($form,$form_num)  = $self->_get_new_ticket_form();

    my %form = map { 'field_' . $_ => $args{$_} } keys %args;

    $self->connection->mech->submit_form(
        form_number => $form_num,
        fields => { %form, submit => 1 }
    );

    my $reply = $self->connection->mech->response;
    $self->connection->_die_on_error( $reply->base->as_string );

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
            map { $_ => 0 } $self->valid_props
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
            if $args{'owner'} eq $self->connection->user
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

    # XXX TODO: use _die_on_error here?

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
    my $hist = Net::Trac::TicketHistory->new(
        { connection => $self->connection, ticket => $self->id } );
    $hist->load;
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
    $self->connection->_fetch("/attachment/ticket/".$self->id."/?action=new");
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
    $self->connection->_die_on_error( $reply->base->as_string );

    return $self->attachments->[-1];
}

sub _update_attachments {
    my $self = shift;
    $self->connection->ensure_logged_in;
    my $content = $self->connection->_fetch("/attachment/ticket/".$self->id."/");
    
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

#http://barnowl.mit.edu/ticket/36?format=tab

__PACKAGE__->meta->make_immutable;
no Moose;

1;

