#!/bin/bash

#
# Author: Laurens van der Werff (University of Twente)
# 
# Apache 2.0
#

#
#   Decode audio-files to produce transcriptions and additional info in a target directory
#
#		Usage: ./decode.sh [options] <speech-dir>|<speech-file>|<txt-file containing list of source material> <output-dir>
#
#   Use the configure.sh script to create the required links to the relevant utilities of Kaldi and the models.
#
#   If the source directory contains .ubm files, only those sections will be transcribed
#   If the source directory contains .stm files, it is assumed to contain a transcription of the audio and
#   the results are automatically evaluated using asclite (case insensitive). 
#
#   All selected files/directories are copied to the target directory for processing, so make sure there is 
#   enough space available in the target location. Files are identified by their base filename, so make sure there
#	 are no duplicate names in a batch!
#
#   The following steps are taken:
#	   1. All source files which are specified in the command line are copied to the source directory
#     	The source directory is scanned for audio, which is then processed by the LIUM speaker diarization tool.
#        The results are used to create the files needed for Kaldi: wav.scp, segments, utt2spk, spk2utt, spk2gender
#     2. MFCC features and CMVN stats are generated. The data may be split into 4 sets: Male & Female Broadcast News and
#        Telephone speech, though this is not needed if a single acoustic model is used.
#     3. Decoding is done in several stages: FMLLR (2-pass), then whichever method is selected (fmmi, sgmm, nnet, nnet_bn), 
#		   using a relatively small trigram language model. 
#     4. The resulting lattices are rescored using a larger 4-gram language model.
#     5. 1-best transcriptions are extracted from the rescored lattices and results are gathered into 1Best.ctm which contains
#        the transcriptions for all of the audio in the source directory. Optionally an NBest ctm can also be generated.
#     6. If a reference transcription is available, an evaluation is done using asclite.
#

cmd=run.pl
nj=8                    # maximum number of simultaneous jobs used for feature generation and decoding
stage=1
num_threads=1           # used for decoding
inv_acoustic_scale=11   # used for 1-best and N-best generation

# for decode_fmllr:
first_beam=10.0         # Beam used in initial, speaker-indep. pass
first_max_active=2000   # max-active used in initial pass.
silence_weight=0.01
max_active=7000

# for decode_fmllr w/bn features:
first_beam_bn=10.0         
first_max_active_bn=2000 
silence_weight_bn=0.01
max_active_bn=7000
acwt_bn=0.05
beam_bn=15.0
lattice_beam_bn=8.0

# for decode_fmmi:
maxactive=7000				# also uses for sgmm

# for decode_fmllr & decode_fmmi & decode_sgmm2:
acwt=0.083333           # Acoustic weight used in getting fMLLR transforms, and also in lattice generation.
beam=13.0
lattice_beam=6.0

modeltype="nnet_bn"		# fmmi, or nnet_bn, or fmmlr, or sgmm2

rnn=false               # if true, do RNN rescoring
rnnnbest=1000           # if doing RNN rescoring use this amount of alternatives
rnnweight=0.5           # relative weight of RNN in rescoring

cts=false                       # if true, use CTS models for sections that were detected as CTS by the diarization. Else use BN models.
genderspecific=false					# if true, use gender specific models 
speech_types="MS FS MT FT"      # which types of speech to transcribe (M=Male, F=female, S=studio, T=telephone)
file_types="wav mp3"				# file types to include for transcription
nbest=0                         # if value >0, generate NBest.ctm with this amount of transcription alternatives
multichannel=false              # by default assume that the input files are monophonic (or map them to mono), otherwise analyse channels separately
singlespeaker=false             # by default assume multiple speakers in input, otherwise assume one speaker (per channel)
dorescore=true                  # rescore with largeLM as default

# language models used for rescoring. smallLM must match with the graph of acoustic+language model
# largeLM must be a 'const arpa' LM
graph=graph_lm_small
smallLM=3gpr
largeLM=4gpr_const

rnnLM=						        # if rnn=true, use this model for rnn-rescoring after largeLM rescoring

[ -f ./path.sh ] && . ./path.sh; # source the path.

. parse_options.sh || exit 1;

