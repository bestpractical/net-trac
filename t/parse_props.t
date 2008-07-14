use Test::More qw/no_plan/;

my $props = <<'EOF';

<strong>owner</strong> changed from <em>somebody</em> to <em>jrv</em>.</li>
    <li><strong>status</strong> changed from <em>new</em> to <em>assigned</em>.</li>
    <li><strong>type</strong> changed from <em>defect</em> to <em>enhancement</em>.</li>
    <li><strong>description</strong> set to <em>cry</em>

EOF

use_ok('Net::Trac::TicketHistoryEntry');

my $e = Net::Trac::TicketHistoryEntry->new();
my $props = $e->_parse_props($props);
is(scalar keys %$props, 4, "Four properties");
my @keys = sort (qw(owner status type description));
is_deeply([sort keys %$props], [sort @keys]);

