#!/bin/bash

#
# Author: Laurens van der Werff (University of Twente)
#         >2020 (heavily adapted by Maarten van Gompel (CLST, Radboud University Nijmegen))
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

# shellcheck disable=SC2002
# ^-- allow the use of cat file | cmd   (rather than cmd < file)
# shellcheck disable=SC1091
# ^-- don't attempt fo follow includes

VERSION="0.3"

# auto-export all variables
set -a

# exit a pipeline with a non-zero exit code if any part of it fails
set -o pipefail

die() {
	echo "-------------------------------------------------" >&2
	echo "ERROR: $*" >&2
	echo "-------------------------------------------------" >&2
	[ -n "$logging" ] && echo "(you can inspect the log at $logging for details)" >&2
	exit 2
}

log() {
	if [ -n "$logging" ]; then
		echo -e "$*" | tee -a "$logging" >&2
	else
		echo -e "$*" >&2
	fi
}

logtitle() {
	log "\n=========================="
	if [ -n "$inter" ]; then
		echo "$@" > "$inter/stage"
	fi
	log "$@"
	log "=========================="
}

[ -n "$cmd" ] || cmd="run.pl"
[ -n "$nj" ] || nj=8                               # maximum number of simultaneous jobs used for feature generation and decoding
[ -n "$stage" ] || stage=1
[ -n "$numthreads" ] || numthreads=1               # used for decoding
[ -n "$file_types" ] || file_types="wav mp3"       # file types to include for transcription
[ -n "$splittext" ] || splittext=true
[ -n "$dorescore" ] || dorescore=true              # rescore with largeLM as default
[ -n "$copyall" ] || copyall=false                 # copy all source files (true) or use symlinks (false)
[ -n "$overwrite" ] || overwrite=true              # overwrite the 1st pass output if already present
[ -n "$multichannel" ] || multichannel=true
[ -n "$nbest" ] || nbest=0                         # if value >0, generate NBest.ctm with this amount of transcription alternatives
[ -n "$inv_acoustic_scale" ] || inv_acoustic_scale="11"  # used for 1-best and N-best generation
[ -n "$word_ins_penalty" ] || word_ins_penalty="-1.0" # word insertion penalty
[ -n "$beam" ] || beam=7
[ -n "$decode_mbr" ] || decode_mbr=true

[ -n "$model" ] || die "This script must be sourced, missing: \$model"
[ -n "$graph" ] || graph="$model/graph"
[ -n "$lmodel" ] || die "This script must be sourced, missing: \$lmodel"
[ -n "$llmodel" ] || die "This script must be sourced, missing: \$llmodel"   #this variable does not exist in the decode_template
[ -n "$lpath" ] || die "This script must be sourced, missing: \$lpath"
[ -n "$llpath" ] || die "This script must be sourced, missing: \$llpath"

symtab="$lpath/words.txt"
wordbound="$lpath/phones/word_boundary.int"
[ -e "$llpath" ] && symtab="$llpath/words.txt" && wordbound="$llpath/phones/word_boundary.int"

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
	if [ -n "${acwt}" ]; then
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
if [[ "$model" = *" "* ]]; then
	die "Model path ($model) may not contain any spaces!"
fi
if [[ "$result" = *" "* ]]; then
	die "Output path ($result) may not contain any spaces!"
fi
[ "$(echo "$inv_acoustic_scale" | wc -w)" -gt 1 ] && miac=true
[ "$(echo "$word_ins_penalty" | wc -w)" -gt 1 ] && mwip=true

# stop auto-exporting all variables
set +a

inter="${result}/intermediate"
data="${inter}/data"
logging="${inter}/log"
rescore=$inter/decode


mkdir -p $inter || die "unable to create intermediate directory $inter"
timer="$(which time)" #This is not the shell's time function but GNU time! needs to be installed explicitly or you get weird errors!
if [ -z "$timer" ]; then
    die "GNU time not found  (apt install time)"
