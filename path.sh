#!/bin/bash
if [ -z "$KALDI_ROOT" ] && [ -z "$LM_PREFIX" ]; then
    HOST=$(hostname)
    if [ "$HOST" = "mlp01" ]; then
        #production installation for webservices on applejack, Nijmegen
        #set KALDI_ROOT by activating LaMachine environment
        source /home/proycon/bin/lamachine-weblamachine-activate
    elif [ "${HOST:0:3}" = "mlp" ]; then
        #we're running in Nijmegen on the normal installation for users
        #set KALDI_ROOT by activating LaMachine environment
        source /vol/customopt/bin/lamachine-activate
    fi
fi
if [ -z "$KALDI_ROOT" ]; then
    echo "Kaldi root not set! do an export KALDI_ROOT manually!" >&2
    exit 2
fi
[ -f $KALDI_ROOT/tools/env.sh ] && . $KALDI_ROOT/tools/env.sh
export PATH=$PWD/utils/:$KALDI_ROOT/src/bin:$KALDI_ROOT/tools/openfst/bin:$KALDI_ROOT/tools/sctk/bin:$KALDI_ROOT/src/fstbin/:$KALDI_ROOT/src/gmmbin/:$KALDI_ROOT/src/featbin/:$KALDI_ROOT/src/lm/:$KALDI_ROOT/src/sgmmbin/:$KALDI_ROOT/src/sgmm2bin/:$KALDI_ROOT/src/fgmmbin/:$KALDI_ROOT/src/latbin/:$KALDI_ROOT/src/nnetbin:$KALDI_ROOT/src/nnet2bin/:$KALDI_ROOT/src/kwsbin:$KALDI_ROOT/src/online2bin/:$KALDI_ROOT/src/ivectorbin/:$KALDI_ROOT/src/lmbin/:$KALDI_ROOT/src/nnet3bin/:$PWD:$PATH
export LC_ALL=C #do we really need this?? I'd rather have a UTF-8 locale! (proycon)
