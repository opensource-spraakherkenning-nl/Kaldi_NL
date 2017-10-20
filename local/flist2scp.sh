#!/bin/bash

#
#    Converts list of audio files in test.flist into a the format required by Kaldi.
#    Specifically, the following files are created:
#       - wav.scp         contains a list of the source audio files + (sox) instructions for converting to 16khz mono
#       - segments        a list of audio segments to transcribe of up to ~20 seconds in length
#       - utt2spk         the segments list with (artificial) speaker information
#

lines=()
basefiles=()

# take care of uem and stm files if present
[ -e $1/*.glm ] && cat $1/*.glm 2>&1 >$1/ALL/all.glm
[ -e $1/*.uem ] && cat $1/*.uem 2>&1 | sort >$1/ALL/test.uem
[ -s $1/ALL/test.uem ] && uemopt="--uem $1/ALL/test.uem"
cat $1/*.stm 2>&1 >$1/ALL/ref.stm
[ -e $1/ALL/all.glm ] && cat $1/*.stm | csrfilt.sh -s -i stm -t ref $1/ALL/all.glm >$1/ALL/ref.stm

>$1/ALL/wav.scp
>$1/ALL/segments
>$1/ALL/utt2spk.tmp

# iterate over list and prepare for each file
while read line; do	
	basefile=$(basename $line .${line##*.})
	echo "$basefile sox $line -r 16k -e signed-integer -t wav - remix - |" >>$1/ALL/wav.scp 
	basefiles+=($basefile)
	lines+=($line)
done <$1/test.flist

# Do diarization.   
# If needed, make a temporary wav file for each input file, as this is what the diarization requires
numjobs="${#lines[@]-1}"
$cmd --max-jobs-run $nj JOB=1:$numjobs $1/ALL/liumlog/segmentation.JOB.log \
    lines=\( ${lines[@]} \)\; basefiles=\( ${basefiles[@]} \)\; idx=JOB\; line=\${lines[\$idx-1]}\; basefile=\${basefiles[\$idx-1]}\; \
    { [ ! \${line##*.} == \'wav\' ] \&\& sox \$line -t wav $1/\${basefile}.wav \; } \; \
    { [ ! -e $1/ALL/liumlog/\$basefile.seg ] \&\& local/diarization.sh $uemopt $1/\$basefile.wav $1/ALL/liumlog 2>&1 \; } \; \
    { [ ! \${line##*.} == \'wav\' ] \&\& rm $1/\${basefile}.wav \; } \; \
	echo \$line \>\>$1/ALL/liumlog/done.log
    
for basefile in "${basefiles[@]}"; do
	cat $1/ALL/liumlog/$basefile.seg | grep -v ";;" | awk '{s++; printf "%s.%05d %s %.3f %.3f\n", $1, s, $1, $3/100, ($3+$4)/100}' >>$1/ALL/segments	
	cat $1/ALL/liumlog/$basefile.seg | grep -v ";;" | awk '{s++; printf "%s.%05d %s-%s\n", $1, s, $1, $NF}' >>$1/ALL/utt2spk.tmp
done

cat $1/ALL/utt2spk.tmp | sort -k2,2 -k1,1 -u >$1/ALL/utt2spk
rm $1/ALL/utt2spk.tmp
