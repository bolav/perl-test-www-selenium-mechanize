use strict;
use Test::More;

use Test::WWW::Selenium::Mechanize;

use lib 't/';
use TestServer;

my $server = TestServer->new();
my $pid = $server->background();

my $root             = $server->root;

my $signal = ($^O eq 'MSWin32') ? 9 : 15;
my $nprocesses = kill $signal, $pid;
is( $nprocesses, 1, 'Signaled the child process' );


my $twsm = Test::WWW::Selenium::Mechanize->new;

$twsm->run('t/data/test.html');
done_testing();