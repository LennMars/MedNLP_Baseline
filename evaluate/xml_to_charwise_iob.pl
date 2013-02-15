#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use Getopt::Long qw(:config posix_default no_ignore_case gnu_compat);
use Algorithm::Diff qw(diff);
use Data::Dumper;
binmode STDOUT, ":utf8";

if ($#ARGV == -1) {
    print "usage: xml_to_charwise_iob.pl [-d1 depth] [-d2 depth] [-mod] [-h] file1 [file2]\n";
    exit 1;
}

my $start_depth_correct = 0;
my $start_depth_answer = 0;
my $is_modality_concerned = 0;
my $wild_char = '';
my $is_readable_mode = 0;
GetOptions(
    'd1=i' => \$start_depth_correct,
    'd2=i' => \$start_depth_answer,
    'mod' => \$is_modality_concerned,
    'w=s' => \$wild_char,
    'h' => \$is_readable_mode
);

my $correct = input_as_str($ARGV[0]);
my $raw = extract_text($correct);
my $pos_correct = 0;
my @tags_correct = ();

my $is_compare_mode = ($#ARGV >= 1);

my $answer;
if ($is_compare_mode) {
    my $raw_nolinebreak = remove_linebreak($raw);
    $answer = input_as_str($ARGV[1]);
    my $raw_answer_nolinebreak = remove_linebreak(extract_text($answer));
    if (!$wild_char && $raw_nolinebreak ne $raw_answer_nolinebreak) {
        print STDERR "incompatible texts.\n";
        open CORRECT_OUT, ">:utf8", "raw.txt";
        open ANSWER_OUT, ">:utf8", "raw_answer.txt";
        print CORRECT_OUT $raw_nolinebreak;
        print ANSWER_OUT $raw_answer_nolinebreak;
        close CORRECT_OUT;
        close ANSWER_OUT;
        my @correct_arr = split //, $raw_nolinebreak;
        my @answer_arr = split //, $raw_answer_nolinebreak;
        my $diffref = diff(\@correct_arr, \@answer_arr);
        open DIFF_OUT, ">:utf8", "diff.txt";
        print DIFF_OUT (Data::Dumper->Dump($diffref));
        close DIFF_OUT;
        exit 1;
    }
}
my $pos_answer = 0;
my @tags_answer = ();

my $line_num_raw = 1;
for (my $pos_raw = 0; $pos_raw < length($raw); ++$pos_raw) {
    my $char = substr($raw, $pos_raw, 1);
    if ($char eq "\n") {
        $line_num_raw += 1;
        print "\n";
        next;
    }

    print "$char";

    print "\t$line_num_raw" if $is_readable_mode;

    my $is_correct_tag_opened = forward(\$correct, \$pos_correct, \@tags_correct, $char);
    my $iob_correct = get_iob(\@tags_correct, $is_correct_tag_opened, $start_depth_correct);

    print "\t$iob_correct";

    if ($is_compare_mode) {
        my $is_answer_tag_opened = forward(\$answer, \$pos_answer, \@tags_answer, $char);
        my $iob_answer = get_iob(\@tags_answer, $is_answer_tag_opened, $start_depth_answer);
        print "\t$iob_answer";
        if ($is_readable_mode) {
            print "\t", (($iob_correct eq $iob_answer) ? '' : '!');
        }
    }

    print "\n";
}

sub get_iob {
    my ($tagsref, $is_tag_opened, $start_depth) = @_;
    my @tags = @$tagsref;
    my $iob;
    if ($#tags >= $start_depth) {
        my $last_tag = $tags[$#tags];
        my ($name, $modality) = @$last_tag;
        $iob = ($is_tag_opened) ? "B-$name" : "I-$name";
        if ($is_modality_concerned && $modality) {
            $iob = $iob . "-$modality";
        }
    } else {
        $iob = $is_readable_mode ? '' : 'O';
    }
    return $iob;
}

sub forward {
    my ($textref, $posref, $tagsref, $char) = @_;
    my $pos = $$posref;
    my $is_tag_opened = 0;
    while (1) {
        die "searching $char failed" if ($pos >= length $$textref);
        my $ch = substr($$textref, $pos, 1);
        if ($ch eq $wild_char || $ch eq $char) { # char found
            ++$pos;
            last;
        } elsif ($ch eq '<') { # tag found
            my $close_pos = index($$textref, '>', $pos + 1);
            die "searching '>' failed" if ($close_pos == -1);
            my $tagstr = substr($$textref, $pos + 1, $close_pos - $pos - 1);
            $tagstr =~ /(\?)?(\/)?([^ ]+)( modality="(.*?)")?/;
            if ($1) {} # header
            elsif ($2) { # close tag
                my $tag = pop @$tagsref;
                die "unbalanced tags $tag->[0] and $3" if ($3 ne $tag->[0]);
            } else { # open tag
                $is_tag_opened = 1;
                my @tag = ($3, $5); # name, modality
                push @$tagsref, \@tag;
            }
            $pos = $close_pos + 1;
        } else {
            ++$pos;
            next;
        }
    }
    $$posref = $pos;
    return $is_tag_opened;
}


sub extract_text {
    my $copy = shift;
    $copy =~ s/[\ \t\f]|<.*?>//g;
    return $copy;
}

sub remove_linebreak {
    my $copy = shift;
    $copy =~ s/\n//g;
    return $copy;
}

sub input_as_str {
    my $filename = shift;
    open INPUT, $filename or die "cannot open $filename\n";
    binmode INPUT, ":encoding(utf-8)";
    my @input = <INPUT>;
    close INPUT;
    return join '', @input;
}
