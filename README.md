These scripts may be used to convert speech contained in audio files into text using the Kaldi open-source speech 
recognition system. Running them requires installation of Kaldi (http://kaldi-asr.org/), Java, and SoX (http://sox.sourceforge.net/).
They have been tested on Ubuntu 16.10, but are expected to run on other flavors of Linux as well. 

The use of these scripts under OSX is not supported, but we have been able to make them work. Just as with the default 
Kaldi recipes, most issues stem from the use of the standard bash tools. So use gcp, gawk, gsed, gtime, gfile, etc 
in place of cp, awk, sed, time, and file.
If you encounter any other issues with these script on OSX, please let us know, especially if you've been able to fix them :-)

Before running the decoder for the first time, or when you need to change its configuration, please run configure.sh.
The configure.sh script will ask for the location of your Kaldi installation, and for the location to put the models. 
Currently, a default starterpack of Dutch models will be downloaded automatically, but this procedure will change in the 
future to allow for easier sharing of newer and better models.
The decode.sh script is dynamically generated based on the selected models, as are the decoding graphs needed for Kaldi. This
last step may take a while (but on a 16GB machine usually no more than an hour or so). 

Due to the nature of decoding with Kaldi, its use of FSTs, and the size of the models in the starterpack, a machine with 
less than 8GB of memory will probably not be able to compile the graphs or provide very useful ASR performance. In any case,
make sure the number of jobs does not crush your machine (use the --nj parameter).

In the starterpack of Dutch models, the best current performance can be expected when using:
AM: NL/UTwente/HMI/AM/CGN_all/nnet3_online/tdnn
(slightly better, but much slower: NL/UTwente/HMI/AM/CGN_all/nnet3/tdnn_lstm)
LM: v1.0/KrantenTT.3gpr.kn.int.arpa.gz
Rescore LM: NL/UTwente/HMI/LM/KrantenTT & v1.0/KrantenTT.4gpr.kn.int.arpa.gz

The decode script is called with:

`./decode.sh [options] <speech-dir>|<speech-file>|<txt-file containing list of source material> <output-dir>`

All parameters before the last one are automatically interpreted as one of the three types listed above. 
After the process is done, the main results are produced in `<output-dir>/1Best.ctm`. This file contains a list of all
words that were recognised in the audio, with one word per line. The lines follow the standard .ctm format:

`<source file> 1 <start time> <duration> <word hypothesis> <posterior probability>`

In addition, some simple text files may be generated, as well as performance metrics in case the source material contains 
a suitable reference transcription in .stm format. There's also the option of using a .uem file in order to provide a
pre-segmentation or to limit the amount of audio to transcribe.

As part of the transcription process, the LIUM speech diarization toolkit is utilized. This produces a directory 
`<output-dir>/liumlog`, which contains .seg files that provide information about the speaker diarization. For more
information on the content of these files, please visit http://www-lium.univ-lemans.fr/diarization/.


