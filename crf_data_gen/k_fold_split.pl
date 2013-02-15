#!/usr/bin/perl -w
use strict;
use utf8;
use XML::LibXML;
use Getopt::Std;

my %opts = ('n' => 2);
getopts ("n:", \%opts);
my $num_split = $opts{"n"};

my $parser = XML::LibXML->new();
my $filename = $ARGV[0];
my $doc = $parser->parse_file($filename);
my $root_orig = $doc->getDocumentElement();
my @children_orig = $root_orig->nonBlankChildNodes();
my $xml_size = $#children_orig + 1;

$filename =~ s/\..*$//;
my $dirname = "${filename}_${num_split}fold";
mkdir $dirname;

my $fold_size = int ($xml_size / $num_split);
my $start = 0;

for (my $n = 0; $n < $num_split; ++$n) {
  my $fold_size = $fold_size + (($n < $xml_size - $fold_size * $num_split) ? 1 : 0);

  my $root = $root_orig->cloneNode(1);
  my $node = $root->firstChild;
  for (my $m = 0; $m <= $start; ++$m) {
    $node = $node->nextNonBlankSibling;
  }
  my @to_remove = ();
  for (my $m = 0; $m < $fold_size; ++$m) {
    push @to_remove, $node;
    $node = $node->nextNonBlankSibling;
  }

  my $root_test = $root_orig->cloneNode(0);
  map {
    $root->removeChild($_);
    $root_test->appendChild($_);
  } @to_remove;

  open TRAIN, "> ${dirname}/train_${n}" or die "Cannot open output file: $!";
  open TEST, "> ${dirname}/test_${n}" or die "Cannot open output file: $!";
  binmode(TRAIN, ":utf8");
  binmode(TEST, ":utf8");
  print TRAIN $root->toString;
  print TEST $root_test->toString;
  close TRAIN;
  close TEST;

  $start += $fold_size;
}
