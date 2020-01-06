#!/bin/bash

#
# Author: Laurens van der Werff (University of Twente)
#
# Apache 2.0
#

#
#   Decode audio files to produce transcriptions and additional info in a target directory
#
#		Usage: ./decode.sh [options] <speech-dir>|<speech-file>|<txt-file containing list of source material> <output-dir>
#
#   Use the configure.sh script to prepare this decode.sh script
#
# 	All input files that are specified on the command-line are linked or copied to a working directory, which is
#	<output-dir>/intermediate/data. From here, all files with a chosen extension (default wav, mp3) are
#	used as input for the Kaldi speech transcription.
#
#	If the following file types are present in the working (input) directory, they will be
#	automatically applied:
#
#   .ubm:	defines the sections in the files that should be transcribed
#	.stm:	transcriptions for evaluation purposes. If present, asclite will be invoked	to evaluate the results (case insensitive)
#	.glm:	contains definitions for use by csrfilt.sh (part of sctk in the kaldi/tools directory), which are applied
#			to the transcription
#
#	In case you want/need to copy all source materials, make sure there is enough space available in the target location.
#	Files are identified by their base filename, so there must be no duplicate names in a batch!
#
#   The procedure is as follows:
#		1.	All source files which are specified on the command line are copied or linked to <output-dir>/intermediate/data
#     	 	This directory is scanned for audio, which is then processed by the LIUM speaker diarization tool so as to produce
#			chunks of up to 20 seconds in length.
#			The LIUM segmentations are then processed to create the files needed for Kaldi:
#				wav.scp, segments, utt2spk, spk2utt, spk2gender
#		2. 	MFCC features and CMVN stats are generated.
#		3.	Speech transcription is performed. The type of recognizer is selected with the configure.sh script.
#		4.	The resulting lattices are optionally rescored using a larger 4-gram language model.
#		5.	1-best transcriptions are extracted from the rescored lattices and results are gathered into 1Best.ctm which contains
#			all of the transcriptions. The segmentation from (1) is then used to create a 1Best.txt file.
# 		6.	If a reference transcription (.stm) is available, an evaluation is performed using asclite. Results of the evalluation can then be
#			found in <output-dir>/1Best.ctm.{dtl,pra,sys}
#

set -a

cmd=run.pl
nj=8                   # maximum number of simultaneous jobs used for feature generation and decoding
stage=1
numthreads=1           # used for decoding

file_types="wav mp3"			# file types to include for transcription
splittext=true
dorescore=true			# rescore with largeLM as default
copyall=false			# copy all source files (true) or use symlinks (false)
overwrite=true			# overwrite the 1st pass output if already present
multichannel=false
inv_acoustic_scale="11"    # used for 1-best and N-best generation
nbest=0					  # if value >0, generate NBest.ctm with this amount of transcription alternatives
word_ins_penalty="-1.0"   # word insertion penalty
beam=7
decode_mbr=true
miac=
mwip=

model=models/AM
lmodel=models/LM/LM_OH_3gpr.gz
lpath=models/Lang_OH
llmodel=models/LM/LM_OH_4gpr.gz
llpath=models/LM/Const_OH
extractor=



symtab=$lpath/words.txt
wordbound=$lpath/phones/word_boundary.int
[ "$llpath" ] && symtab=$llpath/words.txt && wordbound=$llpath/phones/word_boundary.int

[ -f ./path.sh ] && . ./path.sh; # source the path.

. parse_options.sh || exit 1;

