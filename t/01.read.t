use strict;
use Test::More tests => 4;

use ok 'Test::WWW::Selenium::HTMLReader';

my $read;
isa_ok($read = Test::WWW::Selenium::HTMLReader->new, 'Test::WWW::Selenium::HTMLReader');

$read->read('t/data/test.html');