fi
timer="$timer -o $inter/time.log -f \"%e %U %S %M\""
scriptname="$(readlink -f "$0")" #the invoked script
includescriptname="$(readlink -f "${BASH_SOURCE[0]}")" #this sources script
cp -f "$scriptname" "$inter/decode.sh" || die "error copying decode.sh ($scriptname)"		# Make a copy of this file and..
cp -f "$includescriptname" "$inter/decode_include.sh" || die "error copying decode_include.sh ($includescriptname)"		# Make a copy of this file and..
date=$(date)
echo "(starting log at $date)" | tee "$logging" >&2
logtitle "Kaldi-NL v$VERSION"
log "    https://github.com/opensource-spraakherkenning-nl/Kaldi_NL"
log ""
log "Command: $0 $*" # ..print the command line
log "Intermediate directory: $inter"
log "Output directory: $result"
log "Log: $logging"

## data prep
if [ $stage -le 3 ]; then
	echo -e "\n==========================">&2
	echo "Data Preparation" | tee "$inter/stage" >&2
	echo "==========================">&2
	source local/decode_prepdata.sh || die "Data preparation failed"
fi

# determine maximum number of jobs for this feature generation and decoding
numspeak=$(cat $data/ALL/spk2utt | wc -l)
if (( numspeak == 0 )); then die "No speech found, exiting."
elif (( nj > numspeak )); then this_nj=$numspeak; echo "Number of speakers is less than $nj, reducing number of jobs to $this_nj" >&2
else this_nj=$nj
fi

## feature generation
if [ $stage -le 5 ]; then
	logtitle "Feature generation"
	[ -e "$model/mfcc.conf" ] && cp "$model/mfcc.conf" "$inter" 2>/dev/null
	[ -e "$model/conf/mfcc.conf" ] && cp "$model/conf/mfcc.conf" "$inter" 2>/dev/null
	steps/make_mfcc.sh --nj "$this_nj" --mfcc-config "$inter/mfcc.conf" "$data/ALL" "$data/ALL/log" "$inter/mfcc" 2>&1 | tee -a $logging >&2 || die "feature generation failed"
	steps/compute_cmvn_stats.sh "$data/ALL" "$data/ALL/log" "$inter/mfcc" 2>&1 | tee -a "$logging" >&2 || die "compute CMVN stats failed"
fi

## decode
if [ $stage -le 6 ]; then
	logtitle "Decoding"
	echo -n "Duration of speech: " >&2
	cat "$data/ALL/segments" | awk '{s+=$4-$3} END {printf("%.0f", s)}' | local/convert_time.sh
	rm -r -f "${inter}/decode"
	tmp_decode=$result/tmp/ && mkdir -p "$tmp_decode"
	tmp=$(mktemp -d -p "$tmp_decode")
	cp -r models/AM/conf models/AM/final.mdl models/AM/frame_subsampling_factor "$tmp_decode"


	echo "Running decoder, this may take a long time...." | tee -a $logging >&2
	failed=0
	eval "$timer" steps/online/nnet3/decode.sh --nj "$this_nj" --acwt 1.2 --post-decode-acwt 10.0 --skip-scoring true "$graph" "$data/ALL" "$tmp" | tee -a "$logging" >&2 || failed=1  #the return code will usually be 0 even if things go wrong, because a job system may be in the way
	mv -f "$tmp" "${inter}/decode"
	if [ ! -e "${inter}/decode/lat.${this_nj}.gz" ] || [ $failed -eq 1 ]; then
		echo -e "NNET3 DECODING FAILED! Log follows:\n===========================\nNNET 3 DECODE LOG\n=========================" >&2
		cat "${inter}/decode/log/decode.${this_nj}.log" >&2
		tail -1 "$inter/time.log" | awk '{printf( "NNet3 decoding *FAILED* in %d:%02d:%02d (CPU: %d:%02d:%02d), Memory used: %d MB                \n", int($1/3600), int($1%3600/60), int($1%3600%60), int(($2+$3)/3600), int(($2+$3)%3600/60), int(($2+$3)%3600%60), $4/1000) }'
		die "Decoding failed, inspect decode log above"
	fi
	tail -1 $inter/time.log | awk '{printf( "NNet3 decoding completed in %d:%02d:%02d (CPU: %d:%02d:%02d), Memory used: %d MB                \n", int($1/3600), int($1%3600/60), int($1%3600%60), int(($2+$3)/3600), int(($2+$3)%3600/60), int(($2+$3)%3600%60), $4/1000) }'

	rm -r $tmp_decode

fi