if [ $# -lt 2 ]; then
    echo "Wrong #arguments ($#, expected 2)"
    echo "Usage: decode.sh [options] <source-dir|source files|txt-file list of source files> <decode-dir>"
    echo "  "
    echo "main options (for others, see top of script file)"
    echo "  --config <config-file>                   # config containing options"
    echo "  --modeltype <fmllr|fmmi|sgmm2|nnet|nnet_bn>"
    echo "		                                      # models used for decoding, defaule nnet_bn"
    echo "  --nj <nj>                                # maximum number of parallel jobs"
    echo "  --cmd <cmd>                              # Command to run in parallel with"
    echo "  --acwt <acoustic-weight>                 # default 0.08333 ... used to get posteriors"
    echo "  --num-threads <n>                        # number of threads to use, default 1."
    echo "  --speech-types <types>                   # speech types to decode, default \"MS FS MT FT\" "
    echo "  --nbest <n>                              # produce <n>-best ctms (without posteriors)"
    echo "  --cts <true/false>                       # use cts models for telephone speech, default is false."
    echo "  --file-types <extensions>                # include audio files with the given extensions, default \"wav mp3\" "
    exit 1;
fi

## These settings should generally be left alone
result=${!#}
inter=$result/Intermediate
data=$inter/Data
lmloc=models/LM
fmllr_decode=$inter/fmllr
fmllr_bn_decode=$inter/fmllr_bn
fmmi_decode=$inter/fmmi
sgmm2_decode=$inter/sgmm2
sgmm2_mmi_decode=$inter/sgmm2_mmi
nnet_decode=$inter/nnet
nnet_bn_decode=$inter/nnet_bn
rescore=$inter/rescore
orgrescore=$rescore
rnnrescore=$inter/rnnrescore
symtab=$lmloc/$largeLM/words.txt
fmllr_opts="--cmd $cmd --skip-scoring true --num-threads $num_threads --first-beam $first_beam --first-max-active $first_max_active --silence-weight $silence_weight --acwt $acwt --max-active $max_active --beam $beam --lattice-beam $lattice_beam";
fmllr_bn_opts="--cmd $cmd --skip-scoring true --num-threads $num_threads --first-beam $first_beam_bn --first-max-active $first_max_active_bn --silence-weight $silence_weight_bn --acwt $acwt_bn --max-active $max_active_bn --beam $beam_bn --lattice-beam $lattice_beam_bn";
fmmi_opts="--cmd $cmd --skip-scoring true --num-threads $num_threads --acwt $acwt --maxactive $maxactive --beam $beam --lattice-beam $lattice_beam";
sgmm2_opts="--cmd $cmd --skip-scoring true --num-threads $num_threads --acwt $acwt --max-active $maxactive --beam $beam --lattice-beam $lattice_beam";

# determine the output location
case $modeltype in 
	fmllr)	resultsloc=$fmllr_decode;;
	fmmi)		resultsloc=$fmmi_decode;;
	sgmm2)	resultsloc=$sgmm2_mmi_decode
			modeltype="sgmm2_mmi";;
	nnet)		resultsloc=$nnet_decode;;
	nnet_bn)	resultsloc=$nnet_bn_decode;;
esac

# set up speech types: only split into speech types if different models are used
if $cts || $genderspecific && [ $speech_types = "ALL" ]; then
	speech_types="MS FS MT FT"
elif [ !$cts ] && [ !$genderspecific ] && [ "$speech_types" = "MS FS MT FT" ]; then
	speech_types="ALL"
fi

