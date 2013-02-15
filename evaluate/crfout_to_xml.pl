#!/usr/bin/perl
use strict;
use warnings;
use utf8;
binmode STDIN, ":encoding(utf-8)";
binmode STDOUT, ":encoding(utf-8)";

my $is_head = 0;
my $opening = '';

print "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
print "<medtexts>\n";

while (<>) {
    chomp;
    my @sp = split /\t/;
    if (scalar(@sp) < 1) {
        $is_head = 1;
        next;
    }
    my $surface = $sp[0];
    my $bio = $sp[$#sp];
    my @biosp = split /-/, $bio;
    if ($biosp[0] eq 'B') {
        my $c = close_tag ();
        if (scalar(@biosp) == 2) {
            $opening = $biosp[1];
            print "$c<$opening>$surface";
        } elsif (scalar(@biosp) == 3) {
            $opening = $biosp[1];
            print "$c<$opening modality=\"$biosp[2]\">$surface";
        } else {
            die;
        }
    } elsif ($biosp[0] eq 'O' && scalar(@biosp) == 1) {
        my $c = close_tag ();
        print "$c$surface";
        $opening = '';
    } elsif ($biosp[0] eq 'I') {
        my $c = $is_head ? "\n" : "";
        $is_head = 0;
        print "$c$surface";
    } else {
        die "$biosp[0] is not I|O|B";
    }
}

print "</medtexts>\n";

sub close_tag {
    my $n = $is_head ? "\n" : "";
    $is_head = 0;
    return ($opening ? "</$opening>$n" : $n);
}
