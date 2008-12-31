use warnings; 
use strict;

use Test::More qw/no_plan/;
use_ok('Net::Trac::Connection');
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
my $ticket = Net::Trac::Ticket->new( connection => $trac );
isa_ok($ticket, 'Net::Trac::Ticket');

can_ok($ticket => 'create');
ok($ticket->create(summary => 'Summary #1'));

can_ok($ticket, 'load');
ok($ticket->load(1));
like($ticket->state->{'summary'}, qr/Summary #1/);
like($ticket->summary, qr/Summary #1/, "The summary looks correct");

can_ok($ticket => 'create');
ok($ticket->create(summary => 'Summary #2'));

can_ok($ticket, 'load');
ok($ticket->load(2));
like($ticket->state->{'summary'}, qr/Summary #2/);
like($ticket->summary, qr/Summary #2/, "The summary looks correct");

my $search = Net::Trac::TicketSearch->new( connection => $trac );
isa_ok( $search, 'Net::Trac::TicketSearch' );
can_ok( $search => 'query' );
ok($search->query);
is(@{$search->results}, 2, "Got two results");
isa_ok($search->results->[0], 'Net::Trac::Ticket');
isa_ok($search->results->[1], 'Net::Trac::Ticket');
is($search->results->[0]->summary, "Summary #1", "Got summary");
is($search->results->[1]->summary, "Summary #2", "Got summary");

ok($search->query( id => 2 ));
is(@{$search->results}, 1, "Got one result");
isa_ok($search->results->[0], 'Net::Trac::Ticket');
is($search->results->[0]->summary, "Summary #2", "Got summary");

