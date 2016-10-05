#!/bin/bash

#
#	Apply speaker diarization to a .wav input file.
#	Optionally you can specify a uem to pre-select sections of a file
#
#	The default configuration of this script is essentially the same as simply invoking the jar 
#   directly, however, having all the steps separated out makes it easier to adapt the procedure
# 	somewhat in case of non-BN data.
#

uem=
l=2
h=3
c=1.7			# used in NCLR clustering, can be changed to tune the number of clusters, higher > less clusters
minspk=2		# the minimum number of speakers (if you want to achieve a low number, you need to increase c)
cleanup="true"
nclr="false"
music="false"	# requires the use of models_es models

[ -z $LOCALCLASSPATH ] && LOCALCLASSPATH=lib/lium_spkdiarization-8.4.1.jar

[ -f ./path.sh ] && . ./path.sh; # source the path
. parse_options.sh || exit 1;

if [ $# -lt 2 ]; then
    echo "Wrong #arguments ($#, expected 2)"
    echo "Usage: diarization.sh [options] <input file> <output directory>"
    echo "  "
    echo "main options (for others, see top of script file)"
    echo "  --uem <filename>         # specify a uem file for presegmenting source"
    echo "  --l	<n>                  # linear clustering threshold, value is: $l"
	echo "  --h <n>                  # hierarchical clustering threshold, value is: $h"    
	echo "  --c	<n>                  # NCLR clustering threshold, value is: $c"
	echo "  --minspk <n>             # stop when this number of speakers is reached, value is: $minspk"
	echo "                           # NOTE: when you want a specific number of speakers, use a high value of c"
	echo "                                   and the desired number for minspk"
	echo "  --cleanup <true/false>   # Remove intermediate results, value is: $cleanup"
	echo "  --nclr <true/false>      # Do NCLR clustering, value is: $nclr"
	echo "  --music <true/false>     # Do music/jingle detection, value is: $music"
    exit 1;
fi

audio=$1			# input file in .wav format
dir=$2			# output location for segmentation
show=`basename $audio .wav`
mem=2G

echo $show
mkdir -p $dir
if [ $uem ]; then
	cat $uem | grep $show | awk '{printf "%s %d %7d %7d U U U 1\n", $1, $2, $3*100, ($4-$3)*100}' >$dir/${show}.uem
	uem=$dir/$show.uem
fi

java="java -Xmx$mem -classpath $LOCALCLASSPATH"
# help="--help"
help=

echo "init done"

pmsgmm=lib/models_es/sms.gmms
sgmm=lib/models_es/s.gmms
ggmm=lib/models_es/gender.gmms
ubm=lib/models_es/ubm.gmm

fDescStart="audio16kHz2sphinx,1:1:0:0:0:0,13,0:0:0"
fDesc="sphinx,1:1:0:0:0:0,13,0:0:0"
fDescD="sphinx,1:3:2:0:0:0,13,0:0:0:0"
fDescLast="audio16kHz2sphinx,1:3:2:0:0:0,13,1:1:0:0"
fDescCLR="audio16kHz2sphinx,1:3:2:0:0:0,13,1:1:300:4"

features=$dir/%s.mfcc
pmsseg=$dir/$show.pms.seg
	
if [ ! -e $dir/$show.adj.$h.seg ]; then
	standardopts="$help --fInputMask=$features --fInputDesc=$fDesc $show"
	# compute the MFCC
	$java fr.lium.spkDiarization.tools.Wave2FeatureSet $help \
		--fInputMask=$audio --fInputDesc=$fDescStart --fOutputMask=$features \
		--fOutputDesc=$fDesc --sInputMask=$uem --sOutputMask=$dir/%s.out.seg $show
	# check the MFCC 
	$java fr.lium.spkDiarization.programs.MSegInit $standardopts --sInputMask=$uem --sOutputMask=$dir/%s.i.seg
	# Speech / non-speech segmentation using a set of GMMs
	$java fr.lium.spkDiarization.programs.MDecode $help \
  		--fInputDesc=$fDescD --fInputMask=$features --sInputMask=$dir/%s.i.seg \
		--sOutputMask=$pmsseg --dPenality=10,10,50 --tInputMask=$pmsgmm $show	
	# GLR based segmentation, make small segments
	$java fr.lium.spkDiarization.programs.MSeg $standardopts --sInputMask=$dir/%s.i.seg \
		--sOutputMask=$dir/%s.s.seg --kind=FULL --sMethod=GLR
	# Segmentation: linear clustering
	$java fr.lium.spkDiarization.programs.MClust $standardopts --sInputMask=$dir/%s.s.seg \
		--sOutputMask=$dir/%s.l.seg --cMethod=l --cThr=$l
	# hierarchical clustering
	$java fr.lium.spkDiarization.programs.MClust $standardopts --sInputMask=$dir/%s.l.seg \
		--sOutputMask=$dir/%s.h.$h.seg --cMethod=h --cThr=$h
	# initialize GMM
	$java fr.lium.spkDiarization.programs.MTrainInit $standardopts --sInputMask=$dir/%s.h.$h.seg \
		--tOutputMask=$dir/%s.init.gmms --nbComp=8 --kind=DIAG 
	# EM computation
	$java fr.lium.spkDiarization.programs.MTrainEM $standardopts --sInputMask=$dir/%s.h.$h.seg \
		--tOutputMask=$dir/%s.gmms --tInputMask=$dir/%s.init.gmms --nbComp=8 --kind=DIAG  
	# Viterbi decoding
	$java fr.lium.spkDiarization.programs.MDecode $standardopts --sInputMask=$dir/%s.h.$h.seg \
		--sOutputMask=$dir/%s.d.$h.seg --dPenality=250 --tInputMask=$dir/%s.gmms
	# Adjust segment boundaries near silence sections
	$java fr.lium.spkDiarization.tools.SAdjSeg $standardopts --sInputMask=$dir/%s.d.$h.seg \
		--sOutputMask=$dir/%s.adj.$h.seg
fi

if [ "$music" == "true" ]; then
	# Filter speaker segmentation according to speech / non-speech segmentation
	flt1seg=$dir/$show.flt1.seg
	$java fr.lium.spkDiarization.tools.SFilter $help --sInputMask=$dir/%s.adj.$h.seg \
 		--fInputDesc=$fDescD --fInputMask=$features --fltSegMinLenSpeech=150 --fltSegMinLenSil=25 \
		--sFilterClusterName=music --fltSegPadding=25 --sFilterMask=$pmsseg --sOutputMask=$flt1seg $show

	fltseg=$dir/$show.flt.$h.seg
	$java fr.lium.spkDiarization.tools.SFilter $help --sInputMask=$flt1seg \
 		--fInputDesc=$fDescD --fInputMask=$features --fltSegMinLenSpeech=150 --fltSegMinLenSil=25 \
		--sFilterClusterName=jingle --fltSegPadding=25 --sFilterMask=$pmsseg --sOutputMask=$fltseg $show
else
	# Filter speaker segmentation according to pms segmentation
	fltseg=$dir/$show.flt.$h.seg
	$java fr.lium.spkDiarization.tools.SFilter $help --sInputMask=$dir/%s.adj.$h.seg \
		--fInputDesc=$fDescD --fInputMask=$features --fltSegMinLenSpeech=150 --fltSegMinLenSil=25 \
		--sFilterClusterName=j --fltSegPadding=25 --sFilterMask=$pmsseg --sOutputMask=$fltseg $show
fi

# Split segments longer than 20s (useful for transcription)
splseg=$dir/$show.spl.seg
$java fr.lium.spkDiarization.tools.SSplitSeg $help --sInputMask=$fltseg \
	--fInputDesc=$fDescD --fInputMask=$features  --sSegMaxLen=2000 \
	--sFilterMask=$pmsseg --sFilterClusterName=iS,iT,j --tInputMask=$sgmm --sOutputMask=$splseg $show

##Set gender and bandwith
gseg=$dir/$show.g.$h.seg
$java fr.lium.spkDiarization.programs.MScore $help --sInputMask=$splseg \
	--sGender --sByCluster --fInputDesc=$fDescLast --fInputMask=$audio \
	--tInputMask=$ggmm --sOutputMask=$gseg $show

## NCLR clustering
if [ "$nclr" == "true" ]; then
	## Features contain static and delta and are centered and reduced (--fInputDesc)
	$java fr.lium.spkDiarization.programs.MClust $help \
		--fInputMask=$audio --fInputDesc=$fDescCLR --sInputMask=$gseg \
		--sOutputMask=$dir/%s.seg --cMethod=ce --cThr=$c --tInputMask=$ubm \
		--cMinimumOfCluster=$minspk \
		--emCtrl=1,5,0.01 --sTop=5,$ubm --tOutputMask=$dir/%s.c.gmm $show
else
	mv $dir/$show.g.$h.seg $dir/$show.seg
fi

if [ "$cleanup" == "true" ]; then
	rm -f $dir/$show.{adj.$h,d.$h,flt.$h,g.$h,h.$h,i,l,pms,spl,s,out}.seg $dir/$show.{c.gmm,gmms,init.gmms,mfcc,uem}
fi

