#!/usr/bin/perl -w
use strict;
use utf8;
use XML::LibXML;
use MeCab;
#see http://d.hatena.ne.jp/tagomoris/20120918/1347991165 for this configuration
use Getopt::Long qw(:config posix_default no_ignore_case gnu_compat);
use Encode;
use HTML::Entities;
use FindBin;
use lib "$FindBin::Bin";
use MednlpFeature;
binmode STDOUT, ":encoding(utf-8)";

if ($#ARGV < 0) {die "Usage: parse.pl [-tag t1,t2,...] [-notag t1,t2,...] [-attr] [-d dict]... input.xml\n";}

# command line option handling
my @output_tags = ('mn', 'ms', 'm', 'a', 't', 'h', 'l', 'x', 'd', 'cn', 'cs', 'c', 'C', 'H', 'LOC', 'M', 'M1', 'T', 'T1', 'X'); # default tags to output
my @no_output_tags = (); # exclusion

my $to_use_modality = 0;

my %tag_conversion = (); #("d" => "c"); # d tag is interpreted as c tag.
my %attr_value_conversion = ("予" => "negation", "必" => "negation", "方" => "negation", "目" => "negation", "適" => "negation", "希" => "negation", "稀" => "negation", "勧" => "negation", "希_neg" => "negation");
my @dictionary_files;

GetOptions ('tag=s' => \@output_tags, 'notag=s' => \@no_output_tags, 'attr' => \$to_use_modality, 'd=s' => \@dictionary_files);

die "Missing filename." if (!$ARGV[0]);


my $doc = input_as_xml($ARGV[0]);
my $text = input_as_str($ARGV[0]);
my $pos_in_text = 0;

init_output_tags();
my @dictionaries = init_dictionaries(\@dictionary_files);
init_word_intervals($text, \@dictionaries);


&traverse($doc);


sub input_as_xml {
    my $filename = shift;
    my $parser = XML::LibXML->new();
    return $parser->parse_file($filename);
}

sub input_as_str {
    my $filename = shift;
    open INPUT, $filename or die;
    binmode INPUT, ":encoding(utf-8)";
    my @input = <INPUT>;
    return join '', @input;
}

sub init_output_tags {
    @output_tags = split(/,/,join(',',@output_tags));
    @no_output_tags = split(/,/,join(',',@no_output_tags));

    # remove elements of @no_output_tags from @output_tags
    @output_tags = grep {
        my $x = $_;
        my $found = grep /^$x$/, @no_output_tags;
        ! $found} @output_tags;
}

sub iob_sequence_to_string {
    my $iobs_ref = shift;
    my @iob_strs = map {
        my @iob = @$_;
        @iob = map {(defined && $_ ne '') ? $_ : '*'} @iob; # avoid empty column
        join ' ', @iob;
    } (@$iobs_ref);
    return join "\n", @iob_strs;
}

sub get_iob_sequence {
    my ($type, $string) = @_;
    if (exists $tag_conversion{$type}) {$type = $tag_conversion{$type};}

    my $mecab = MeCab::Tagger->new();
    my $node = $mecab->parseToNode($string);

    my @iobs;
    my $is_first = 1;
    for ( ; $node; $node = $node->{next}) { # for each morpheme
        my ($class1, $class2, $read) =
            map {decode("utf-8", $_)} (split(/,/, $node->{feature}))[0, 1, 7];
        # skip begin and end in the result of morphological analysis
        next if ($class1 =~ /BOS|EOS/);

        my $surface = decode("utf8", $node->{surface});
        my $pos_temp = index($text, $surface, $pos_in_text);
        my $iobs_from_dict_str = bio_from_intervals($pos_temp);
        my $letter_type = letter_type($surface);
        my $last_char = substr $surface, -1;

        # forward position
        $pos_in_text = $pos_temp + length($surface);
        while (substr($text, $pos_in_text, 1) eq '<') {
            $pos_in_text = index($text, '>', $pos_in_text) + 1;
        }

        my $tag = ($type eq 'O') ? 'O' : ($is_first ? "B-${type}" : "I-${type}");
        $is_first = 0;
        my @iob = ($surface, $class1, $class2, $read, $iobs_from_dict_str, $letter_type, $last_char, $tag);
        push @iobs, \@iob;
    }

    return \@iobs;
}

sub get_modality {
    my $node = shift;
    my $name = $node->nodeName();
    if ($to_use_modality) {
        my @attrs = $node->attributes();
        my $modality;
        foreach (@attrs) {
            if (/modality="(.+)"/) {
                $modality = decode_entities($1);
                if (exists $attr_value_conversion{$modality}) {
                    $modality = $attr_value_conversion{$modality};
                }
            }
        }
        if ($modality) {$name = $name . '-' . $modality;}
    }
    return $name;
}

# print if an appriptiate tag found
sub print_leaf {
    my $node = shift;
    my $name = $node->nodeName();

    if (grep {$name =~ /^$_$/} @output_tags) {
        my $iobs = get_iob_sequence(get_modality($node), $node->textContent);
        my $str = iob_sequence_to_string $iobs;
        print "$str\n";
    } else {
        my $parent_name = $node->parentNode()->nodeName();
        unless ($node->hasChildNodes() || grep {$parent_name =~ /^$_$/} @output_tags) {
            my $content = $node->textContent;
            $content =~ s/^\s+//;
            my @contents = split "\n+", $content;
            my @strs = map {
                my $iobs = get_iob_sequence('O', $_);
                iob_sequence_to_string $iobs;
            } @contents;
            my $output = join "\n\n", @strs;
            print $output;
            print ($node->textContent =~ /\n$/ ? "\n\n" : "\n") if $output;
        }
    }
}

sub traverse {
    my $doc = shift;
    my $root = $doc->getDocumentElement();
    my $node = $root;
    while (1) {
        print_leaf $node;

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
