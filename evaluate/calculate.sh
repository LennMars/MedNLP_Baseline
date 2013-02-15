#!/bin/sh

BINDIR=~/workspace/MEDNLP/NTCIR/evaluate

ORIGCORPUSDIR=~/workspace/MEDNLP/NTCIR/distr/first_distributed

if [ $# -ne 2 ]; then
    echo "bad input"
    exit 1
fi

input=$2
dir=${input%/*}
file=${input##*/}
name=${file%.*}
ext=${file##*.}
evaldir=$dir/${name}_eval

rm -rf $evaldir
mkdir $evaldir

option=$1

if [ $option = "-c" ] || [ $option = "-b" ]; then
    $BINDIR/form_submission.pl -c < $input > $evaldir/${name}_c.$ext
    $BINDIR/form_submission.pl -c -r < $input > $evaldir/${name}_c_noattr.$ext

    $BINDIR/xml_to_charwise_iob.pl -mod \
        $ORIGCORPUSDIR/raw_test_modified_c.txt \
        $evaldir/${name}_c.$ext > $evaldir/${name}_c_cmp.txt
    $BINDIR/xml_to_charwise_iob.pl \
        $ORIGCORPUSDIR/raw_test_modified_c_noattr.txt \
        $evaldir/${name}_c_noattr.$ext > $evaldir/${name}_c_noattr_cmp.txt

    $BINDIR/conlleval.pl -d "\t" < $evaldir/${name}_c_cmp.txt \
        > $evaldir/${name}_c_eval.txt
    $BINDIR/conlleval.pl -d "\t" < $evaldir/${name}_c_noattr_cmp.txt \
        > $evaldir/${name}_c_noattr_eval.txt

    $BINDIR/get_from_eval.pl < $evaldir/${name}_c_eval.txt > $evaldir/${name}_c_eval_digits.txt
    $BINDIR/get_from_eval.pl < $evaldir/${name}_c_noattr_eval.txt > $evaldir/${name}_c_noattr_eval_digits.txt
fi
if [ $option = "-i" ] || [ $option = "-b" ]; then
    $BINDIR/form_submission.pl -i < $input > $evaldir/${name}_deid.$ext
    $BINDIR/xml_to_charwise_iob.pl -d2 1 \
        $ORIGCORPUSDIR/raw_test_modified_deid.txt \
        $evaldir/${name}_deid.$ext > $evaldir/${name}_deid_cmp.txt
    $BINDIR/conlleval.pl -d "\t" < $evaldir/${name}_deid_cmp.txt \
        > $evaldir/${name}_deid_eval.txt
    $BINDIR/get_from_eval.pl < $evaldir/${name}_deid_eval.txt > $evaldir/${name}_deid_eval_digits.txt
fi
