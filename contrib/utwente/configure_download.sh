#!/bin/sh
(return 0 2>/dev/null) && sourced=1 || sourced=0
if [ $sourced -eq 0 ]; then
    echo "this script should not be run directly but through configure.sh in the kaldi_nl root directory">&2
fi

if [ ! -d models/NL ]; then
    if [ ! -e Models_Starterpack.tar.gz ]; then
        wget https://applejack.science.ru.nl/downloads/kaldi_nl_utwente/Models_Starterpack.tar.gz || fatalerror "Unable to download models from nlspraak.ewi.utwente.nl!"
    fi
	tar -C models --strip-components 1 -xvzf Models_Starterpack.tar.gz  || fatalerror "Failure during extraction of models"
    rm Models_Starterpack.tar.gz
fi
[ ! -d models/NL ] && fatalerror "Something went wrong: models were not installed."

if [ ! -e models/Patch1 ]; then
	if [ ! -e Models_Patch1.tar.gz ]; then
        wget https://applejack.science.ru.nl/downloads/kaldi_nl_utwente/Models_Patch1.tar.gz || fatalerror "Unable to download Patch1 model from nlspraak.ewi.utwente.nl!"
    fi
	tar -C models --strip-components 1 -xvzf Models_Patch1.tar.gz  || fatalerror "Failure during extraction of models"

    rm Models_Patch1.tar.gz
fi

# Correct hardcoded paths in existing configuration files:
find "$modelpack" -name "*.conf" | xargs sed -i "s|=.*/Models|=$modelpack|g"
