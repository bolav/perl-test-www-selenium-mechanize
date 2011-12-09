package Test::WWW::Selenium::Mechanize;

use Moose;
use Parse::Selenese;
use Test::More;
use Test::WWW::Mechanize;
use utf8;

use HTML::Strip;
use HTML::TreeBuilder;
use HTML::TreeBuilder::XPath;
use HTML::Selector::XPath;

use Data::Dump qw/dump/;

has 'testbuilder' => (is => 'ro', default => sub { Test::More->builder; });
has 'mech'        => (is => 'ro', default => sub { Test::WWW::Mechanize->new(); });

# State variables. NOT THREADSAFE!
has 'changed'   => (is => 'rw', isa => 'Bool', default => 1);
has 'wanttree'  => (is => 'rw', isa => 'Bool', default => 0);
has 'wantxpath' => (is => 'rw', isa => 'Bool', default => 0);

has 'skiptest'  => (is => 'rw', isa => 'Bool', default => 0);

sub run {
    my ($self, $test) = @_;
    my $tb = $self->testbuilder;
    my $mech = $self->mech;
    my $tree;
    my $xpath;

    if (ref $test) {
        
    } else {
        $test = Parse::Selenese::parse($test);
    }
    # dump $test;
    if (ref $test eq 'Parse::Selenese::TestCase') {
        foreach my $command (@{$test->commands}) {
            my ($cmd, $args) = $self->convert_command($command, $test);
            if ($self->changed) {
                $self->changed(0);
                $tree && $tree->delete;
                $tree = undef;
                $xpath && $xpath->delete;
                $xpath = undef;
            }
            if ($self->wanttree && !$tree) {
                $tree = HTML::TreeBuilder->new_from_content($mech->content);
            }
            if ($self->wantxpath && !$xpath) {
                $xpath = HTML::TreeBuilder::XPath->new_from_content($mech->content);
            }
            if ($self->skiptest) {
                $cmd = '$tb->diag("Skipping javascript test");'."\n";
            }

            eval $cmd;
            if ($@) {
                die $@.' '.join(' ', @{$command->values})."\n".$cmd;
            }
        }
        $tree && $tree->delete;
        $xpath && $xpath->delete;
    }
}

sub convert_command {
    my ($self, $command, $tc) = @_;
    my ($cmd, @values) = @{$command->values};
    my $cmdstr = '';
    my $instr = join ' ',@{$command->values};
    $instr =~ s/\'//g;
    $instr = "'".$instr."'";
    
    if (my $coderef = $self->can($cmd)) {
        $cmdstr = &{$coderef}($self, $tc, $command->values, $instr);
    }
    else {
        $cmdstr = '$tb->todo_skip('.$instr.');'."\n";
    }
    return $cmdstr;
}

sub open {
    my ($self, $tc, $values, $instr) = @_;
    my $url = $tc->base_url;
    $url =~ s/\/$//;
    return '$mech->get_ok(\''.$url.$values->[1].'\', '.$instr.');'."\n";
}

sub clickAndWait {
    my ($self, $tc, $values, $instr) = @_;
    if ($values->[1] =~ /^link=(.*)/) {
        $self->changed(1);
        return '$mech->follow_link_ok({ text => '._esc_in_q($1).'}, '.$instr.');'."\n";
    }
    else {
        return '$tb->todo_skip('.$instr.');'."\n";        
    }
}

*verifyTextPresent = \&assertTextPresent;

sub assertTextPresent {
    my ($self, $tc, $values, $instr) = @_;
    return '$mech->text_contains('._esc_in_q($values->[1]).', '.$instr.');'."\n";
}

