#!/usr/bin/perl -w
package MednlpFeature;
use strict;
use Set::IntervalTree;
use Algorithm::AhoCorasick qw(find_all);
use base qw(Exporter);
our @EXPORT = qw( init_word_intervals bio_from_intervals init_dictionaries letter_type );

my @word_intervals;

# search words in dictionaries and convert founds into interval
sub init_word_intervals {
    my $input_joined = shift;
    my $dictionaries = shift;
    @word_intervals = map {
        my $interval = Set::IntervalTree->new;
        my $found = find_all($input_joined, @{$_});
        foreach my $pos (keys %$found) {
            my $pos2 = $pos + length($found->{$pos}->[0]);
            $interval->insert($pos, $pos, $pos2);
        }
        $interval;
    } @$dictionaries;
}

sub bio_from_intervals {
    my $pos = shift;
    my @bios = map {
        my $interval = $_->fetch($pos, $pos + 1);
        if (@$interval) {
            ($interval->[0] == $pos) ? 'B' : 'I';
        } else {
            'O';
        }
    } @word_intervals;
    return join '', @bios;
}

sub init_dictionaries {
    my $dictionary_files = shift;
    return map {
        open DICT, $_ or die;
        binmode DICT, ":encoding(utf-8)";
        my @dict = <DICT>;
        close DICT;
        map {chomp;} @dict;
        \@dict;
    } @$dictionary_files;
}

sub letter_type {
    my $str = shift;
    if ($str =~ /^[\d０-９\.]+$/) {
        return 'digit';
    } elsif ($str =~ /^\p{Latin}+$/) {
        return 'latin';
    } elsif ($str =~ /^[\p{Hiragana}ー]+$/) {
        return 'hiragana';
    } elsif ($str =~ /^[\p{Katakana}ー]+$/) {
        return 'katakana';
    } elsif ($str =~ /^\p{Han}+$/) {
        return 'kanji';
    } elsif ($str =~ /^\p{Common}+$/) {
        return 'symbol';
    } else {
        return 'mixed';
    }
}

1;
