#!/bin/bash

fatalerror() {
    echo "$*" >&2
    exit 2
}

#
# setup kaldi_root
#
if [ -z "$KALDI_ROOT" ]; then
    kaldiroot=$(cat path.sh | grep "export KALDI_ROOT=" | awk -F'=' '{print $2}')
else
    kaldiroot=$KALDI_ROOT
fi
return_value=0
if [ ! -z "$LM_PREFIX" ]; then
    modelpack=$LM_PREFIX/opt/kaldi_nl
else
    modelpack=
fi

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
    if [ -z "$modelpack" ]; then
        while [ $return_value -eq 0 ] && ! readlink -f $modelpack; do
            modelpack=$(dialog --stdout --title "Models not found" --inputbox "Enter location to download & store models, do not use ~ " 0 0 "$modelpack")
            return_value=$?
        done
    fi
	[ ! $return_value -eq 0 ] && fatalerror "Models not downloaded. Cancelling"
	mkdir -p $modelpack
    if [ ! -e $modelpack/Models_Starterpack.tar.gz ]; then
        wget -P $modelpack https://nlspraak.ewi.utwente.nl/open-source-spraakherkenning-NL/Models_Starterpack.tar.gz || fatalerror "Unable to download models from nlspraak.ewi.utwente.nl!"
    fi
	tar -xvzf $modelpack/Models_Starterpack.tar.gz -C $modelpack || fatalerror "Failure during extraction of models"
    if [ ! -e models ]; then
        ln -s -f $modelpack/Models models
    fi
fi
[ ! -d models/NL ] && fatalerror "Something went wrong: models were not installed."

if [ ! -e models/Patch1 ]; then
	modelpack=$(readlink -f models)/..
	if [ ! -e $modelpack/Models_Patch1.tar.gz ]; then
        wget -P $modelpack https://nlspraak.ewi.utwente.nl/open-source-spraakherkenning-NL/Models_Patch1.tar.gz || fatalerror "Unable to download Patch1 model from nlspraak.ewi.utwente.nl!"
    fi
	tar -xvzf $modelpack/Models_Patch1.tar.gz -C $modelpack || fatalerror "Failure during extraction of models"

    rm $modelpack/Models_Patch1.tar.gz
fi

if [ ! -e models/Lang_OH ]; then
	modelpack=$(readlink -f models)/..
	if [ ! -e $modelpack/oral_history_models.tar.gz ]; then
        wget -P $modelpack https://applejack.science.ru.nl/downloads/oral_history_models.tar.gz || fatalerror "Unable to download oral history models from applejack.science.ru.nl!"
    fi
	tar -xvzf $modelpack/oral_history_models.tar.gz -C $modelpack || fatalerror "Failure during extraction of models"

    rm $modelpack/oral_history_models.tar.gz
fi


#
# Correct hardcoded paths in existing configuration files:

#for original models from twente:
find -name "*.conf" | xargs sed -i "s|/home/laurensw/Documents|$modelpack|g"

#for oral_history:
find -name "*.conf" | xargs sed -i "s|/vol/customopt/kaldi/egs/Kaldi_NL|$modelpack|g"

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
# Hints:
# On Fedora/Ubuntu install Sox normally ('yum install sox'/'apt install sox')
# To get mp3 support on Fedora:
#  yum install --nogpgcheck http://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-stable.noarch.rpm http://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-stable.noarch.rpm
#  yum install --nogpgcheck sox-plugins-freeworld
# To get mp3 support on Ubuntu:
#  apt install libsox-fmt-mp3
#

#
# create symlinks to the scripts
#
ln -s -f $kaldiroot/egs/wsj/s5/steps steps
ln -s -f $kaldiroot/egs/wsj/s5/utils utils

