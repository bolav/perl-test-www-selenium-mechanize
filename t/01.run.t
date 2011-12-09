use strict;
use Test::More;

use Test::WWW::Selenium::Mechanize;
use Test::MockModule;

use lib 't/';
use TestServer;

my $server = TestServer->new();
my $pid = $server->background();

my $root             = $server->root;

my $module = new Test::MockModule('Parse::Selenese::TestCase');
$module->mock('base_url', sub { $root });

my $twsm = Test::WWW::Selenium::Mechanize->new;

$twsm->run('t/data/test.html');

my $signal = ($^O eq 'MSWin32') ? 9 : 15;
my $nprocesses = kill $signal, $pid;
is( $nprocesses, 1, 'Signaled the child process' );

done_testing();
