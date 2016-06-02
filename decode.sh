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
#   Use the configure.sh script to create the required links to the relevant utilities of Kaldi 
#	and to download and link to the models.
#
# 	All input files that are specified on the command-line are linked or copied to a working directory, which is
#	<output-dir>/Intermediate/Data. From here, all files with a chosen extension (default wav, mp3) are 
#	used as input for the Kaldi speech transcription. Certain additional files may be present in the working
#	directory, specifically those with the following extensions:
#
#   .ubm:	used to define the sections in the files that should be transcribed
#	.stm:	containing transcriptions for evaluation purposes. If present, asclite will be invoked
#			to evaluate the results (case insensitive)
#	.glm:	contains definitions for use by csrfilt.sh (part of sctk in the kaldi/tools directory), which are applied
#			to the transcription
#
#	In case you want to copy all material, make sure there is enough space available in the target location. 
#	Files are identified by their base filename, so there must be no duplicate names in a batch!
#
#   The procedure is as follows:
#		1.	All source files which are specified on the command line are copied or linked to <output-dir>/Intermediate/Data
#     	 	This directory is scanned for audio, which is then processed by the LIUM speaker diarization tool so as to produce
#			chunks of around 20 seconds in length.
#			The LIUM segmentation and source files are then processed to create the files needed for Kaldi: 
#				wav.scp, segments, utt2spk, spk2utt, spk2gender
#		2. 	MFCC features and CMVN stats are generated.
#		3.	Speech transcription is performed. First there is an FMLLR stage (2-passes), then whichever method is selected (fmmi, sgmm2, nnet_bn), 
#			using a relatively small trigram language model. 
#		4.	The resulting lattices are rescored using a larger 4-gram language model.
#		5.	1-best transcriptions are extracted from the rescored lattices and results are gathered into 1Best.ctm which contains
#			the transcriptions for all of the audio in the source directory. The segmentation from (1) is then used to create a 1Best.txt file.
#			Optionally an NBest ctm can also be generated. Results are filtered to remove 'uh' and '<unk>', numbers and compounds are rewritten
#			to follow normal Dutch practice.
# 		6.	If a reference transcription (.stm) is available, an evaluation is performed using asclite. Results of the evalluation can then be 
#			found in <output-dir>/1Best.ctm.{dtl,pra,sys}
#

cmd=run.pl
nj=4                    # maximum number of simultaneous jobs used for feature generation and decoding
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
copyall=false							# copy all source files (true) or use symlinks (false)
overwrite=true					# overwrite the 1st pass output if already present
splittext=true

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
    echo "  --copyall <true/false>                   # copy all source files or use symlinks, default is false (use symlinks)"
    echo "  --splittext <true/false>                 # split resulting 1Best.txt into separate .txt files for each input file, default $splittext"
    exit 1;
fi