## rescore
if [ $stage -le 7 ] && [ -e "$llmodel" ] && [ -e "$inter/decode/num_jobs" ]; then
	logtitle "Rescoring"
	numjobs=$(< $inter/decode/num_jobs)
	eval "$timer" steps/lmrescore_const_arpa.sh --skip-scoring true "$lpath" "$llpath" "$data/ALL" "$inter/decode" "$inter/rescore" | tee -a "$logging" 2>&1 &
	pid=$!
	spin='-\|/'
	i=0
	while kill -0 $pid 2>/dev/null; do
		i=$(( (i+1) %4 ))
		printf "\rRescoring.. %s" "${spin:$i:1}"
		sleep .2
	done
	cat "$inter/time.log"| awk '{printf("\rRescoring completed in %d:%02d:%02d (CPU: %d:%02d:%02d), Memory used: %d MB                \n", int($1/3600), int($1%3600/60), int($1%3600%60), int(($2+$3)/3600), int(($2+$3)%3600/60), int(($2+$3)%3600%60), $4/1000) }'
	rescore="$inter/rescore"
fi

[ -e "$llmodel" ] && rescore="$inter/rescore"

## create readable output
if [ $stage -le 8 ] && [ -e "$rescore/num_jobs" ]; then
	logtitle "Producing output"

	frame_shift_opt=
	rm -f "$data"/ALL/1Best.* "$result"/1Best* "$rescore"/1Best.*

	numjobs=$(< $rescore/num_jobs)
	[ -z "$numjobs" ] && numjobs=1

	if [ -f "$model/frame_shift" ]; then
		frame_shift_opt="--frame-shift=$(cat "$model/frame_shift")"
	elif [ -f "$model/frame_subsampling_factor" ]; then
		factor=$(cat "$model/frame_subsampling_factor") || exit 1
		frame_shift_opt="--frame-shift=0.0$factor"
	fi

	# produce 1-Best with confidence
	for iac in $inv_acoustic_scale; do
		for wip in $word_ins_penalty; do
			ident=
			[ $mwip ] && ident="$wip."
			[ $miac ] && ident="$ident$iac."
			$cmd --max-jobs-run $nj "JOB=1:$numjobs" "$inter/l2c_log/lat2ctm.${ident}JOB.log" \
				gunzip -c $rescore/lat.JOB.gz \| \
				lattice-push ark:- ark:- \| \
				lattice-add-penalty --word-ins-penalty=$wip ark:- ark:- \| \
				lattice-align-words "$wordbound" "$model/final.mdl" ark:- ark:- \| \
				lattice-to-ctm-conf "$frame_shift_opt" --inv-acoustic-scale=$iac ark:- - \| utils/int2sym.pl -f 5 "$symtab" \| \
				local/ctm_time_correct.pl $data/ALL/segments \| sort \> $rescore/1Best.${ident}JOB.ctm | exit 1;
			cat $rescore/1Best.${ident}*.ctm >$rescore/1Best_raw.${ident}ctm || die "Command produced no viable output: $cmd"

			cat $rescore/1Best_raw.${ident}ctm | sort -k1,1 -k3,3n | local/remove_hyphens.pl | \
				perl local/combine_numbers.pl | sort -k1,1 -k3,3n | local/compound-restoration.pl 2>>$logging | \
				grep -E --text -v 'uh|<unk>' >$result/1Best.${ident}ctm || die "Postprocesing raw CTM into final CTM failed"
            [ ! -e "$result/1Best.${ident}ctm" ] && die "Failed to generate expected output $result/1Best.${ident}ctm"
			[ -s $data/ALL/all.glm ] && mv $result/1Best.${ident}ctm $rescore/1Best_prefilt.${ident}ctm && \
                (cat $rescore/1Best_prefilt.${ident}ctm | csrfilt.sh -s -i ctm -t hyp "$data/ALL/all.glm" >"$result/1Best.${ident}ctm" 2>&1 | tee -a $logging >&2 || die "Filtering 1Best.ctm failed (csrfilt.sh)")

			local/ctmseg2sent.pl "$result" "$splittext" "$ident" 2>&1 | tee -a $logging >&2 || die "ctmseg2sent failed"
		done
	done
fi

