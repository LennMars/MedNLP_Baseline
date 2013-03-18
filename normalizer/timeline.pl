#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use XML::LibXML;
use Getopt::Long qw(:config posix_default no_ignore_case gnu_compat);
use Encode;
#binmode STDOUT, ":encoding(utf-8)";

my $time_tag = 't';
my $to_deter_original_text = 0;

GetOptions('t=s' => \$time_tag, 'q' => \$to_deter_original_text);

my $parser = XML::LibXML->new();
my $input_doc = $parser->parse_file($ARGV[0]);

my $timeline = XML::LibXML::Document->createDocument('1.0', 'UTF-8');
my $timeline_root = $timeline->createElement("timeline");
traverse($input_doc);
$timeline->setDocumentElement($timeline_root);
print $timeline->toString(2); # 2 means output with identation


sub convert_tag {
    my $node = shift;
    my $name = $node->nodeName;
    if ($name =~ /[cC]/) {
        $node->setNodeName('symptom');
    } elsif ($name =~ /[mM]/) {
        $node->setNodeName('treatnment');
    } else {
        $node->setNodeName('condition');
    }
}

sub copy_attributes {
    my $source = shift;
    my $dist = shift;
    map {
        /\s*(.+)="(.+)"/ or die "malformed attribute: $_";
        $dist->setAttribute($1, $2);
    } ($source->attributes());
}

sub proc_node {
    my ($text_acc_ref, $tag_acc_ref, $time_node_ref, $node) = @_;
        if ($node->nodeName eq $time_tag) {
            my $text = join '', @$text_acc_ref;
            if ($text !~ /^\s*$/) {
                # event
                my $event = $timeline->createElement('event');
                $event->setAttribute('date', $$time_node_ref->textContent());
                copy_attributes($$time_node_ref, $event);
                map {$event->appendChild($_)} @$tag_acc_ref;
                # text
                if (!$to_deter_original_text) {
                    my $textnode = $timeline->createElement('text');
                    $text =~ s/\n/ /g;
                    $textnode->appendText($text);
                    $event->appendChild($textnode);
                }
                # append to root
                $timeline_root->appendChild($event);
            }
            @$tag_acc_ref = ();
            @$text_acc_ref = ();
            $$time_node_ref = $node;
        } elsif ($node->nodeName eq '#text') {
            push @$text_acc_ref, $node->nodeValue;
        } elsif ($node->nodeName eq 'medtexts') {
            # do nothing
        } else {
            convert_tag($node);
            push @$tag_acc_ref, $node;
        }
}

sub traverse {
    my $input_doc = shift;
    my $root = $input_doc->getDocumentElement();
    my $node = $root;

    my @text_acc = ();
    my @tag_acc = ();
    my $time_node;

    while (1) {
        proc_node (\@text_acc, \@tag_acc, \$time_node, $node);

        # move node
        if ($node->hasChildNodes()) { # go down
            $node = $node->firstChild();
        } else {
            my $next_tmp = $node;
            my $next;
            while (1) { # go up until a sibling found or return if came back to root
                $next = $next_tmp->nextSibling();
                last if (defined $next);
                $next = $next_tmp->parentNode();
                if ($next->isEqual($root)) {return 1;} # found root
                $next_tmp = $next;
            }
            $node = $next;
        }
    }
}
