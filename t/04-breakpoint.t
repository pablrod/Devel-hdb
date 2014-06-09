use strict;
use warnings;

use lib 't';
use HdbHelper;
use Devel::hdb::Client;

use Test::More;
if ($^O =~ m/^MS/) {
    plan skip_all => 'Test hangs on Windows';
} else {
    plan tests => 7;
}

my $url = start_test_program();
my $client = Devel::hdb::Client->new(url => $url);

my $stack;
my $resp = $client->stack();
ok($resp, 'Request stack position');
my $filename = $resp->[0]->{filename};
$stack = strip_stack($resp);
is_deeply($stack,
    [ { line => 1, subroutine => 'main::MAIN' } ],
    'Stopped on line 1');

subtest 'invalid breakpoints' => sub {
    plan tests => 4;

    my $resp = eval { $client->create_breakpoint(filename => $filename, line => 4, code => 1) };
    ok(!$resp && $@, 'Cannot set breakpoint on unbreakable line');
    is($@->http_code, 403, 'Error was Forbidden');

    $resp = eval { $client->create_breakpoint(filename => 'garbage', line => 123, code => 1) };
    ok(!$resp && $@, 'Cannot set breakpoint on unknown file');
    is($@->http_code, 404, 'Error was Not Found');
};

my $breakpoint_id;
subtest 'create breskpoint' => sub {
    plan tests => 1;

    $breakpoint_id = $client->create_breakpoint(filename => $filename, line => 3, code => 1);
    ok($breakpoint_id, 'Set breakpoint for line 3');
};

subtest 'get breakpoint' => sub {
    plan tests => 3;

    my $resp = eval { $client->get_breakpoint('garbage') };
    ok(!$resp && $@, 'Cannot get unknown breakpoint');
    is($@->http_code, 404, 'Error was Not Found');

    $resp = $client->get_breakpoint($breakpoint_id);
    is_deeply($resp,
        { filename => $filename, line => 3, code => 1, inactive => 0, href => $breakpoint_id },
        'Get breakpoint by id');
};

subtest 'stop at breakpoint' => sub {
    plan tests => 2;

    my $resp = $client->continue();
    is_deeply($resp,
        { filename => $filename, line => 3, subroutine => 'MAIN', running => 1 },
        'continue to line 3');

    $resp = $client->continue();
    my $stopped_filename = delete $resp->{filename};
    my $stopped_line = delete $resp->{line};
    is_deeply($resp,
        { subroutine => 'Devel::Chitin::exiting::at_exit', running => 0, exit_code => 0 },
        'continue to end');
};

subtest 'delete breakpoint' => sub {
    plan tests => 3;

    my $resp = eval { $client->delete_breakpoint('garbage') };
    ok(!$resp && $@, 'Cannot delete unknown breakpoint');
    is($@->http_code, 404, 'Error was Not Found');

    $resp = $client->delete_breakpoint($breakpoint_id);
    ok($resp, 'Delete previously added breakpoint');
};


__DATA__
1;
foo();
3;
sub foo {
    5;
}
