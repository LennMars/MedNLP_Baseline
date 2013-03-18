#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use XML::LibXML;
use Getopt::Long qw(:config posix_default no_ignore_case gnu_compat);
use Encode;
use HTML::Entities;
use FindBin qw($Bin);
binmode STDOUT, ":encoding(utf-8)";
binmode STDERR, ":encoding(utf-8)";

if ($#ARGV != 2) {die "Usage: normalizer.pl TAG DICT ATTR < INPUT";}

my $parser = XML::LibXML->new();
my $in = join '', <STDIN>;
my $xml = $parser->parse_string($in);
my $doc = $xml->getDocumentElement();

normalize_tag($ARGV[0], $ARGV[1], $ARGV[2], $doc);

print HTML::Entities::decode($doc->toString());


sub normalize_tag {
    my ($tag, $dict, $attr, $doc) = @_;
    print STDERR "normalize $tag -> $attr with $dict\n";

    my @nodes = $doc->getElementsByTagName($tag);
    my @texts = map {$_->textContent()} @nodes;

    my %unifier = map {$_, 1} @texts; # remove duplication
    @texts = keys %unifier;

    my $query = join(' ', @texts);
    $query =~ s/[\n\(\)\|;"'<>]//g;
    return unless ($query);

    open(my $normal_in, "$Bin/sim.pl -m $dict $query |");
    binmode $normal_in, ':encoding(utf8)';

    my %normals;
    while (<$normal_in>) {
        chomp;
        my @sp = split("\t");
        if (@sp > 1) {
            $normals{$sp[0]} = $sp[1];
            print STDERR "$sp[0] -> $sp[1]\n";
        }
    }

    foreach (@nodes) {
        my $normal = $normals{$_->textContent()};
        $_->setAttribute($attr, $normal) if (defined $normal);
    }
}
