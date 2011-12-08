package Test::WWW::Selenium::HTMLReader;

use Moo;
use Carp;
use XML::LibXML;

has 'parser' => (is => 'ro', default => sub { XML::LibXML->new(); });

use Data::Dump qw/dump dd/;

sub read {
    my ($self, $filename) = @_;
    my $ret = {};
    my $test_dom = $self->parser->parse_html_file( $filename );
    my @title_tags = $test_dom->getElementsByTagName( q{title} );
    $ret->{title} = $title_tags[0]->firstChild->nodeValue();


    my ($tbody) = $test_dom->getElementsByTagName( q{tbody} );
    foreach my $action_set ( $tbody->getElementsByTagName( q{tr} ) ) {
      my ( $action, $operand_1, $operand_2 ) = $action_set->getElementsByTagName( q{td} );
      foreach my $node ( $action, $operand_1, $operand_2 ) {
        if ( defined $node->firstChild ) {
          $node = $node->firstChild->nodeValue();
        } else {
          $node = q{};
        }
      }
      if ( $operand_1 =~ m{\A[(]?//}xms ) {
        $operand_1 = q{xpath=} . $operand_1;
      }
      print STDERR "$action $operand_1 $operand_2\n";
    }

    $ret->{tests} = [];
    return $ret;
}

1;
