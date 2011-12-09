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

# http://use.perl.org/~miyagawa/journal/31204
# http://search.cpan.org/perldoc?WWW%3A%3AMechanize%3A%3ATreeBuilder

has 'testbuilder' => (is => 'ro', default => sub { Test::More->builder; });
has 'mech'        => (is => 'ro', default => sub { Test::WWW::Mechanize->new(); });

# State variables. NOT THREADSAFE!
has 'changed'   => (is => 'rw', isa => 'Bool', default => 1);
has 'wanttree'  => (is => 'rw', isa => 'Bool', default => 0);
has 'wantxpath' => (is => 'rw', isa => 'Bool', default => 0);

has 'skiptest'  => (is => 'rw', isa => 'Bool', default => 0);

sub get_test {
    my ($self, $test) = @_;
    
    if (ref $test) {
        
    } else {
        $test = Parse::Selenese::parse($test);
    }
    return $test;
}

sub run {
    my ($self, $test) = @_;
    my $tb = $self->testbuilder;
    my $mech = $self->mech;
    my $tree;
    my $xpath;

    $test = $self->get_test($test);

    if (ref $test eq 'Parse::Selenese::TestCase') {
        foreach my $command (@{$test->commands}) {
            my ($cmd, $args) = $self->convert_command($command, $test);
            if ($self->wanttree && !$tree) {
                $tree = HTML::TreeBuilder->new_from_content($mech->content);
                $self->wanttree(0);
            }
            if ($self->wantxpath && !$xpath) {
                $xpath = HTML::TreeBuilder::XPath->new_from_content($mech->content);
                $self->wantxpath(0);
            }
            if ($self->skiptest) {
                $cmd = '$tb->diag("Skipping javascript test");'."\n";
            }

            eval $cmd;
            if ($@) {
                die $@.' '.join(' ', @{$command->values})."\n".$cmd;
            }
            if ($self->changed) {
                $self->changed(0);
                $self->wanttree(0);
                $self->wantxpath(0);
                $tree && $tree->delete;
                $tree = undef;
                $xpath && $xpath->delete;
                $xpath = undef;
            }
        }
        $tree && $tree->delete;
        $xpath && $xpath->delete;
    }
}

