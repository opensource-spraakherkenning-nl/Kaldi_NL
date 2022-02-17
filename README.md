# Kaldi NL


## Introduction

These scripts may be used to convert speech contained in audio files into text using the Kaldi open-source speech
recognition system.

## Installation

The software is run from the directory where you cloned this repository.  Kaldi NL depends on a working installation of
Kaldi (http://kaldi-asr.org/), Java, Perl, Python 3, and SoX (http://sox.sourceforge.net/).  They have been tested on
Ubuntu Linux 16.10, 18.04 LTS and 20.04 LTS but are expected to run on other Linux distributions as well. A container
image is provided that contains all of the dependencies and models.

Before running the decoder for the first time, or when you need to change its configuration, please run ``configure.sh``.
The ``configure.sh`` script will ask for the location of your Kaldi installation, and for the location to put the models.

A ``decode.sh`` script is dynamically generated based on the selected models, as
are the decoding graphs needed for Kaldi. This last step may take a while (but on a 16GB machine usually no more than an hour or so).

It is also possible to install a completely pre-made decoder with models as supplied by certain partners
in that case you can specify one or more of the following models as a parameter to ``configure.sh``:

* `utwente` - **Starter Pack** - These are the dutch models and decoder graphs originally provided with Kaldi_NL
* `radboud_OH` - **Oral History** - These are dutch models and decoder graphs trained on oral history interviews
* `radboud_PR` - **Parliamentary Talks** - These are dutch models and decoder graphs trained on parliamentary talks
* `radboud_GN` - **Daily Conversation** - These are dutch models and decoder graphs trained on daily conversations

A decode script is supplied for for each, respectively named ``decoder_OH.sh``, ``decoder_PR.sh`` and ``decode_GN.sh``.

Kaldi NL, with all its dependencies, is also included as an optional extra in the [LaMachine
meta-distribution](https://proycon.github.io/LaMachine) , this may make it more readily usable/deployable by end-users.
For instance in containerised (e.g. docker) or virtual machine form.

The use of these scripts under macOS is not supported, but we have been able to make them work. Just as with the default
Kaldi recipes, most issues stem from the use of the standard GNU tools. So use gcp, gawk, gsed, gtime, gfile, etc
in place of cp, awk, sed, time, and file.
If you encounter any other issues with these script on macOS, please let us know, especially if you've been able to fix them :-)

### Container with Web Interface

For end-users and hosting partners, we provide a web-interface offering easy access to *Automatic Speech Recognition for
Dutch* (`asr_nl`), containing all the models from Radboud University. A container image is available to deploy this
webservice locally, please see: [Automatic Speech Recognition for
Dutch](https://github.com/opensource-spraakherkenning-nl/asr_nl) for the webservice source and further instructions.

### Container without Web Interface

This contains the `asr_nl` models but not the webservice.
You can pull a prebuilt image from the Docker Hub registry using docker as follows:

```
$ docker pull proycon/lamachine:kaldi_nl
```

You can also build the container image yourself using a tool like ``docker build``, which is the recommended option if you are deploying this
in your own infrastructure. In that case will want adjust the ``Dockerfile`` to set some parameters.

Run the container as follows:

```
$ docker run -t -i -v /your/data/path:/data proycon/lamachine:kaldi_nl
```

The `decode.sh` command from the next section can be appended to the docker run line.

## Usage

The decode script is called with:

`./decode.sh [options] <speech-dir>|<speech-file>|<txt-file containing list of source material> <output-dir>`

If you want to use one of the pre-built models from `asr_nl`, use `decode_OH.sh` or any of the other options instead of the generic `decode.sh`.

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

The models for Dutch (asr_nl) that are installable through this Kaldi_NL distribution are licensed under the [Creative Commons
Attribution-NonCommercial-ShareAlike license (4.0)](https://creativecommons.org/licenses/by-nc-sa/4.0/legalcode).


