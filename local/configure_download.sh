#!/bin/bash
(return 0 2>/dev/null) && sourced=1 || sourced=0
if [ $sourced -eq 0 ]; then
    echo "this script should not be run directly but through configure.sh in the kaldi_nl root directory">&2
fi

#Set model directory
if [ ! -d models/NL ] && [ -z "$modelpack" ]; then
    if [ -d models ]; then
        modelpack=$(realpath models)
    else
        while [ $return_value -eq 0 ] && ! readlink -f $modelpack; do
            modelpack=$(dialog --stdout --title "Models not found" --inputbox "Enter location to download & store models, do not use ~ " 0 0 "models")
            return_value=$?
        done
        [ ! $return_value -eq 0 ] && fatalerror "Models not downloaded. Cancelling"
    fi
fi
mkdir -p $modelpack || fatalerror "Model base directory $modelpack does not exist and unable to create"
modelpack=$(realpath $modelpack)
#link to the model pack directory from the kaldi_nl root
if [ ! -e models ]; then
    ln -s -f $modelpack models
fi

#we need this very ugly patch,
#creating a symlink back to itself,
#otherwise certain models break
if [ ! -e models/Models ]; then
    ln -s $(realpath models) models/Models
fi

# get models
#
if [ ! -d models/NL ]; then
    if [ ! -e Models_Starterpack.tar.gz ]; then
        wget https://nlspraak.ewi.utwente.nl/open-source-spraakherkenning-NL/Models_Starterpack.tar.gz || fatalerror "Unable to download models from nlspraak.ewi.utwente.nl!"
    fi
	tar -C models --strip-components 1 -xvzf Models_Starterpack.tar.gz  || fatalerror "Failure during extraction of models"
    rm Models_Starterpack.tar.gz
fi
[ ! -d models/NL ] && fatalerror "Something went wrong: models were not installed."

if [ ! -e models/Patch1 ]; then
	if [ ! -e Models_Patch1.tar.gz ]; then
        wget https://nlspraak.ewi.utwente.nl/open-source-spraakherkenning-NL/Models_Patch1.tar.gz || fatalerror "Unable to download Patch1 model from nlspraak.ewi.utwente.nl!"
    fi
	tar -C models --strip-components 1 -xvzf Models_Patch1.tar.gz  || fatalerror "Failure during extraction of models"

    rm Models_Patch1.tar.gz
fi

# Correct hardcoded paths in existing configuration files:
find -name "*.conf" | xargs sed -i "s|/home/laurensw/Documents/Models|$modelpack|g"

for model in "$@"; do
    if [ -d "contrib/$model" ]; then
        if [ -e "contrib/$model/configure_download.sh" ]; then
            source "contrib/$model/configure_download.sh"
        fi
        for f in contrib/$model/decode*.sh; do
            ln -s $f $(basename $f)
        done
    else
        echo "Specified model ($model) not found, expected a directory $root/contrib/$model/">&2
        exit 2
    fi
done

chmod -R a+r models/