sub as_perl {
    my ($self, $test) = @_;
    my $tree;
    my $xpath;
    $test = $self->get_test($test);
    my $perl = <<'PERL';
use Test::More;
use Test::WWW::Mechanize;
use utf8;

use HTML::Strip;
use HTML::TreeBuilder;
use HTML::TreeBuilder::XPath;
use HTML::Selector::XPath;

my $tree;
my $xpath;
my $tb = Test::More->builder;
PERL
    foreach my $command (@{$test->commands}) {
        my ($cmd, $args) = $self->convert_command($command, $test);
        if ($self->wanttree && !$tree) {
            $tree = 1;
            $perl .= '  $tree = HTML::TreeBuilder->new_from_content($mech->content);'."\n";
            $self->wanttree(0);
        }
        if ($self->wantxpath && !$xpath) {
            $xpath = 1;
            $perl .= '  $xpath = HTML::TreeBuilder::XPath->new_from_content($mech->content);'."\n";
            $self->wantxpath(0);
        }
        if ($self->skiptest) {
            $cmd = '$tb->diag("Skipping javascript test");'."\n";
        }
        $perl .= $cmd;
        if ($self->changed) {
            $self->changed(0);
            $self->wanttree(0);
            $self->wantxpath(0);
            $tree = 0;
            $xpath = 0;
            $perl .= <<'PERL';
  $tree && $tree->delete;
  $tree = undef;
  $xpath && $xpath->delete;
  $xpath = undef;
PERL
        }
    }
    $perl .= <<'PERL';
  $tree && $tree->delete;
  $xpath && $xpath->delete;
  done_testing;
PERL
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

sub type {
    my ($self, $tc, $values, $instr) = @_;
    return '$mech->field('._esc_in_q($values->[1]).', '._esc_in_q($values->[2]).');'."\n";
}

sub clickAndWait {
    my ($self, $tc, $values, $instr) = @_;
    if ($values->[1] =~ /^link=(.*)/) {
        $self->changed(1);
        return '$mech->follow_link_ok({ text => '._esc_in_q($1).'}, '.$instr.');'."\n";
    }
    elsif ($values->[1] =~ /^css=(.*)/) {
        my $xp = HTML::Selector::XPath::selector_to_xpath($1);
        $self->wantxpath(1);
        return '{
  my $node = $xpath->findnodes('._esc_in_q($xp).')->[0];
  if ($node->attr(\'type\') eq \'submit\') {
      $mech->form_number(find_formnumber($node));
      my $req = $mech->current_form->find_input( undef, \'submit\', find_typenumber($node, {type => \'submit\'}, \'form\') )->click($mech->current_form);
      $mech->request($req);
      ok($mech->success, '.$instr.');
  }
  else {
      $tb->todo_skip('.$instr.');
  }
}
';
    }
    elsif ($values->[1] =~ m{^//}) {
        return '{
  my $node = $xpath->findnodes('._esc_in_q($values->[1]).')->[0];
  if ($node->tag eq \'a\') {
      $mech->get_ok($node->attr(\'href\'));
  }
  else {
      $tb->todo_skip('.$instr.');
  }
}
';

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
    my $locator = $self->locator_to_perl($values->[1],1);

    if ($locator) {
        return 'is('.$locator.', '._esc_in_q($values->[2]).', '.$instr.');'."\n";
    }
        # TODO: Filter out HTML
        # html_strip($xpath->findnodes_as_string('._esc_in_q($values->[1]).'))
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
}

sub assertElementNotPresent {
    my ($self, $tc, $values, $instr) = @_;
    return 'ok(!'.$self->locator_to_perl($values->[1]).', '.$instr.')'."\n";
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
        else {
            $self->wanttree(1);
            return '$tree->look_down("id" => '._esc_in_q($locator).')';
        }
    }
    else {
        # Want to compare against a value
        if (0) {
            
        }
        elsif ($locator =~ /^css=(.*)/) {
            my $xp = HTML::Selector::XPath::selector_to_xpath($1);
            $self->wantxpath(1);
            return '$xpath->findnodes('._esc_in_q($xp).')->[0]->as_text';
        }
        elsif ($locator =~ m{^//}) {
            return '$xpath->findnodes('._esc_in_q($locator).')->[0]->as_text';
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


# TODO: Move this to Mechanize::Helper, and export by default
# Needs to be done for perl-conversion to work

sub html_strip {
    my ($str) = @_;
    my $hs = HTML::Strip->new();
    my $clean_text = $hs->parse( $str );
    $hs->eof;
    $clean_text =~ s/\s$//;
    $clean_text =~ s/^\s//;
    return $clean_text;
}

# If we need more like this, could be refactored into find_parent, and then
# use find_typenumber

sub find_formnumber {
    my ($node) = @_;
    my $find = $node;
    while ($find->tag and $find->tag ne 'form') {
        $find = $find->parent;
    }
    if ($find) {
        my @forms = $node->root->look_down('_tag' => 'form');
        my $i = 1;
        foreach my $form (@forms) {
            return $i if ($find == $form);
            $i++;
        }
    }
    warn "Button not in a form";
}

# parent should use root if not set

sub find_typenumber {
    my ($node, $search, $parent) = @_;
    my $find = $node;
    while ($find->tag and $find->tag ne $parent) {
        $find = $find->parent;
    }
    if ($find) {
        my @found = $find->look_down(%$search);
        my $i = 1;
        foreach my $f (@found) {
            return $i if ($f == $node);
            $i++;
        }
    }
    warn "not found";
}


1;
