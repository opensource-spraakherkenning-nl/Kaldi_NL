#!/bin/bash
(return 0 2>/dev/null) && sourced=1 || sourced=0
if [ $sourced -eq 0 ]; then
    echo "this script should not be run directly but through configure.sh in the kaldi_nl root directory">&2
fi

#Set model directory
if [ -d models ] && [ -z "$modelpack" ]; then
    modelpack=$(realpath models)
elif [ ! -d models/NL ] && [ -z "$modelpack" ]; then
    while [ $return_value -eq 0 ] && ! readlink -f $modelpack; do
        modelpack=$(dialog --stdout --title "Models not found" --inputbox "Enter location to download & store models, do not use ~ " 0 0 "models")
        return_value=$?
    done
    [ ! $return_value -eq 0 ] && fatalerror "Models not downloaded. Cancelling"
fi
[ -z "$modelpack" ] && fatalerror "Model base directory is empty"
mkdir -p "$modelpack" || fatalerror "Model base directory $modelpack does not exist and unable to create"
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
