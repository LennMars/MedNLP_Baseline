#!/usr/bin/perl
use strict;
use warnings;
use utf8;
binmode STDIN, ":encoding(utf-8)";
binmode STDOUT, ":encoding(utf-8)";

while (<STDIN>) {
    $_ =~ s/(\d+)-(\d+)-(\d+)/$1年$2月$3日/;
    $_ =~ tr/[0-9a-zA-Z]/[０-９ａ-ｚＡ-Ｚ]/;
    print $_;
}

