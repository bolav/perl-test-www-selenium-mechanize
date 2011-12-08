package Test::WWW::Selenium::Mechanize;

use Moose;
use Parse::Selenese;
use Test::More;
use Test::WWW::Mechanize;
use utf8;

use HTML::TreeBuilder;
use HTML::TreeBuilder::XPath;

use Data::Dump qw/dump/;

has 'testbuilder' => (is => 'ro', default => sub { Test::More->builder; });
has 'mech'        => (is => 'ro', default => sub { Test::WWW::Mechanize->new(); });


# State variables. NOT THREADSAFE!
has 'changed'   => (is => 'rw', isa => 'Bool', default => 1);
has 'wanttree'  => (is => 'rw', isa => 'Bool', default => 0);
has 'wantxpath' => (is => 'rw', isa => 'Bool', default => 0);

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
            }
            if ($self->wanttree && !$tree) {
                $tree = HTML::TreeBuilder->new_from_content($mech->content);
            }
            if ($self->wantxpath && !$xpath) {
                $xpath = HTML::TreeBuilder::XPath->new_from_content($mech->content);
            }
            eval $cmd;
        }
        # $tree && $tree->delete;
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

sub comment {
    my ($self, $tc, $values, $instr) = @_;
    return '$tb->diag('.$instr.');'."\n";
}

sub waitForTitle {
    my ($self, $tc, $values, $instr) = @_;
    return '$mech->title_is('._esc_in_q($values->[1]).', '.$instr.');'."\n";
}

*verifyElementPresent = \&assertElementPresent;

sub assertElementPresent {
    my ($self, $tc, $values, $instr) = @_;
    if ($values->[1] =~ /^id=(.*)/) {
        my $val = $1;
        $self->wanttree(1);
        return 'ok($tree->look_down("id" => '._esc_in_q($val).'), '.$instr.');'."\n";
    }
    elsif ($values->[1] =~ /^link=(.*)/) {
        return 'ok($mech->find_link( text => '._esc_in_q($1).'), '.$instr.');'."\n";
    }
    elsif ($values->[1] =~ m{^//}) {
        $self->wantxpath(1);
        return 'ok($xpath->findnodes('._esc_in_q($values->[1]).')->size, '.$instr.')'."\n";
    }
    else {
        return '$tb->todo_skip('.$instr.');'."\n";
    }
}

=head2 _esc_in_q

Escape in quotes

=cut

sub _esc_in_q {
    my ($str) = @_;
    $str =~ s/\'//g;
    return "'".$str."'";
}

1;