if [ $# -lt 2 ]; then
    echo "Wrong #arguments ($#, expected 2)"
    echo "Usage: decode.sh [options] <source-dir|source files|txt-file list of source files> <decode-dir>"
    echo "  "
    echo "main options (for others, see top of script file)"
    echo "  --config <config-file>             # config containing options"
    echo "  --nj <nj>                          # maximum number of parallel jobs"
    echo "  --cmd <cmd>                        # Command to run in parallel with"
	if [ ! -z ${acwt+x} ]; then
    	echo "  --acwt <acoustic-weight>                 # value is ${acwt} ... used to get posteriors"
    fi
    echo "  --inv-acoustic-scale               # used for 1-best and N-best generation, may have multiple values, value is $inv_acoustic_scale"
    echo "  --word-ins-penalty                 # used for 1-best generation, may have multiple values, value is $word_ins_penalty"
    echo "  --num-threads <n>                  # number of threads to use, value is 1."
    echo "  --file-types <extensions>          # include audio files with the given extensions, default \"wav mp3\" "
    echo "  --copyall <true/false>             # copy all source files (true) or use symlinks (false), value is $copyall"
    echo "  --splittext <true/false>           # split resulting 1Best.txt into separate .txt files for each input file, value is $splittext"
    exit 1;
fi

result=${!#}
inter="${result}/intermediate"
data="${inter}/data"
logging="${inter}/log"
rescore=$inter/decode

[ `echo $inv_acoustic_scale | wc -w` -gt 1 ] && miac=true
[ `echo $word_ins_penalty | wc -w` -gt 1 ] && mwip=true

set +a

mkdir -p $inter
timer="$(which time) -o $inter/time.log -f \"%e %U %S %M\""
cp decode_OH.sh $inter/decode.sh			# Make a copy of this file and..
echo "$0 $@" >$logging      # ..print the command line for logging

## data prep
if [ $stage -le 3 ]; then
	local/decode_prepdata.sh $@
fi

# determine maximum number of jobs for this feature generation and decoding
numspeak=$(cat $data/ALL/spk2utt | wc -l)
if (( $numspeak == 0 )); then echo "No speech found, exiting."; exit
elif (( $nj > $numspeak )); then this_nj=$numspeak; echo "Number of speakers is less than $nj, reducing number of jobs to $this_nj"
else this_nj=$nj
fi

## feature generation
if [ $stage -le 5 ]; then
	echo "Feature generation" >$inter/stage
	[ -e $model/mfcc.conf ] && cp $model/mfcc.conf $inter 2>/dev/null
	[ -e $model/conf/mfcc.conf ] && cp $model/conf/mfcc.conf $inter 2>/dev/null
	steps/make_mfcc.sh --nj $this_nj --mfcc-config $inter/mfcc.conf $data/ALL $data/ALL/log $inter/mfcc >>$logging 2>&1
	steps/compute_cmvn_stats.sh $data/ALL $data/ALL/log $inter/mfcc >>$logging 2>&1

fi

## decode
if [ $stage -le 6 ]; then
	echo "Decoding" >$inter/stage
	echo -n "Duration of speech: "
	cat $data/ALL/segments | awk '{s+=$4-$3} END {printf("%.0f", s)}' | local/convert_time.sh
	totallines=$(cat $data/ALL/segments | wc -l)
	rm -r -f ${inter}/decode
	tmp_decode=$result/tmp/ && mkdir -p $tmp_decode
	tmp=`mktemp -d -p $tmp_decode`
	cp -r models/AM/conf models/AM/final.mdl models/AM/frame_subsampling_factor $tmp_decode
	eval $timer steps/online/nnet3/decode.sh --nj $this_nj --acwt 1.2 --post-decode-acwt 10.0 --skip-scoring true $model/graph_OH $data/ALL $tmp >>$logging 2>&1 &
	pid=$!
 	while kill -0 $pid 2>/dev/null; do
 		linesdone=$(cat $tmp/log/decode.*.log 2>/dev/null | grep "Decoded utterance" | wc -l)
 		local/progressbar.sh $linesdone $totallines 50 "NNet3 Decoding"
 		sleep 2
 	done
	tail -1 $inter/time.log | awk '{printf( "NNet3 decoding completed in %d:%02d:%02d (CPU: %d:%02d:%02d), Memory used: %d MB                \n", int($1/3600), int($1%3600/60), int($1%3600%60), int(($2+$3)/3600), int(($2+$3)%3600/60), int(($2+$3)%3600%60), $4/1000) }'

	mv -f $tmp ${inter}/decode
	rm -r $tmp_decode

fi

## rescore
if [ $stage -le 7 ] && [ $llmodel ] && [ -e $inter/decode/num_jobs ]; then
	echo "Rescoring" >$inter/stage
	numjobs=$(< $inter/decode/num_jobs)
	eval $timer steps/lmrescore_const_arpa.sh --skip-scoring true $lpath $llpath $data/ALL $inter/decode $inter/rescore >>$logging 2>&1 &
	pid=$!
	spin='-\|/'
	i=0
 	while kill -0 $pid 2>/dev/null; do
 		i=$(( (i+1) %4 ))
   		printf "\rRescoring.. ${spin:$i:1}"
   		sleep .2
 	done
	cat $inter/time.log | awk '{printf("\rRescoring completed in %d:%02d:%02d (CPU: %d:%02d:%02d), Memory used: %d MB                \n", int($1/3600), int($1%3600/60), int($1%3600%60), int(($2+$3)/3600), int(($2+$3)%3600/60), int(($2+$3)%3600%60), $4/1000) }'
	rescore=$inter/rescore
fi

[ $llmodel ] && rescore=$inter/rescore

## create readable output
if [ $stage -le 8 ] && [ -e $rescore/num_jobs ]; then
	echo -e "Producing output" >$inter/stage

	frame_shift_opt=
	rm -f $data/ALL/1Best.* $result/1Best* $rescore/1Best.*

	numjobs=$(< $rescore/num_jobs)

	if [ -f $model/frame_shift ]; then
		frame_shift_opt="--frame-shift=$(cat $model/frame_shift)"
	elif [ -f $model/frame_subsampling_factor ]; then
		factor=$(cat $model/frame_subsampling_factor) || exit 1
		frame_shift_opt="--frame-shift=0.0$factor"
	fi

	# produce 1-Best with confidence
	for iac in $inv_acoustic_scale; do
		for wip in $word_ins_penalty; do
			ident=
			[ $mwip ] && ident="$wip."
			[ $miac ] && ident="$ident$iac."
			$cmd --max-jobs-run $nj JOB=1:$numjobs $inter/l2c_log/lat2ctm.${ident}JOB.log \
				gunzip -c $rescore/lat.JOB.gz \| \
				lattice-push ark:- ark:- \| \
				lattice-add-penalty --word-ins-penalty=$wip ark:- ark:- \| \
				lattice-align-words $wordbound $model/final.mdl ark:- ark:- \| \
				lattice-to-ctm-conf $frame_shift_opt --inv-acoustic-scale=$iac ark:- - \| utils/int2sym.pl -f 5 $symtab \| \
				local/ctm_time_correct.pl $data/ALL/segments \| sort \> $rescore/1Best.${ident}JOB.ctm | exit 1;
			cat $rescore/1Best.${ident}*.ctm >$rescore/1Best_raw.${ident}ctm

			cat $rescore/1Best_raw.${ident}ctm | sort -k1,1 -k3,3n | local/remove_hyphens.pl | \
				perl local/combine_numbers.pl | sort -k1,1 -k3,3n | local/compound-restoration.pl 2>>$logging | \
				grep -E --text -v 'uh|<unk>' >$result/1Best.${ident}ctm
			[ -s $data/ALL/all.glm ] && mv $result/1Best.${ident}ctm $rescore/1Best_prefilt.${ident}ctm && \
				cat $rescore/1Best_prefilt.${ident}ctm | csrfilt.sh -s -i ctm -t hyp $data/ALL/all.glm >$result/1Best.${ident}ctm

			local/ctmseg2sent.pl $result $splittext $ident
		done
	done
fi

## score if reference transcription exists
if [ $stage -le 9 ] && [ -s $data/ALL/ref.stm ]; then
	echo -e "Scoring" >$inter/stage
	# score using asclite, then produce alignments and reports using sclite
	[ -s $data/ALL/test.uem ] && uem="-uem $data/ALL/test.uem"
	for iac in $inv_acoustic_scale; do
		for wip in $word_ins_penalty; do
			ident=
			[ $mwip ] && ident="$wip."
			[ $miac ] && ident="$ident$iac."
			asclite -D -noisg -r $data/ALL/ref.stm stm -h $result/1Best.${ident}ctm ctm $uem -o sgml >>$logging 2>&1
			cat $result/1Best.${ident}ctm.sgml | sclite -P -o sum -o pralign -o dtl -n $result/1Best.${ident}ctm  >>$logging 2>&1
			[ $(cat $result/1Best.${ident}ctm.sys | grep 'MS\|FS\|MT\|FT' | wc -l) -gt 0 ] && local/split_results.sh $result/1Best.${ident}ctm.sys $result/1Best.${ident}ctm.sys.split
		done
	done
fi

echo -e "Done" >$inter/stage
echo "Done"
