#!/usr/bin/perl
use strict;
use warnings;
use utf8;
binmode STDIN, ":encoding(utf-8)";
binmode STDOUT, ":encoding(utf-8)";

while (<STDIN>) {
    s/[\x{0001}]//g;
    s/(\d+)-(\d+)-(\d+)/$1年$2月$3日/;
    tr/[0-9a-zA-Z%&#<>_\^\/\?\[\]]/[０-９ａ-ｚＡ-Ｚ％＆＃＜＞＿＾／？［］]/;
    print $_;
}
