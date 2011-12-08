use strict;
use Test::More;
use Parse::Selenese::Command;

use Test::WWW::Selenium::Mechanize;

my $twsm = Test::WWW::Selenium::Mechanize->new;

my $tc = Parse::Selenese::TestCase->new(base_url => 'http://www.startsiden.no');
{
    my $cmd = Parse::Selenese::Command->new(values => ['open', '/']);
    is($twsm->convert_command($cmd, $tc), '$mech->get_ok(\'http://www.startsiden.no/\', \'open /\');'."\n");    
}
{
    my $cmd = Parse::Selenese::Command->new(values => ['unknown_cmd', '/']);
    is($twsm->convert_command($cmd, $tc), '$tb->todo_skip(\'unknown_cmd /\');'."\n");    
}

{
    my $cmd = Parse::Selenese::Command->new(values => ['assertElementPresent', 'id=footer']);
    is($twsm->convert_command($cmd, $tc), 'ok($tree->look_down("id" => \'footer\'), \'assertElementPresent id=footer\');'."\n");    
}

done_testing();