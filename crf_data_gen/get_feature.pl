#!/usr/bin/perl -w
use strict;
use utf8;
use Encode;
use MeCab;
use Getopt::Long qw(:config posix_default no_ignore_case gnu_compat);
use FindBin;
use lib "$FindBin::Bin";
use MednlpFeature;
binmode STDOUT, ":encoding(utf-8)";

# read dictionaries
my @dictionary_files;
GetOptions ('d=s' => \@dictionary_files);

my @dictionaries = init_dictionaries(\@dictionary_files);

# read input
open INPUT, $ARGV[0] or die;
binmode INPUT, ":encoding(utf-8)";
my @input = <INPUT>;
my $input_joined = join '', @input;

init_word_intervals($input_joined, \@dictionaries);

my $pos = 0; # in input_joined

foreach (@input) {
    my $string = $_;
    my $mecab = MeCab::Tagger->new();
    my $node = $mecab->parseToNode($string);

    for ( ; $node; $node = $node->{next}) { # for each morpheme
        my ($class1, $class2, $read) =
            map {decode("utf-8", $_)} (split(/,/, $node->{feature}))[0, 1, 7];
        # skip begin and end in the result of morphological analysis
        next if ($class1 =~ /BOS|EOS/);

        my $surface = decode("utf-8", $node->{surface});
        my $pos_temp = index($input_joined, $surface, $pos);
        # print "surface: $surface, pos_prev: $pos, pos_found: $pos_temp\n";
        my $bio_str = bio_from_intervals($pos_temp);

        my $letter_type = letter_type($surface);

        my $last_char = substr $surface, -1;

        my @out = map {(defined && $_ ne '') ? $_ : '*'} ($surface, $class1, $class2, $read, $bio_str, $letter_type, $last_char);
        my $out_str = join " ", @out;
        print $out_str, "\n";

        $pos = $pos_temp + length($surface);
    }

    # add a line break for each end of sentences
    if (substr ($string, -1) eq "\n") {
        print "\n";
    }
}