## These settings should generally be left alone
result=${!#}
logging=$result/Intermediate/logging
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
nnet2_decode=$inter/nnet2
rescore=$inter/rescore
orgrescore=$rescore
rnnrescore=$inter/rnnrescore
symtab=$lmloc/$largeLM/words.txt
fmllr_opts="--cmd $cmd --skip-scoring true --num-threads $num_threads --first-beam $first_beam --first-max-active $first_max_active --silence-weight $silence_weight --acwt $acwt --max-active $max_active --beam $beam --lattice-beam $lattice_beam";
fmllr_bn_opts="--cmd $cmd --skip-scoring true --num-threads $num_threads --first-beam $first_beam_bn --first-max-active $first_max_active_bn --silence-weight $silence_weight_bn --acwt $acwt_bn --max-active $max_active_bn --beam $beam_bn --lattice-beam $lattice_beam_bn";
fmmi_opts="--cmd $cmd --skip-scoring true --num-threads $num_threads --acwt $acwt --maxactive $maxactive --beam $beam --lattice-beam $lattice_beam";
sgmm2_opts="--cmd $cmd --skip-scoring true --num-threads $num_threads --acwt $acwt --max-active $maxactive --beam $beam --lattice-beam $lattice_beam";

timer="$(which time) -o $inter/time.log -f \"%e %U %S %M\""

# determine the output location
case $modeltype in 
	fmllr)	resultsloc=$fmllr_decode;;
	fmmi)		resultsloc=$fmmi_decode;;
	sgmm2)	resultsloc=$sgmm2_mmi_decode
			modeltype="sgmm2_mmi";;
	nnet)		resultsloc=$nnet_decode;;
	nnet_bn)	resultsloc=$nnet_bn_decode;;
	nnet2)		resultsloc=$nnet2_decode
				modeltype="nnet_ms_a";;
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
				if $copyall; then			
					cp $i $data/
				else
					ln -s -f $i $data
				fi
			elif [[ $filetype =~ .*text.* ]]; then
				echo "Argument $i is a text file, using it as list of files to copy"
				if $copyall; then				
					xargs -a $i cp -t $data
				else
					xargs -a $i ln -s -t $data
				fi
			fi
		elif [ -d $i ]; then
			echo "Argument $i is a directory, copying contents"		
			if $copyall; then
				cp -a $i/* $data
			else
				ln -s -f $i/* $data
			fi
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
	eval $timer local/flist2scp.pl $data $multichannel >$logging 2>&1 &						# main data preparation stage, also does diarization
	pid=$!
	numfiles=$(cat $data/test.flist | wc -l)
	while kill -0 $pid 2>/dev/null; do
		if [ -e $data/ALL/test.uem ]; then
			numfiles=$(cat $data/ALL/test.uem | wc -l)
		fi
		numsegmented=$(ls $data/ALL/liumlog/*.seg 2>/dev/null| wc -l)
		local/progressbar.sh $numsegmented $numfiles 50 "Diarization" 
		sleep 1
	done
	cat $inter/time.log | awk '{printf( "Diarization completed in %d:%02d:%02d (CPU: %d:%02d:%02d), Memory used: %d MB                \n", int($1/3600), int($1%3600/60), int($1%3600%60), int(($2+$3)/3600), int(($2+$3)%3600/60), int(($2+$3)%3600%60), $4/1000) }'
			
	numsegments=$(cat $data/ALL/segments | wc -l)
	echo "$numfiles source file(s) were split into $numsegments segments                 "
	cat $data/ALL/utt2spk.tmp | sort -k2,2 -k1,1 -u >$data/ALL/utt2spk
	rm $data/ALL/utt2spk.tmp $data/foo.wav
	local/change_segment_names.pl $data											# change names of utterances for sorting purposes
	cat $data/*.stm 2>/dev/null | sort -k1,1 -k4,4n >$data/ALL/ref.stm			# combine individual stm's
	cat $data/*.glm 2>/dev/null >$data/ALL/all.glm								# copy any .glm's	
	utils/fix_data_dir.sh $data/ALL >>$logging 2>&1
	cp -r $data/ALL/liumlog $result
fi


## feature generation
if [ $stage -le 2 ]; then
	echo "Feature generation" >$inter/stage
	## create mfccs for decoding
	cp conf/mfcc.conf $inter
	[ $modeltype = "nnet_ms_a" ] && cp conf/mfcc_hires.conf $inter/mfcc.conf

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
		
		steps/make_fbank_pitch.sh --nj $this_nj $test_fb $test_fb/log $test_fb/data >>$logging 2>&1 || exit 1;
  		steps/compute_cmvn_stats.sh $test_fb $test_fb/log $test_fb/data >>$logging 2>&1 || exit 1;	  
	  
		steps/nnet/make_bn_feats.sh --nj $this_nj $test_bn $test_fb $bnfeat $test_bn/log $test_bn/data >>$logging 2>&1 || exit 1 
		steps/compute_cmvn_stats.sh $test_bn $test_bn/log $test_bn/data >>$logging 2>&1 || exit 1
		
		# the standard scripts don't copy ref.stm, or test.uem
		cp $data/ALL_orig/ref.stm $data/ALL_orig/test.uem $data/ALL_orig/all.glm $data/ALL/ 2>/dev/null
	else
		steps/make_mfcc.sh --nj $this_nj --mfcc-config $inter/mfcc.conf $data/ALL $data/ALL/log $inter/mfcc >>$logging 2>&1 || exit 1
		steps/compute_cmvn_stats.sh $data/ALL $data/ALL/log $inter/mfcc >>$logging 2>&1 || exit 1
	fi
	
	## Make separate folders for speech types, if needed
	if [ "$speech_types" != "ALL" ]; then				     
		for type in $speech_types; do
			cat $data/BWGender | grep $type | uniq | awk '{print $2}' >$data/foo
 			utils/subset_data_dir.sh --utt-list $data/foo $data/ALL $data/$type >>$logging 2>&1
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
		totallines=$(cat $data/${type}/segments | wc -l)
		
		fmllr_models=models/$bw/fmllr
		if [ $modeltype = "nnet_bn" ]; then 				# for the nnet_bn model, create a first-pass w/ bn features
			fmllr_models=models/$bw/fmllr_bn				# dnn8c_fmllr-gmm 		 
			fmllr_decode=$fmllr_bn_decode	
			fmllr_opts=$fmllr_bn_opts
		fi
		
	 	mkdir -p $fmllr_decode $fmllr_decode.si $resultsloc
			
		if [ $modeltype != "nnet_ms_a" ] && [[ ! -d $fmllr_decode/$type || $overwrite ]]; then
			foo=`mktemp -d -p $fmllr_models` 
			
			echo -e "First pass decode\t$type\t$foo" >$inter/stage 
			# fmllr decoding
			eval $timer steps/decode_fmllr.sh $fmllr_opts --nj $this_nj $fmllr_models/$graph $data/$type $foo >>$logging 2>&1 &
			pid=$!
        	while kill -0 $pid 2>/dev/null; do
				linesdone=$(cat ${foo}/log/decode.*.log 2>/dev/null | grep Log-like | wc -l)
				pbmessage="First Pass Stage 2/2";				
				if [ $linesdone -eq 0 ]; then
					linesdone=$(cat ${foo}.si/log/decode.*.log 2>/dev/null | grep Log-like | wc -l)		
					pbmessage="First Pass Stage 1/2";				
				fi
				local/progressbar.sh $linesdone $totallines 50 "$pbmessage"  			
  				sleep 2
			done
			cat $inter/time.log | awk '{printf( "First Pass  completed in %d:%02d:%02d (CPU: %d:%02d:%02d), Memory used: %d MB                \n", int($1/3600), int($1%3600/60), int($1%3600%60), int(($2+$3)/3600), int(($2+$3)%3600/60), int(($2+$3)%3600%60), $4/1000) }'
			
            rm -rf $fmllr_decode/$type ${fmllr_decode}.si/$type 
            mv -f $foo $fmllr_decode/$type      # standard scripts place results in subdir of model directory.. 
            mv -f ${foo}.si ${fmllr_decode}.si/$type 
		fi
    	 
		if [ $modeltype = "fmllr" ]; then continue; fi
		
		models=models/$bw/$modeltype
		
		# nnet decode supports alternative decode locations, fmmi & sgmm decode do not
		if [ $modeltype = "fmmi" -o $modeltype = "sgmm2_mmi" -o $modeltype = "nnet_ms_a" ]; then
        	foo=`mktemp -d -p $models`
        	fpresults=$foo
			echo -e "Second pass decode\t$type\t$foo" >$inter/stage 
		else
			fpresults=${resultsloc}/$type
			echo -e "Second pass decode\t$type\t${resultsloc}/$type" >$inter/stage 	
		fi
		
		case $modeltype in 
			fmmi)    /usr/bin/time -o $inter/time.log -f "%e %U %S %M" steps/decode_fmmi.sh $fmmi_opts --nj $this_nj --transform-dir $fmllr_decode/$type $models/$graph $data/$type $foo;; 
      		sgmm2_mmi)	p1_models=models/$bw/sgmm2
						foop1=`mktemp -d -p $p1_models` 
            			rm -rf $sgmm2_decode/$type 
            			time steps/decode_sgmm2.sh $sgmm2_opts --nj $this_nj --transform-dir $fmllr_decode/$type $p1_models/$graph $data/$type $foop1                    
            			time steps/decode_sgmm2_rescore.sh --skip-scoring true --transform-dir $fmllr_decode/$type $p1_models/$graph $data/$type $foop1 $foo         
            			mkdir -p $sgmm2_decode                   
                  		mv $foop1 $sgmm2_decode/$type;; 
            nnet_ms_a)	rm $models/../extractor/.error 2>/dev/null
            			steps/online/nnet2/extract_ivectors_online.sh --nj $this_nj --max-count 10 $data/$type $models/../extractor $data/$type/ivectors >>$logging 2>&1 || touch $models/../extractor/.error
            			[ -f $models/../extractor/.error ] && echo "$0: error ectracting iVectors." && exit 1
            			eval $timer steps/nnet2/decode.sh --nj $this_nj --skip-scoring true --online-ivector-dir $data/$type/ivectors $fmllr_models/$graph $data/$type $foo >>$logging 2>&1 &;; 
            nnet)    	steps/nnet/make_fmllr_feats.sh --nj $this_nj --transform-dir $fmllr_decode/$type $data/$type/data_fmllr $data/$type $fmllr_models $data/$type/log $data/$type/data_fmllr/data     
              			eval $timer steps/nnet/decode.sh --nj $this_nj --srcdir $models --config conf/decode_dnn.config --acwt 0.1 $fmllr_models/$graph $data/$type/data_fmllr $resultsloc/$type;;
			nnet_bn)	rm -rf $resultsloc/$type
						steps/nnet/make_fmllr_feats.sh --nj $this_nj --transform-dir $fmllr_decode/$type $data/$type/data_fmllr_bn $data/$type $fmllr_models $data/$type/log $data/$type/data_fmllr_bn/data  >>$logging 2>&1
						eval $timer steps/nnet/decode.sh --nj $this_nj --srcdir $models --config conf/decode_dnn.config --acwt 0.1 $fmllr_models/$graph $data/$type/data_fmllr_bn $resultsloc/$type  >>$logging 2>&1 &;;       
        esac 
		        
        pid=$!
        while kill -0 $pid 2>/dev/null; do
			linesdone=$(cat $fpresults/log/decode.*.log 2>/dev/null | grep Log-like | wc -l)
			local/progressbar.sh $linesdone $totallines 50 "Final Pass"  			
  			sleep 2
		done
        tail -1 $inter/time.log | awk '{printf( "Final Pass  completed in %d:%02d:%02d (CPU: %d:%02d:%02d), Memory used: %d MB                \n", int($1/3600), int($1%3600/60), int($1%3600%60), int(($2+$3)/3600), int(($2+$3)%3600/60), int(($2+$3)%3600%60), $4/1000) }'
		
        if [ $modeltype = "fmmi" -o $modeltype = "sgmm2_mmi" -o $modeltype = "nnet_ms_a" ]; then
        	rm -rf $resultsloc/$type    
       		mv -f $foo $resultsloc/$type
       	fi   
	done
fi

## rescore with 4-gram language model and optionally RNN LM.]; the
if [ $stage -le 4 ]; then
	for type in $speech_types; do
		if $dorescore; then		
			echo -e "Rescoring\t$type" >$inter/stage            
      		if [ ! -e $resultsloc/$type/num_jobs ]; then
         		continue
         	fi
         	numjobs=$(< $resultsloc/$type/num_jobs)
	     	# largeLM rescoring
     		eval $timer steps/lmrescore_const_arpa.sh --skip-scoring true $lmloc/$smallLM $lmloc/$largeLM $data/$type $resultsloc/$type $rescore/$type >>$logging 2>&1 &           
			pid=$!
			spin='-\|/'
			i=0
        	while kill -0 $pid 2>/dev/null; do
				i=$(( (i+1) %4 ))
  				printf "\rRescoring.. ${spin:$i:1}"
  				sleep .2
			done
        	cat $inter/time.log | awk '{printf("\rRescoring   completed in %d:%02d:%02d (CPU: %d:%02d:%02d), Memory used: %d MB                \n", int($1/3600), int($1%3600/60), int($1%3600%60), int(($2+$3)/3600), int(($2+$3)%3600/60), int(($2+$3)%3600%60), $4/1000) }'
		     		
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
	if [ -s $data/ALL/all.glm ]; then
			cat $data/ALL/1Best.raw.ctm | sort -k1,1 -k3,3n | local/remove_hyphens.pl | \
			perl local/combine_numbers.pl | sort -k1,1 -k3,3n | local/compound-restoration.pl 2>>$logging | \
			grep -E --text -v 'uh|<unk>' | csrfilt.sh -s -i ctm -t hyp $data/ALL/all.glm >$data/ALL/1Best.ctm
	else
		cat $data/ALL/1Best.raw.ctm | sort -k1,1 -k3,3n | local/remove_hyphens.pl | \
			perl local/combine_numbers.pl | sort -k1,1 -k3,3n | local/compound-restoration.pl 2>>$logging | \
			grep -E --text -v 'uh|<unk>' >$data/ALL/1Best.ctm
	fi
	
	if $multichannel; then
		cat $data/ALL/1Best.ctm | sed 's/\.[0-9] / /' | sort -k1,1 -k3,3n >$result/1Best.ctm    # remove channel from id
	else
		cp $data/ALL/1Best.ctm $result
	fi
	
	local/ctmseg2sent.pl $result $splittext >$result/1Best.txt

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
		asclite -D -noisg -r $data/ALL/ref.stm stm -h $result/1Best.ctm ctm $uem -o sgml >>$logging 2>&1 
		cat $result/1Best.ctm.sgml | sclite -P -o sum -o pralign -o dtl -n $result/1Best.ctm  >>$logging 2>&1
  	fi
fi

echo -e "Done\t$type" >$inter/stage
echo "Done"
