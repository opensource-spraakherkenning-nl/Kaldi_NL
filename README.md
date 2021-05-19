# Kaldi NL


## Introduction

These scripts may be used to convert speech contained in audio files into text using the Kaldi open-source speech
recognition system.

## Installation

The software is run from the directory where you cloned this repository.  Kaldi NL depends on a working installation of
Kaldi (http://kaldi-asr.org/), Java, Perl, Python 3, and SoX (http://sox.sourceforge.net/).  They have been tested on
Ubuntu Linux 16.10, 18.04 LTS and 20.04 LTS but are expected to run on other Linux distributions as well.

Before running the decoder for the first time, or when you need to change its configuration, please run ``configure.sh``.
The ``configure.sh`` script will ask for the location of your Kaldi installation, and for the location to put the models.

A ``decode.sh`` script is dynamically generated based on the selected models, as
are the decoding graphs needed for Kaldi. This last step may take a while (but on a 16GB machine usually no more than an hour or so).

It is also possible to install a completely pre-made decoder, as supplied by certain partners
in that case you can specify one or more of the following models as a parameter to ``configure.sh``:

* **oralhistory** - These are models and decoder graphs for oral history interviews (OH), parliamentary talks (PR), and daily conversations (GN) created by Emre Yilmaz, CLST, Radboud University, Nijmegen. A decode script is supplied for for each, respectively named ``decoder_OH.sh``, ``decoder_PR.sh`` and ``decode_GN.sh``.

Kaldi NL, with all its dependencies, is also included as an optional extra in the [LaMachine
meta-distribution](https://proycon.github.io/LaMachine) , this may make it more readily usable/deployable by end-users.
For instance in containerised (e.g. docker) or virtual machine form.

The use of these scripts under macOS is not supported, but we have been able to make them work. Just as with the default
Kaldi recipes, most issues stem from the use of the standard GNU tools. So use gcp, gawk, gsed, gtime, gfile, etc
in place of cp, awk, sed, time, and file.
If you encounter any other issues with these script on macOS, please let us know, especially if you've been able to fix them :-)

## Usage

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

### Web Interface

The docker image ships with a web interface based on [CLAM](https://proycon.github.io/clam/). To use the web interface, start the web server by running the ``lamachine-start-webserver`` command. The web interface for Kaldi-NL can be found on ``http://<docker-container-ip>/oralhistory``.


## Details

Due to the nature of decoding with Kaldi, its use of FSTs, and the size of the models in the starterpack, a machine with
less than 8GB of memory will probably not be able to compile the graphs or provide very useful ASR performance. In any case, make sure the number of jobs does not crush your machine (use the --nj parameter). Also be advised that building the docker image requires at least 60GiB of available disk space.

In the starterpack of Dutch models, the best current performance can be expected when using:

* AM: ``NL/UTwente/HMI/AM/CGN_all/nnet3_online/tdnn``
    * (slightly better, but much slower: ``NL/UTwente/HMI/AM/CGN_all/nnet3/tdnn_lstm``
* LM: ``v1.0/KrantenTT.3gpr.kn.int.arpa.gz``
* Rescore LM: ``NL/UTwente/HMI/LM/KrantenTT`` & ``v1.0/KrantenTT.4gpr.kn.int.arpa.gz``

## Contribute your own models!

Please see [the contribution guidelines](CONTRIBUTING.md) and contribute your own models and decoding pipelines!

## Licensing

Kaldi-NL is licensed under the Apache 2.0 licence, this concerns only the scripts directly included in this repository
and where not explicitly noted otherwise. Note that the various models that can be obtained through Kaldi-NL are never by
default covered by this license and may often be licensed differently.


