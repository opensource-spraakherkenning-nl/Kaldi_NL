# How to contribute?

Follow these instructions if you have your own models and decode scripts and want them included in Kaldi-NL. We
encourage you to contribute your work and make more Dutch ASR research findable and usable.

Models are never stored in this git repository but are downloaded from some external source. You will need to put all your models into an archive (``tar.gz``) and make it available for download from a webserver. Subsequently, do the following:

* create a directory in `contrib/`, say we call it `my-asr` for example. Within this directory:
* write a `configure_download.sh` script that downloads your models into the `models/` directory.
    * If you need user interaction in your script, use ``dialog``. This may be needed to query a
      username/password if your models are behind an authentication wall. However, please
      always ensure that user interaction can be bypassed through the setting of environment variables,
      so your script is also viable in automated environments.
* add your ``decode*.sh`` script(s)
* Add and commit all of this to git
* Do a pull request after you confirmed everything is working properly

Anybody can now obtain your models and decoding pipeline by configuring Kaldi-NL as `./configure.sh my-asr`

