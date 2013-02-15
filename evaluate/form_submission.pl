#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long qw(:config posix_default no_ignore_case gnu_compat);

my $filter_c_mode = 0;
my $to_remove_attr = 0;
my $filter_id_mode = 0;
GetOptions('c' => \$filter_c_mode, 'r' => \$to_remove_attr, 'i' => \$filter_id_mode);

while (<>) {
    if ($filter_c_mode) {
        s/<\/?[^\/c][^>]*>//g;
        s/<c [^>]*>/<c>/g if $to_remove_attr;
    } elsif ($filter_id_mode) {
        s/<\/?c[^>]*>//g;
    } else {
        die;
    }

    print $_;
}
