# How to contribute?

Follow these instructions if you have your own models and decode scripts and want them included in Kaldi-NL. We
encourage you to contribute your work and make more Dutch ASR research findable and usable.

Models are never stored in this git repository but are downloaded from some external source.

* You will need to put all your models into an archive (``tar.gz``) and make it available for download from a webserver.
    * Configuration files provided along with your models may reference certain absolute paths (always ending in `/Models/` (case-sensitive) !), these will be automatically translated upon installation. Any other absolute path is invalid!
    * Do not duplicate data that is already in another model and never overwrite data from other models: choose unique
      directory/file names for your model.
* create a directory in `contrib/`, say we call it `my-asr` for example. Within this directory:
* write a `configure_download.sh` script that downloads your models into the `models/` directory.
    * If you need user interaction in your script, use ``dialog``. This may be needed to query a
      username/password if your models are behind an authentication wall. However, please
      always ensure that user interaction can be bypassed through the setting of environment variables,
      so your script is also viable in automated environments.
    * It is best to copy and adapt one of the existing scripts as an example
* add your ``decode*.sh`` script(s), keep it as minimal as possible and source
    ``contrib/radboud_shared/decode_include.sh`` from your script instead to do the hard work.
* Add and commit all you added to `contrib/` to git
* Do a pull request after you confirmed everything is working properly

Anybody can now obtain your models and decoding pipeline by configuring Kaldi-NL as `./configure.sh my-asr`

