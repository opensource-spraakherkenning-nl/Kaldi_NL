#!/bin/bash

speaker=$1
audio=$2        # file to retrieve info from
segfile=$3      # segmentation output from LIUM

# get list of speakers in .seg
# speakers=`grep ';;' $2 | awk '{printf "%s ",$3} END {print ""}'`

# for speaker in $speakers; do
    trim=`grep -v ';;' $segfile | grep ${speaker}$ | awk '{printf "%.2f %.2f ", ($3-prev)/100, $4/100; prev=$3+$4}'`
    left=`sox $audio -e signed-integer -t wav - remix 1 trim $trim 2>/dev/null | sox - -n stat 2>&1 | grep "Mean    norm" | awk '{print $3}'`
    right=`sox $audio -e signed-integer -t wav - remix 2 trim $trim 2>/dev/null | sox - -n stat 2>&1 | grep "Mean    norm" | awk '{print $3}'`
    awk -v left=$left -v right=$right 'BEGIN {if (left>right) print 1; else print 2}'
#if [ $left -gt $right ]; then
#    echo 1
#else
#echo 2
# fi
#   echo "$speaker  left: $left right: $right"
# done