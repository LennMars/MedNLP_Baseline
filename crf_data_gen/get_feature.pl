#!/usr/bin/perl -w
use strict;
use utf8;
use Encode;
use MeCab;
use Getopt::Long qw(:config posix_default no_ignore_case gnu_compat);
use Algorithm::AhoCorasick qw(find_all);
use Set::IntervalTree;
binmode STDOUT, ":encoding(utf-8)";

# read dictionaries
my @dictionary_files;
GetOptions ('d=s' => \@dictionary_files);

my @dictionaries = map {
    open DICT, $_ or die;
    binmode DICT, ":encoding(utf-8)";
    my @dict = <DICT>;
    close DICT;
    map {chomp;} @dict;
    \@dict;
} @dictionary_files;

# read input
open INPUT, $ARGV[0] or die;
binmode INPUT, ":encoding(utf-8)";
my @input = <INPUT>;
my $input_joined = join '', @input;

# search words in dictionaries and convert founds into interval
my @word_intervals = map {
    my $interval = Set::IntervalTree->new;
    my $found = find_all($input_joined, @{$_});
    foreach my $pos (keys %$found) {
        my $pos2 = $pos + length($found->{$pos}->[0]);
        # print "word: $found->{$pos}->[0], $pos to $pos2\n";
        $interval->insert($pos, $pos, $pos2);
    }
    $interval;
} @dictionaries;

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
        my @bios = map {
            my $interval = $_->fetch($pos_temp, $pos_temp + 1);
            if (@$interval) {
                ($interval->[0] == $pos_temp) ? 'B' : 'I';
            } else {
                'O';
            }
        } @word_intervals;

        my $bio_str = join '', @bios;
        my @out = map {(defined && $_ ne '') ? $_ : '*'} ($surface, $class1, $class2, $read, $bio_str);
        my $out_str = join " ", @out;
        print $out_str, "\n";

        $pos = $pos_temp + length($surface);
    }

    # add a line break for each end of sentences
    if (substr ($string, -1) eq "\n") {
        print "\n";
    }
}
