#!/bin/bash
(return 0 2>/dev/null) && sourced=1 || sourced=0
if [ $sourced -eq 0 ]; then
    echo "this script should not be run directly but through configure.sh in the kaldi_nl root directory">&2
fi

fatalerror() {
    echo "$*" >&2
    exit 2
}

#
# setup kaldi_root
#
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
    kaldiroot=$KALDI_ROOT
else
    kaldiroot=$KALDI_ROOT
fi
return_value=0

if [ ! -d $kaldiroot/egs ]; then
    while [ ! -d $kaldiroot/egs ] && [ $return_value -eq 0 ]; do
        kaldiroot=$(dialog --stdout --title "KALDI_ROOT not properly set" --inputbox "Enter location of your KALDI installation " 0 0 "$kaldiroot")
        return_value=$?
    done
    [ ! $return_value -eq 0 ] && echo "KALDI_ROOT not set. Cancelling" && exit 1
    echo -e "#!/bin/sh\nexport KALDI_ROOT=$kaldiroot" > path.$(hostname).sh
fi

# check for presence of java and available memory
#
messages=
[ $(which sox) ] || messages="${messages}## Warning: SOX not found, please install before using the decode script.\n"
[ "$(sox -h | grep 'AUDIO FILE FORMATS' | grep ' mp3 ')" ] || messages="${messages}## Warning: mp3 support for SOX is not installed.\n"
[ $(which time) ] || messages="${messages}## Warning: TIME not found, please install before using the decode script.\n"
[ $(which java) ] || messages="${messages}## Warning: JAVA not found, please install before using the decode script.\n"
[ $(which perl) ] || messages="${messages}## Warning: Perl not found, please install before using the decode script.\n"
[ $(which python3) ] || messages="${messages}## Warning: Python (3+) not found, please install before using the decode script.\n"
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
ln -s -f $kaldiroot/egs/wsj/s5/steps steps || fatalerror "unable to create link to $kaldiroot/egs/wsj/s5/steps"
ln -s -f $kaldiroot/egs/wsj/s5/utils utils || fatalerror "unable to create link to $kaldiroot/egs/wsj/s5/utils"

#set permissive permissions
chmod -R a+r .
