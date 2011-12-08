use strict;
use Test::More tests => 4;

use ok 'Test::WWW::Selenium::Mechanize';

isa_ok(Test::WWW::Selenium::Mechanize->new, 'Test::WWW::Selenium::Mechanize');
