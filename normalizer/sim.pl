#!/usr/bin/perl -w
#
# sim.pl
#
use Encode;
use utf8;
use strict;
use Unicode::Normalize;
use Getopt::Long qw(:config posix_default no_ignore_case gnu_compat);

binmode(STDIN, ":encoding(utf8)");
binmode(STDOUT, ":utf8");

# ./sim.pl -m tables/Master_M.txt -r "XX/アク" アクチダス XXチダス ビルレクス
foreach (@ARGV) {$_ = decode('utf8', $_);}

my $master_file;
my @rule_args;
GetOptions('m=s' => \$master_file, 'r=s' => \@rule_args);

my $master = read_master($master_file);
my $rules = read_rules(@rule_args);

my @found = map {[$_, search($master, $rules, $_)]} @ARGV;
foreach (@found) {
    print "$_->[0]" . ($_->[1] ? "\t$_->[1]\n" : "\n");
}

sub search {
    my $master = shift;
    my $rules = shift;
    my $input = shift;

    my @max_codes;
    my $max_sim = 1;
    my $input_p = paraphrase(normalize_unicode($input), $rules);
    my $input_s = word_split($input_p);

    my %used;
    while (my ($code, $texts) = each %$master) {
        foreach (@$texts) {
            my $master_p = paraphrase(normalize_unicode($_), $rules);
            my $master_s = word_split($master_p);

            my $sim = get_sim($input_s, $master_s);
            if ($sim > $max_sim) {
                @max_codes = ($code);
                $max_sim = $sim;
                undef %used;
                $used{$code} = 1;
            } elsif ($sim == $max_sim && ! exists $used{$code}) {
                push @max_codes, $code;
                $used{$code} = 1;
            }
        }
    }
    return (@max_codes < 20) ? (join ',', @max_codes) : '';
}

sub read_rules {
    my @rules;
    foreach (@_) {
        chomp;
        my @n = split /\//;
        push @rules, [$n[0], $n[1]];
    }
    return \@rules;
}

sub read_master {
    my $file = shift;
    my %master;
    open my $in, "<:encoding(utf8)", $file or die "failed opening $file";
    while (<$in>) {
        chomp;
        my @n = split /\t/;
        if (exists $master{$n[1]}) {
            push @{$master{$n[1]}}, $n[0];
        } else {
            $master{$n[1]} = [$n[0]];
        }
    }
    return \%master;
}

sub paraphrase {
    my $input = shift;
    my $rules = shift or return $input;
    foreach my $rule (@$rules) {
        my @n = split(/,/, $rule->[0]);
        foreach my $tmp (@n) {
            next unless ($input =~ /$tmp/);
            my $w = "0-9A-z";
            if  ($tmp =~ /^$w+$/ && $input =~ /(.*)$tmp(.*)/) {
                # アルファベットの部分一致を無視する
                next if (($1 =~ /$w$/) or ($2 =~ /^$w/));
            }
            # パラフレーズを表示
            # print "change[".$input."]".$tmp."-->".$rule->[1]."\n";
            $input=~s/$tmp/$rule->[1]/g;
            $input=~s/^_//;
            $input=~s/_$//;
            $input=~s/_+/_/g;
        }
    }
    return $input;
}

sub remove_paren {
    map {
        s/ //s;
        s/\(//s;
        s/\)//s;
    } @_;
}

sub get_sim {
    ### 構成要素にばらして類似度をえる###
    my $src = shift;
    my $tgt = shift;

    my @n = split(/\|/, $src);
    remove_paren(@n);

    my $SIM = 0;
    foreach my $tmp (@n) {
        next if ($tmp eq "_");

        my @n2 = split(/\|/, $tgt);
        remove_paren(@n2);

        my $sim = 0;

        foreach (@n2) { # STEP1: 構成要素の完全一致をみる
            if ($tmp eq $_) {
                $sim = length($tmp);
            }
        }
        if ($sim == 0) { # STEP2: 構成要素の部分一致をみる
            foreach (@n2) {
                my $w = "0-9A-z";
                if (length($tmp) >= 1 && $tmp =~ /^$w+$/ && $_ =~ /(.*)$tmp(.*)/) {
                    # アルファベットの部分一致を無視する
                    next if ($1 =~ /$w$/) or ($2 =~ /^$w/);
                    $sim = length($tmp) / 2;
                    #print "partly match [". $tmp2."]-[".$tmp."]".$1."\n";
                }
            }
        }
        $SIM += $sim;
    }
    return $SIM;
}

sub word_split {
    # 文字種切りわけ
    my $text = shift;
    $text=~s/[＿ _]/\|/g;

    my $pat = qr/(
                  \d+                 |
                  \p{InBasicLatin}+                 |
                  \p{InHalfwidthAndFullwidthForms}+ |
                  \p{Hiragana}+                     |
                  \p{Katakana}+                     |
                  \p{Han}+     |
                  \p{InGreek}  |
                  \p{Common}+
                  )/x;
    my $ret;
    while ($text =~ /($pat)/g) {
        $ret.="|".$1;
    }

    $ret=~s/(\p{Katakana})\|(ー)\|(\p{Katakana})/$1$2$3/g;
    $ret=~s/(\p{Hiragana})\|(ー)\|(\p{Hiragana})/$1$2$3/g;
    $ret=~s/\|ー/ー/g;
    $ret=~s/ー(\d)/ー|$1/g;

    $ret=~s/-/\|/g;
    $ret=~s/\|+/|/g; # remove consecutive separator
    $ret=~s/^\|//; # remove separator on head
    return $ret;
}

sub normalize_unicode {
    # unicode 正規化
    my $input = uc($_[0]);
    # my $input=NFKC($input);
    $input =~ s/[；;\^＊※：:\(\) +*・]/＿/g;
    $input =~ s/＿+/＿/g;
    $input =~ s/([A-z])-([1-9])/$1$2/; # アルファベット+ハイフン+数字はアルファベットだけにする
    return $input;
}

1;
