#!/bin/bash

#
# setup kaldi_root
#
kaldiroot=$(cat path.sh | grep "export KALDI_ROOT=" | awk -F'=' '{print $2}')
return_value=0
modelpack=

while [ ! -d $kaldiroot/egs ] && [ $return_value -eq 0 ]; do
	kaldiroot=$(dialog --stdout --title "KALDI_ROOT not properly set" --inputbox "Enter location of your KALDI installation " 0 0 "$kaldiroot")
	return_value=$?
done
[ ! $return_value -eq 0 ] && echo "KALDI_ROOT not set. Cancelling" && exit 1
sed -i "s%KALDI_ROOT=.*$%KALDI_ROOT=$kaldiroot%" path.sh

#
# get models (temporary process, a separate script for retrieving and updating models is forthcoming)
#

if [ ! -d models/NL ]; then
	while [ $return_value -eq 0 ] && ! realpath $modelpack; do
		modelpack=$(dialog --stdout --title "Models not found" --inputbox "Enter location to download & store models, do not use ~ " 0 0 "$modelpack")
		return_value=$?	
	done	
	[ ! $return_value -eq 0 ] && echo "Models not downloaded. Cancelling" && exit 1
	mkdir -p $modelpack
	[ ! -e $modelpack/Models_Starterpack.tar.gz ] && wget -P $modelpack http://beehub.nl/open-source-spraakherkenning-NL/Models_Starterpack.tar.gz
	tar -xvzf $modelpack/Models_Starterpack.tar.gz -C $modelpack
	rm -rf models
	ln -s -f $modelpack/Models models
fi

[ ! -d models/NL ] && echo "Something went wrong: models were not installed." && exit 1


#
# check for presence of java and available memory
#
messages=
[ $(which sox) ] || messages="${messages}## Warning: SOX not found, please install before using the decode script.\n"
[ "$(sox -h | grep 'AUDIO FILE FORMATS' | grep ' mp3 ')" ] || messages="${messages}## Warning: mp3 support for SOX is not installed.\n"
[ $(which time) ] || messages="${messages}## Warning: TIME not found, please install before using the decode script.\n"
[ $(which java) ] || messages="${messages}## Warning: JAVA not found, please install before using the decode script.\n"
[ $(free -t -m | grep Total | awk '{print $4}') -lt 6000 ] && messages="${messages}## Warning: You have less than 6GB of available memory, this script may hang/crash! Proceed with caution!\n"
[ "$messages" ] && dialog --stdout --title "Warnings" --msgbox "Some problems were found:\n${messages}" 0 0

#
# create symlinks to the scripts
#
ln -s -f $kaldiroot/egs/wsj/s5/steps steps
ln -s -f $kaldiroot/egs/wsj/s5/utils utils

