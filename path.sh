#!/bin/bash
if [ -z "$KALDI_ROOT" ]; then
    HOST=$(hostname)
    DOMAIN=$(hostname -d)
    if [ -x "path.$HOST.sh" ]; then
        #source host-specific path.sh
        source "path.$HOST.sh"
    elif [ -x "path.$DOMAIN.sh" ]; then
        #source domain specific path.sh
        source "path.$DOMAIN.sh"
    elif [ -x "path.custom.sh" ]; then
        #source custom path.sh
        source "path.custom.sh"
    fi
fi
if [ -z "$KALDI_ROOT" ]; then
    echo "Kaldi root not set! do an export KALDI_ROOT manually!" >&2
    exit 2
fi
[ -f $KALDI_ROOT/tools/env.sh ] && . $KALDI_ROOT/tools/env.sh
export PATH=$PWD/utils/:$KALDI_ROOT/src/bin:$KALDI_ROOT/tools/openfst/bin:$KALDI_ROOT/tools/sctk/bin:$KALDI_ROOT/src/fstbin/:$KALDI_ROOT/src/gmmbin/:$KALDI_ROOT/src/featbin/:$KALDI_ROOT/src/lm/:$KALDI_ROOT/src/sgmmbin/:$KALDI_ROOT/src/sgmm2bin/:$KALDI_ROOT/src/fgmmbin/:$KALDI_ROOT/src/latbin/:$KALDI_ROOT/src/nnetbin:$KALDI_ROOT/src/nnet2bin/:$KALDI_ROOT/src/kwsbin:$KALDI_ROOT/src/online2bin/:$KALDI_ROOT/src/ivectorbin/:$KALDI_ROOT/src/lmbin/:$KALDI_ROOT/src/nnet3bin/:$PWD:$PATH
export LC_ALL=C #do we really need this?? I'd rather have a UTF-8 locale! (proycon)