sub assertText {
    my ($self, $tc, $values, $instr) = @_;
    if (0) {
        
    }
    elsif ($values->[1] =~ m{^//}) {
        $self->wantxpath(1);
        # TODO: Filter out HTML
        return 'is(html_strip($xpath->findnodes_as_string('._esc_in_q($values->[1]).')), '._esc_in_q($values->[2]).', '.$instr.')'."\n";
    }
    return '$tb->todo_skip('.$instr.');'."\n";
}

sub comment {
    my ($self, $tc, $values, $instr) = @_;
    if ($values->[1] eq 'no_mech') {
        $self->skiptest(1);
    }
    else {
        $self->skiptest(0);
    }
    return '$tb->diag('.$instr.');'."\n";
}

sub waitForTitle {
    my ($self, $tc, $values, $instr) = @_;
    return '$mech->title_is('._esc_in_q($values->[1]).', '.$instr.');'."\n";
}

*verifyElementPresent = \&assertElementPresent;

sub assertElementPresent {
    my ($self, $tc, $values, $instr) = @_;
    return 'ok('.$self->locator_to_perl($values->[1]).', '.$instr.');'."\n";
    if ($values->[1] =~ /^id=(.*)/) {
        my $val = $1;
        $self->wanttree(1);
        return 'ok($tree->look_down("id" => '._esc_in_q($val).'), '.$instr.');'."\n";
    }
    elsif ($values->[1] =~ /^link=(.*)/) {
        return 'ok($mech->find_link( text => '._esc_in_q($1).'), '.$instr.');'."\n";
    }
    elsif ($values->[1] =~ /^class=(.*)/) {
        my $val = $1;
        $self->wanttree(1);
        return 'ok($tree->look_down("class" => '._esc_in_q($val).'), '.$instr.');'."\n";
    }
    elsif ($values->[1] =~ m{^//}) {
        $self->wantxpath(1);
        return 'ok($xpath->findnodes('._esc_in_q($values->[1]).')->size, '.$instr.')'."\n";
    }
    else {
        return '$tb->todo_skip('.$instr.');'."\n";
    }
}

sub assertElementNotPresent {
    my ($self, $tc, $values, $instr) = @_;
    if (0) {
        
    }
    elsif (($values->[1] =~ m{^//}) && ($values->[2])) {
        $self->wantxpath(1);
        return 'isnt($xpath->findnodes_as_string('._esc_in_q($values->[1]).'), '._esc_in_q($values->[2]).','.$instr.')'."\n";
    }
    elsif ($values->[1] =~ m{^//}) {
        $self->wantxpath(1);
        return 'ok(!$xpath->findnodes('._esc_in_q($values->[1]).')->size, '.$instr.')'."\n";
    }
}

sub locator_to_perl {
    my ($self, $locator, $value) = @_;
    if (!$value) {
        if ($locator =~ /^id=(.*)/) {
            my $val = $1;
            $self->wanttree(1);
            return '$tree->look_down("id" => '._esc_in_q($val).')';
        }
        elsif ($locator =~ /^class=(.*)/) {
            my $val = $1;
            $self->wanttree(1);
            return '$tree->look_down("class" => '._esc_in_q($val).')';
        }
        elsif ($locator =~ /^link=(.*)/) {
            return '$mech->find_link( text => '._esc_in_q($1).')';
        }
        elsif ($locator =~ /^css=(.*)/) {
            my $xp = HTML::Selector::XPath::selector_to_xpath($1);
            $self->wantxpath(1);
            return '$xpath->findnodes('._esc_in_q($xp).')->size';
        }
        elsif ($locator =~ m{^//}) {
            $self->wantxpath(1);
            return '$xpath->findnodes('._esc_in_q($locator).')->size';
        }
    }
}

=head2 _esc_in_q

Escape in quotes

=cut

sub _esc_in_q {
    my ($str) = @_;
    $str =~ s/\\/\\\\/g;
    $str =~ s/\'/\\\'/g;
    return "'".$str."'";
}

sub html_strip {
    my ($str) = @_;
    my $hs = HTML::Strip->new();
    my $clean_text = $hs->parse( $str );
    $hs->eof;
    $clean_text =~ s/\s$//;
    $clean_text =~ s/^\s//;
    return $clean_text;
}

1;
