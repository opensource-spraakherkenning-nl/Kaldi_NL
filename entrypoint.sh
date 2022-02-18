#!/bin/sh

# Entrypoint for containers, downloads models at run-time rather than built-time if not available yet

ARGS="$*"

if [ -n "$modelpack" ] && [ ! -e "$modelpack/Models" ]; then
    #shellcheck disable=SC2086
    set -- $MODELS
    export NODOWNLOAD=0
    #shellcheck disable=SC1091
    . local/configure_download.sh
fi

if [ -n "$ARGS" ]; then
    exec $ARGS
else
    exec /bin/bash -l
fi
