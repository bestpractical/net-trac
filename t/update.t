use warnings; 
use strict;

use Test::More tests => 29;
use_ok('Net::Trac::Connection');
use_ok('Net::Trac::Ticket');
use_ok('Net::Trac::TicketSearch');
require 't/setup_trac.pl';

my $tr = Net::Trac::TestHarness->new();
ok($tr->start_test_server(), "The server started!");

my $trac = Net::Trac::Connection->new(
    url      => $tr->url,
    user     => 'hiro',
    password => 'yatta'
);

isa_ok( $trac, "Net::Trac::Connection" );
is($trac->url, $tr->url);
my $ticket = Net::Trac::Ticket->new( connection => $trac);
isa_ok($ticket, 'Net::Trac::Ticket');

can_ok($ticket => '_fetch_new_ticket_metadata');
ok($ticket->_fetch_new_ticket_metadata);
can_ok($ticket => 'create');
ok($ticket->create(summary => 'Summary #1'));

can_ok($ticket, 'load');
ok($ticket->load(1));
like($ticket->state->{'summary'}, qr/Summary #1/);
like($ticket->summary, qr/Summary #1/, "The summary looks correct");

can_ok($ticket => 'update');
ok($ticket->update( status => 'closed' ), "status = closed");
is(@{$ticket->history->entries}, 1, "Got one history entry.");
is($ticket->status, 'closed', "Got updated status");

my $search = Net::Trac::TicketSearch->new( connection => $trac );
isa_ok( $search, 'Net::Trac::TicketSearch' );
can_ok( $search => 'query' );
ok($search->query( id => 1 ));
is(@{$search->results}, 1, "Got one result");
isa_ok($search->results->[0], 'Net::Trac::Ticket');
is($search->results->[0]->id, 1, "Got id");
is($search->results->[0]->status, 'closed', "Got status");
sleep(1); # trac can't have two updates within one second
ok($ticket->update( resolution => 'fixed' ), "resolution = fixed");
is(@{$ticket->history->entries}, 2, "Got two history entries");
is($ticket->resolution, 'fixed', "Got updated resolution");


