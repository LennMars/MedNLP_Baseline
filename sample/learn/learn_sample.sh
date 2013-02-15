#!/bin/sh

../../crf_data_gen/parse.pl -attr -d ../../corpus/dictionaries/SYN sample.xml > data.txt

crf_learn ../../templates/default data.txt model_sample
