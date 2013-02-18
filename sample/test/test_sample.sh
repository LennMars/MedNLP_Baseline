#!/bin/sh

if [ -z `which crf_learn` ]; then
    echo "CRF++ needed."
    exit 1
fi

if [ ! -f ../../models/mednlp.model ]; then
    echo "model file not found. fetching..."
    if [ ! -d ../../models ]; then
        mkdir ../../models
    fi
    wget http://mednlp.jp/NTCIR10/mednlp.model -O ../../models/mednlp.model
fi

outdir='test_sample'

if [ -d test_sample ]; then
    rm -r $outdir
fi

mkdir $outdir

echo "generating features."
../../crf_data_gen/get_feature.pl -d ../../corpus/dictionaries/SYN ./sample.txt > $outdir/feature.txt

echo "calling crf_test."
crf_test -m ../../models/mednlp.model $outdir/feature.txt > $outdir/crfout.txt

echo "converting CRF++ output into XML format."
../../evaluate/crfout_to_xml.pl < $outdir/crfout.txt > $outdir/crfout.xml

echo "comparing output with correct tagging."
../../evaluate/xml_to_charwise_iob.pl -mod -h ../../sample/learn/sample.xml $outdir/crfout.xml > $outdir/cmp.txt

echo "done.\n"

cat $outdir/crfout.xml