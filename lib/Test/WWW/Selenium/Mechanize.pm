package Test::WWW::Selenium::Mechanize;

use Moose;
use Parse::Selenese;
use Test::More;
use Test::WWW::Mechanize;

use Data::Dump qw/dump/;

has 'testbuilder' => (is => 'ro', default => sub { Test::More->builder });
has 'mech' => (is => 'ro', default => sub { Test::WWW::Mechanize->new() });

sub run {
    my ($self, $test) = @_;
    print "test: $test\n";
    my $tb = $self->testbuilder;
    my $mech = $self->mech;
    if (ref $test) {
        
    } else {
        $test = Parse::Selenese::parse($test);
    }
    # dump $test;
    if (ref $test eq 'Parse::Selenese::TestCase') {
        foreach my $command (@{$test->commands}) {
            my $cmd = $self->convert_command($command, $test);
            eval $cmd;
        }
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
        return '$mech->follow_link_ok({ text => '._esc_in_q($1).'}, '.$instr.')'
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
