package Test::WWW::Selenium::Mechanize::Helper;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(find_formnumber find_typenumber);

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
