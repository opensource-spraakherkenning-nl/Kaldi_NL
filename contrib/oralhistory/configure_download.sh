#!/bin/bash
(return 0 2>/dev/null) && sourced=1 || sourced=0
if [ $sourced -eq 0 ]; then
    echo "this script should not be run directly but through configure.sh in the kaldi_nl root directory">&2
fi

if [ ! -e models/Lang_OH ]; then
    if [ ! -e oral_history_models.tar.gz ]; then
        wget https://applejack.science.ru.nl/downloads/oral_history_models.tar.gz || fatalerror "Unable to download oral history models from applejack.science.ru.nl!"
    fi
    tar -C models --strip-components 1 -xvzf oral_history_models.tar.gz || fatalerror "Failure during extraction of models"

    rm oral_history_models.tar.gz

    #correct absolute paths
    find -name "*.conf" | xargs sed -i "s|/vol/customopt/kaldi/egs/Kaldi_NL/Models|$modelpack|g"
    find -name "*.conf" | xargs sed -i "s|/vol/customopt/kaldi/egs/Kaldi_NL|$root|g" #probably redundant
fi
