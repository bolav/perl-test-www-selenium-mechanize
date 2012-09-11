use strict;
use Test::More;
use Parse::Selenese::Command;

use Test::WWW::Selenium::Mechanize;

my $twsm = Test::WWW::Selenium::Mechanize->new;

my $tc = Parse::Selenese::TestCase->new(base_url => 'http://www.startsiden.no');
{
    my $cmd = Parse::Selenese::Command->new(values => ['open', '/']);
    is($twsm->convert_command($cmd, $tc), '$mech->get_ok(\'http://www.startsiden.no/\', \'open /\') or Test::More::plan skip_all => "Unable to connect to http://www.startsiden.no/" and exit(1);'."\n");
}
{
    my $cmd = Parse::Selenese::Command->new(values => ['unknown_cmd', '/']);
    is($twsm->convert_command($cmd, $tc), '$tb->todo_skip(\'unknown_cmd /\');'."\n");
}

{
    my $cmd = Parse::Selenese::Command->new(values => ['assertElementPresent', 'id=footer']);
    is($twsm->convert_command($cmd, $tc), 'ok($tree->look_down("id" => \'footer\'), \'assertElementPresent id=footer\');'."\n");
}

{
    my $cmd = Parse::Selenese::Command->new(values => ['assertElementNotPresent', '//div[@id=fp_cont]']);
    is($twsm->convert_command($cmd, $tc), 'ok(!$xpath->findnodes(\'//div[@id=fp_cont]\')->size, \'assertElementNotPresent //div[@id=fp_cont]\');'."\n");
}

{
    my $cmd = Parse::Selenese::Command->new(values => ['assertText', '//div', 'Arne']);
    is($twsm->convert_command($cmd, $tc), 'ok($xpath->findnodes(\'//div\')->size, \'Arne\');
is(text_trim($xpath->findnodes(\'//div\')->[0]->as_text), \'Arne\', \'assertText //div Arne\') if ($xpath->findnodes(\'//div\')->size);'."\n");
}


done_testing();