## score if reference transcription exists
if [ $stage -le 9 ] && [ -s "$data/ALL/ref.stm" ]; then
	logtitle "Scoring"
	if grep -q "returned err code" "$data/ALL/ref.stm"; then
		log "WARNING: Unable to score, $data/ALL/ref.stm does not hold valid reference data"
	else
		# score using asclite, then produce alignments and reports using sclite
		[ -s "$data/ALL/test.uem" ] && uem="-uem $data/ALL/test.uem"
		for iac in $inv_acoustic_scale; do
			for wip in $word_ins_penalty; do
				ident=
				[ $mwip ] && ident="$wip."
				[ $miac ] && ident="$ident$iac."
				asclite -D -noisg -r "$data/ALL/ref.stm" stm -h "$result/1Best.${ident}ctm" ctm "$uem" -o sgml 2>&1 | tee -a "$logging" >&2
				cat "$result/1Best.${ident}ctm.sgml" | sclite -P -o sum -o pralign -o dtl -n $result/1Best.${ident}ctm 2>&1  | tee -a "$logging" >&2
				[ -e "$result/1Best.${ident}ctm.sys" ] && [ "$(cat "$result/1Best.${ident}ctm.sys" | grep -c 'MS\|FS\|MT\|FT')" -gt 0 ] && local/split_results.sh "$result/1Best.${ident}ctm.sys" "$result/1Best.${ident}ctm.sys.split"
			done
		done
	fi

	#add an output variant without the scores
	for iac in $inv_acoustic_scale; do
		for wip in $word_ins_penalty; do
			ident=
			[ $mwip ] && ident="$wip."
			[ $miac ] && ident="$ident$iac."
			cat $result/1Best.${ident}txt | cut -d'(' -f 1 > $result/1Best_plain.${ident}txt
		done
	done
fi

if [ -z "$mwip" ] && [ -z "$miac" ]; then
	#these parts of the pipeline only work when idents are not used (mwip/miac are unset)

	if [ ! -f "$result/1Best.ctm" ]; then
		die "Expected output file $result/1Best.ctm not found after decoding!"
	fi

	## convert to XML if output exists
	if [ $stage -le 10 ] && [ -s "$result/1Best.ctm" ] && [ -x ./scripts/ctm2xml.py ];
	then
		logtitle "Conversion to XML"
		./scripts/ctm2xml.py "$result" "1Best" "$data" || die "ctm2xml failed"
	fi

	## process speaker diarisation output
	if [ $stage -le 11 ] && [ -s "$result/liumlog/segmentation.1.log" ] && [ -x ./scripts/addspkctm.py ];
	then
		logtitle "Processing speaker diarisation output"

		segments="$(cat "$data/ALL/segments" | cut -d " " -f 2 | sort | uniq)"
		for segment in $segments; do
			# Create .rttm
			spkr_seg="$result/liumlog/$segment.seg"
			cat "$spkr_seg" | sed -n '/;;/!p' | sort -nk3 | awk '{printf "SPEAKER %s %s %.2f %.2f <NA> <NA> %s <NA>\n", $1, $2, ($3 / 100), ($4 / 100), $8}' > "$result/$segment.rttm" || die "Failure creating RTTM file from speaker diarisation output"

			# Create .ctm with speaker ids
			./scripts/addspkctm.py "$result/$segment.rttm" "$result/1Best.ctm" || die "Failure adding speakers to CTM"
		done
	fi

	if [ $stage -le 12 ] && [ -s "$result/liumlog/segmentation.1.log" ] && [ -x ./scripts/wordpausestatistic.perl ]; then
		logtitle "Adding sentence boundaries"

		# Add sentence boundaries
		cat "$result/1Best.ctm" | perl scripts/wordpausestatistic.perl 1.0 "$result/1Best.sent" || die "Failure adding sentence boundaries"
	fi

fi

logtitle "Done"
log "Output written to:"
log " - CTM:                 $result/1Best.ctm"
log " - Text with scores:    $result/1Best.txt"
log " - Text without scores: $result/1Best_plain.txt"
segments="$(cat "$data/ALL/segments" | cut -d " " -f 2 | sort | uniq)"
for segment in $segments; do
	if [ -e "$result/$segment.xml" ]; then
		log " - XML:                 $result/$segment.xml"
	fi
	if [ -e "$result/$segment.rttm" ]; then
		log " - RTTM:                $result/$segment.rttm"
	fi
done
if [ -e "$result/1Best.ctm.spk" ]; then
	log " - Speaker diarisation: $result/1Best.ctm.spk"
fi
if [ -e "$result/1Best.sent" ]; then
	log " - Sentence boundaries: $result/1Best.sent"
fi
date=$(date)
log "(Finished at $date)"
