#!/bin/bash

[ $(which dialog) ] || { echo 'Please install "dialog" to use this configurator.' >&2; exit 1; };
[ $(which realpath) ] || { echo 'Please install "realpath" to use this configurator.' >&2; exit 1; };

root=$(realpath $(dirname $0))
cd $root

source local/configure_basic.sh
source local/configure_download.sh
if [ -z "$1" ]; then
    source local/configure_decode.sh
fi
