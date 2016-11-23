#!/bin/bash

#
# Convert an ARPA language model, plus a lexicon/dictionary file into
# an fst language model (L and G) for use in Kaldi (to be combined into an HCLG graph
# by mkgraph).
#
# Usage: Arpa2LG.sh <arpa LM> <lexicon> <output directory>
#

export LC_ALL="C"				# important for consistent sort of phonemes

if [ $# != 3 ]; then
    echo "Convert Arpa LM and Lexicon into L and G for use by Kaldi."
    echo
    echo "Wrong #arguments ($#, expected 3)"
    echo "Usage: Arpa2LG.sh <arpa LM> <lexicon> <output-dir>"
    exit 1;
fi

arpalm=$1
dict=$2
outdir=$3
dictdir=$outdir/dicttemp
langtmp=$outdir/langtemp
langdir=$outdir/lang

mkdir -p $outdir $dictdir

# make some preparations
cat $dict | sort | local/normalize_lexicon_probs.pl >$dictdir/lexiconp.txt
echo -e "<unk>\t1.000000\t[SPN]" >>$dictdir/lexiconp.txt         # spoken noise is <unk>
echo SIL >$dictdir/silence_phones.txt
echo SIL >$dictdir/optional_silence.txt
cat $dictdir/lexiconp.txt | awk -F'\t' '{print $3}' | sed 's/ /\n/g' | sort | uniq >$dictdir/nonsilence_phones.txt
touch $dictdir/extra_questions.txt

# create L.fst
utils/prepare_lang.sh --phone-symbol-table $outdir/phones.txt $dictdir "<unk>" $langtmp $langdir || exit 1;

# create G.fst
utils/format_lm.sh $langdir $arpalm $dict $outdir
