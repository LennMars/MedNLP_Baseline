#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use Getopt::Long qw(:config posix_default no_ignore_case gnu_compat);
use File::Spec;
use File::Basename;
use FindBin qw($Bin);
binmode STDOUT, ":encoding(utf-8)";

if ($#ARGV == -1) {
    print "usage: experiment.pl [-d dict]... [-d1 depth] [-d2 depth] [-mod] [-h] [-c file] -m model input
-d dict: 特徴量に用いる辞書ファイル. 複数指定可能.
-d1/d2 depth: XML から IOB フォーマットへの変換時にこの値以上ネストしている所のみ出力する. デフォルト0.
-c file: file を正解 XML ファイルとして IOB フォーマットへの変換時に比較を行う.
-mod: -c 設定時のみ有効. 正解ファイル中の modality を考慮する.
-h: CRF 出力の評価用形式を読みやすい形にする
-m model: crf_test に渡す学習済みモデルファイル.
input: 入力プレーンテキスト.\n";
    exit 1;
}

my $model_file;
my @dictionary_files;
my $correct_xml_file;
my $start_depth_correct = 0;
my $start_depth_answer = 0;
my $to_output_modality = 0;
my $is_readable_cmp = 0;
GetOptions (
    'm=s' => \$model_file,
    'd=s' => \@dictionary_files,
    'c=s' => \$correct_xml_file,
    'd1=i' => \$start_depth_correct,
    'd2=i' => \$start_depth_answer,
    'mod' => \$to_output_modality,
    'h' => \$is_readable_cmp
    );

die "model file (-m) needed" unless ($model_file);

my $dictionaries_str = join ' ', (map {'-d ' . $_} @dictionary_files);
my ($input_file, $input_dir) = fileparse(File::Spec->rel2abs($ARGV[0]));
my $outdir = "${input_file}_test";
mkdir "$outdir" or die "cannot make directory $input_file";

print "get_feature.pl running...\n";
system("$Bin/../crf_data_gen/get_feature.pl $dictionaries_str $input_dir/$input_file > $outdir/feature.txt");

print "crf_test running...\n";
system("crf_test -m $model_file $outdir/feature.txt > $outdir/crfout.txt");

print "crfout_to_xml running...\n";
system("$Bin/crfout_to_xml.pl < $outdir/crfout.txt > $outdir/crfout.xml");

my $output_modality_option = $to_output_modality ? '-mod' : '';
my $readable_cmp_option = $is_readable_cmp ? '-h' : '';
if ($correct_xml_file) {
    print "xml_to_charwise_iob.pl running...\n";
    system "$Bin/xml_to_charwise_iob.pl -d1 $start_depth_correct -d2 $start_depth_answer $output_modality_option $readable_cmp_option $correct_xml_file $outdir/crfout.xml > $outdir/cmp.txt";
}
