These scripts may be used to convert speech contained in audio files into text using the Kaldi open-source speech 
recognition system. Running them requires installation of Kaldi (http://kaldi-asr.org/) and SoX (http://sox.sourceforge.net/).

Before running the decoder for the first time, make sure to set KALDI_ROOT to the proper value in path.sh and set the 
(desired) location of the models at model_root in configure.sh, before running that. The configure.sh script will set up the 
decoder, including creating FST's from the (automatically downloaded) acoustic and language models.

The decode script is called with:

'./decode.sh [options] <speech-dir>|<speech-file>|<txt-file containing list of source material> <output-dir>'

All parameters before the last one are automatically interpreted as one of the three types listed above. 
After the process is done, the main results are produced in <output-dir>/1Best.ctm. This file contains a list of all
words that were recognised in the audio, with one word per line. The lines follow the standard .ctm format:

'<source file> 1 <start time> <duration> <word hypothesis> <posterior probability>'

As part of the transcription process, the LIUM speech diarization toolkit is utilized. This produces a directory 
'<output-dir>/liumlog', which contains .seg files that provide information about the speaker diarization. For more
information on the content of these files, please visit http://www-lium.univ-lemans.fr/diarization/.