## data prep
if [ $stage -le 1 ]; then
	mkdir -p $data/ALL/liumlog 
	echo "Data preparation" >$inter/stage	
	
	# handle input types: either directory, separate files, or list of files to process
	while [[ $# > 1 ]] ; do
		i=$1
		shift
		if [ -f $i ]; then
			filetype=$(file -ib $i)
			if [[ $filetype =~ .*audio.* ]]; then
				echo "Argument $i is a sound file, using it as audio"		
				cp $i $data/
			elif [[ $filetype =~ .*text.* ]]; then
				echo "Argument $i is a text file, using it as list of files to copy"
				xargs -a $i cp -t $data
			fi
		elif [ -d $i ]; then
			echo "Argument $i is a directory, copying contents"		
			cp -a $i/* $data		
		else
			echo "Argument $i cannot be processed - skipping"		
		fi
	done	
	echo "$speech_types" >$inter/types

	## Process source directory
	# create file list to process, only use audio files whose type was specified in file_types
	findcmd="find $data "
	for type in $file_types; do
		findcmd="$findcmd -iname '*.${type}' -o "
	done
	findcmd=${findcmd%????}
	eval $findcmd >$data/test.flist
    
	# prepare data
	local/flist2scp.pl $data $multichannel							# main data preparation stage, also does diarization
	cat $data/ALL/utt2spk.tmp | sort -k2,2 -k1,1 -u >$data/ALL/utt2spk
	rm $data/ALL/utt2spk.tmp $data/foo.wav
	local/change_segment_names.pl $data								# change names of utterances for sorting purposes
	cat $data/*.stm | sort -k1,1 -k4,4n >$data/ALL/ref.stm				# combine individual stm's
	utils/fix_data_dir.sh $data/ALL
	cp -r $data/ALL/liumlog $result
fi


## feature generation
if [ $stage -le 2 ]; then
	echo "Feature generation" >$inter/stage
	## create mfccs for decoding
	cp conf/mfcc.conf $inter

	# determine maximum number of jobs for this task
	numspeak=$(wc -l $data/ALL/spk2utt | awk '{print $1}')
	if (( $numspeak == 0 )); then exit; elif (( $nj > $numspeak )); then this_nj=$numspeak; else this_nj=$nj; fi
	
	# Generate either bottleneck or 'standard' mfcc features
	if [ $modeltype = "nnet_bn" ]; then
		bnfeat=models/BN/bn-feat											   # dnn8a_bn-feat		
		rm -rf $data/ALL_orig		
		mv $data/ALL $data/ALL_orig
		test_fb=$data/ALL_orig
		test_bn=$data/ALL
		
		steps/make_fbank_pitch.sh --nj $this_nj $test_fb $test_fb/log $test_fb/data || exit 1;
  		steps/compute_cmvn_stats.sh $test_fb $test_fb/log $test_fb/data || exit 1;	  
	  
		steps/nnet/make_bn_feats.sh --nj $this_nj $test_bn $test_fb $bnfeat $test_bn/log $test_bn/data || exit 1 
		steps/compute_cmvn_stats.sh $test_bn $test_bn/log $test_bn/data || exit 1
		
		# the standard scripts don't copy ref.stm, or test.uem
		cp $data/ALL_orig/ref.stm $data/ALL_orig/test.uem $data/ALL/ 2>/dev/null
	else
		steps/make_mfcc.sh --nj $this_nj --mfcc-config $inter/mfcc.conf $data/ALL $data/ALL/log $inter/mfcc || exit 1
		steps/compute_cmvn_stats.sh $data/ALL $data/ALL/log $inter/mfcc || exit 1
	fi
	
	## Make separate folders for speech types, if needed
	if [ "$speech_types" != "ALL" ]; then				     
		for type in $speech_types; do
			cat $data/BWGender | grep $type | uniq | awk '{print $2}' >$data/foo
 			utils/subset_data_dir.sh --utt-list $data/foo $data/ALL $data/$type
		done
		rm $data/foo
	fi
fi

## decode
if [ $stage -le 3 ]; then
	for type in $speech_types; do
		# determine number of jobs
		numspeak=$(wc -l $data/$type/spk2utt | awk '{print $1}')
		if (( $numspeak == 0 )); then continue; elif (( $nj > $numspeak )); then this_nj=$numspeak; else this_nj=$nj; fi

		if [[ $type == *T ]] && $cts; then bw=CTS; else bw=BN; fi
       
		echo -n "Duration of $type speech: "
		cat $data/${type}/segments | awk '{s+=$4-$3} END {printf("%.0f", s)}' | local/convert_time.sh

		fmllr_models=models/$bw/fmllr
		if [ $modeltype = "nnet_bn" ]; then 				# for the nnet_bn model, create a first-pass w/ bn features
			fmllr_models=models/$bw/fmllr_bn				# dnn8c_fmllr-gmm 		 
			fmllr_decode=$fmllr_bn_decode	
			fmllr_opts=$fmllr_bn_opts
		fi
		
		mkdir -p $fmllr_decode $fmllr_decode.si $resultsloc
		
		if [ ! -d $fmllr_decode/$type ]; then			
			foo=`mktemp -d -p $fmllr_models`
			echo -e "First pass decode\t$type\t$foo" >$inter/stage 
			# fmllr decoding
        		time steps/decode_fmllr.sh $fmllr_opts --nj $this_nj $fmllr_models/$graph $data/$type $foo
        		rm -rf $fmllr_decode/$type ${fmllr_decode}.si/$type
        		mv -f $foo $fmllr_decode/$type      # standard scripts place results in subdir of model directory..
        		mv -f ${foo}.si ${fmllr_decode}.si/$type
		fi
    	 
		if [ $modeltype = "fmllr" ]; then continue; fi
		
		models=models/$bw/$modeltype
		foo=`mktemp -d -p $models`
		echo -e "Second pass decode\t$type\t$foo" >$inter/stage 	
		case $modeltype in 
			fmmi)		time steps/decode_fmmi.sh $fmmi_opts --nj $this_nj --transform-dir $fmllr_decode/$type $models/$graph $data/$type $foo;;
			sgmm2_mmi)	p1_models=models/$bw/sgmm2
						foop1=`mktemp -d -p $p1_models`
						rm -rf $sgmm2_decode/$type
						time steps/decode_sgmm2.sh $sgmm2_opts --nj $this_nj --transform-dir $fmllr_decode/$type $p1_models/$graph $data/$type $foop1               		
						time steps/decode_sgmm2_rescore.sh --skip-scoring true --transform-dir $fmllr_decode/$type $p1_models/$graph $data/$type $foop1 $foo        
						mkdir -p $sgmm2_decode        					
        					mv $foop1 $sgmm2_decode/$type;;
        		nnet)		steps/nnet/make_fmllr_feats.sh --nj $this_nj --transform-dir $fmllr_decode/$type $data/$type/data_fmllr $data/$type $fmllr_models $data/$type/log $data/$type/data_fmllr/data		
  						time steps/nnet/decode.sh --nj $this_nj --config conf/decode_dnn.config --acwt 0.1 $fmllr_models/$graph $data/$type/data_fmllr $foo;;
			nnet_bn)		steps/nnet/make_fmllr_feats.sh --nj $this_nj --transform-dir $fmllr_decode/$type $data/$type/data_fmllr_bn $data/$type $fmllr_models $data/$type/log $data/$type/data_fmllr_bn/data
						time steps/nnet/decode.sh --nj $this_nj --config conf/decode_dnn.config --acwt 0.1 --nnet $models/final.nnet $fmllr_models/$graph $data/$type/data_fmllr_bn $foo;;      
      	esac
      	rm -rf $resultsloc/$type   
	   	mv -f $foo $resultsloc/$type	
	done
fi

## rescore with 4-gram language model and optionally RNN LM.
if [ $stage -le 4 ]; then
	for type in $speech_types; do
		if $dorescore; then		
			echo -e "Rescoring\t$type" >$inter/stage            
      	if [ ! -e $resultsloc/$type/num_jobs ]; then
         	continue
         fi
         numjobs=$(< $resultsloc/$type/num_jobs)
	     		# largeLM rescoring
     		time steps/lmrescore_const_arpa.sh --skip-scoring true $lmloc/$smallLM $lmloc/$largeLM $data/$type $resultsloc/$type $rescore/$type           
     		if $rnn; then
				time steps/rnnlmrescore.sh --cmd $cmd --skip-scoring true --rnnlm-ver faster-rnnlm/faster-rnnlm --N $rnnnbest --inv-acwt $inv_acoustic_scale $rnnweight $lmloc/$largeLM $rnnLM $data/$type $rescore/$type $rnnrescore/$type
      	fi
		fi
	done
fi

## create readable output
if [ $stage -le 5 ]; then
	if $dorescore; then
		if $rnn; then rescore=$rnnrescore; fi      # if rnn rescoring was active, then use those results to generate .ctm files
	else
		rescore=$resultsloc
	fi

	acoustic_scale=$(awk -v as=$inv_acoustic_scale 'BEGIN { print 1/as }')
	rm -f $data/ALL/1Best.raw.ctm
	if (( $nbest > 0 )); then rm -f $result/NBest.raw.ctm; fi

	for type in $speech_types; do
		echo -e "Producing output\t$type" >$inter/stage            
  
      ## convert lattices into a ctm with confidence scores
		if [[ $type == *T ]] && $cts; then bw=CTS; else bw=BN; fi
		models=models/$bw/$modeltype
						
      	if [ -e $orgrescore/$type/num_jobs ]; then numjobs=$(< $orgrescore/$type/num_jobs); else continue; fi

		# produce 1-Best with confidence
		$cmd --max-jobs-run $nj JOB=1:$numjobs $inter/log/lat2ctm.$type.JOB.log \
			gunzip -c $rescore/$type/lat.JOB.gz \| \
			lattice-push ark:- ark:- \| \
			lattice-align-words $lmloc/$largeLM/phones/word_boundary.int $models/final.mdl ark:- ark:- \| \
			lattice-to-ctm-conf --inv-acoustic-scale=$inv_acoustic_scale ark:- - \| utils/int2sym.pl -f 5 $symtab \| \
			local/ctm_time_correct.pl $data/ALL/segments \| sort \> $rescore/$type/1Best.JOB.ctm | exit 1;
		cat $rescore/$type/1Best.*.ctm >$data/$type/1Best.ctm

		## convert lattices into an nbest-ctm (without confidence scores)
		if (( $nbest > 0 )); then
			$cmd --max-jobs-run $numjobs JOB=1:$numjobs $inter/log/lat2nbest.JOB.log \
 				gunzip -c $rescore/$type/lat.JOB.gz \| \
				lattice-to-nbest --acoustic-scale=$acoustic_scale --n=$nbest ark:- ark:- \| \
				nbest-to-ctm ark:- - \| utils/int2sym.pl -f 5 $symtab \| \
				local/ctm_time_correct.pl $data/ALL/segments \| sort \> $rescore/$type/NBest.JOB.ctm
			cat $rescore/$type/NBest.*.ctm >$data/$type/NBest.ctm
		fi
	done
   
   	# if found, use all speech types in the final ctm files
	if [ $speech_types = "ALL" ]; then	
		alltypes="ALL"
	else
		alltypes="MS FS MT FT"
	fi
	for type in $alltypes; do
      	if [ -e $data/$type/1Best.ctm ]; then
			cat $data/$type/1Best.ctm >>$data/ALL/1Best.raw.ctm
		fi
		if (( $nbest > 0 )) && [ -e $data/$type/NBest.ctm ]; then
			cat $data/$type/NBest.ctm >>$data/ALL/NBest.raw.ctm
		fi
	done

	# combine the ctms and do postprocessing: sort, combine numbers, restore compounds, filter with glm
#	cat $data/ALL/1Best.raw.ctm | sort -k1,1 -k3,3n | local/remove_hyphens.pl | \
#		perl local/combine_numbers.pl | sort -k1,1 -k3,3n | local/compound-restoration.pl | grep -v uh | grep -v '<unk>' | \
#		csrfilt.sh -s -i ctm -t hyp local/nbest-eval-2008.glm >$data/ALL/1Best.ctm
	cat $data/ALL/1Best.raw.ctm | sort -k1,1 -k3,3n | local/remove_hyphens.pl | \
		perl local/combine_numbers.pl | sort -k1,1 -k3,3n | local/compound-restoration.pl | grep -v uh | \
		grep -v '<unk>' >$data/ALL/1Best.ctm

	if $multichannel; then
		cat $data/ALL/1Best.ctm | sed 's/\.[0-9] / /' | sort -k1,1 -k3,3n >$result/1Best.ctm    # remove channel from id
	else
		cp $data/ALL/1Best.ctm $result
	fi

	if (( $nbest > 0 )); then
		cat $data/ALL/NBest.raw.ctm | sort -k1,1 -k3,3n local/remove_hyphens.pl | \
			perl local/combine_numbers.pl | sort -k1,1 -k3,3n | local/compound-restoration.pl | \
			csrfilt.sh -s -i ctm -t hyp local/nbest-eval-2008.glm >$data/ALL/NBest.ctm
 		cp $data/ALL/NBest.ctm $result
	fi
fi

## score if reference transcription exists
if [ $stage -le 6 ]; then
	if [ -s $data/ALL/ref.stm ]; then
		# score using asclite, then produce alignments and reports using sclite
		if [ -e $data/ALL/test.uem ]; then uem="-uem $data/ALL/test.uem"; fi
		asclite -D -noisg -r $data/ALL/ref.stm stm -h $result/1Best.ctm ctm $uem -o sgml
		cat $result/1Best.ctm.sgml | sclite -P -o sum -o pralign -o dtl -n $result/1Best.ctm
  	fi
fi

echo -e "Done\t$type" >$inter/stage
