#!/bin/bash

#
# Author: Laurens van der Werff (University of Twente)
#         Adapted by Maarten van Gompel (CLST, Radboud University Nijmegen)
#
# Apache 2.0
#

#
#   Decode audio files to produce transcriptions and additional info in a target directory
#
#		Usage: ./decode.sh [options] <speech-dir>|<speech-file>|<txt-file containing list of source material> <output-dir>
#
#   This script sets configuration parameters, the actual functionality is implemented in decode_include.sh
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
graph=models/AM/graph_PR
lmodel=models/LM/LM_PR_3gpr.gz
lpath=models/Lang_PR
llmodel=models/LM/LM_PR_4gpr.gz
llpath=models/LM/Const_PR
extractor=


set +a

include_path="$(dirname "$(readlink -f "$0")")"
source "$include_path/decode_include.sh"
