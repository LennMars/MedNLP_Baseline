#!/usr/bin/perl
use strict;
use warnings;

my $is_flat = $ARGV[0];

my $rex_per = "([\\d\.]+)";
my $rex_prf = "\\s*precision:\\s*$rex_per%;\\s*recall:\\s*$rex_per%;\\s*FB1:\\s*$rex_per";

while (<STDIN>) {
    if (/accuracy:\s*$rex_per%;$rex_prf/) {
        $is_flat ? print "$2\t$3\t$4\t$1\t" : print "accucacy $1 $2 $3 $4\n";
    } elsif (/([\w\-]+):$rex_prf/) {
        $is_flat ? print "$2\t$3\t$4\t" : print "$1 $2 $3 $4\n";
    } else {
 #       print "\n";
    }
}

print "\n" if $is_flat;
