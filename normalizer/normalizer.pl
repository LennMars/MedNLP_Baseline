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

if ($#ARGV < 0) {die "Usage: normalizer.pl [-tag tag=dict1[,dict2...]]... xml";}

my %tag_to_table_files = ();
GetOptions('tag=s' => \%tag_to_table_files);

die "Missing filename." if (!$ARGV[0]);

my $parser = XML::LibXML->new();
my $xml = $parser->parse_file($ARGV[0]);
my $doc = $xml->getDocumentElement();

while (my ($tag, $table_files) = each %tag_to_table_files) {
    normalize_tag($doc, $tag, $table_files);
}

print HTML::Entities::decode($doc->toString());


sub normalize_tag {
    my ($doc, $tag, $table_files_text) = @_;
    my @nodes = $doc->getElementsByTagName($tag);
    my @texts = map {$_->textContent()} @nodes;

    my %unifier = map {$_, 1} @texts; # remove duplication
    @texts = keys %unifier;

    my @table_files = split ',', $table_files_text;
    my %normals;

    while (@texts && @table_files) {
        my $query = join(' ', @texts);
        $query =~ s/[\n\(\)\|;"'<>]//g;
        next unless ($query);

        my $table_file = shift @table_files;
        print STDERR "normalize with $table_file\n";
        open(my $normal_in, "$Bin/sim.pl -m $table_file $query |");
        binmode $normal_in, ':encoding(utf8)';

        while (<$normal_in>) {
            chomp;
            my @sp = split("\t");
            if (@sp > 1) {
                $normals{$sp[0]} = $sp[1];
                print STDERR "$sp[0] -> $sp[1]\n";
            }
        }

        @texts = grep {! (exists $normals{$_})} @texts; # filter out if normal form found
    }

    foreach (@nodes) {
        my $normal = $normals{$_->textContent()};
        $_->setAttribute('normal', $normal) if (defined $normal);
    }
}
