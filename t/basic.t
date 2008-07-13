use Test::More qw/no_plan/;

use_ok('Net::Trac::Connection');
my $trac = Net::Trac::Connection->new(url => "http://scripts.mit.edu/~jrv/trac");
isa_ok($trac, "Net::Trac::Connection");
is($trac->url, "http://scripts.mit.edu/~jrv/trac");

can_ok($trac, '_fetch');
use_ok('Net::Trac::Ticket');
my $ticket = Net::Trac::Ticket->new( connection => $trac);
isa_ok($ticket, 'Net::Trac::Ticket');
can_ok($ticket, 'load');
ok($ticket->load(1));
like($ticket->state->{'summary'}, qr/pony/);
like($ticket->summary, qr/pony/);
ok($ticket->history);
