FROM proycon/kaldi
LABEL org.opencontainers.image.title="kaldi" \
      org.opencontainers.image.authors="Maarten van Gompel <proycon@anaproy.nl>" \
      org.opencontainers.image.description="Kaldi models and scripts for Dutch ASR" \
      org.opencontainers.image.source="https://github.com/opensource-spraakherkenning-nl/Kaldi_NL/kaldi.Dockerfile"
ARG BRANCH="master"
ARG MODELS="utwente radboud_OH radboud_PR radboud_GN"
ENV MODELS=$MODELS
ARG MODELPATH="/opt/Kaldi_NL/models"
ENV modelpack=$MODELPATH
RUN apt-get update && \
    apt-get install -y --no-install-recommends python3-numpy default-jre-headless time procps dialog
RUN git clone --branch "$BRANCH" https://github.com/opensource-spraakherkenning-nl/Kaldi_NL.git /opt/Kaldi_NL
ENV KALDI_ROOT=/opt/kaldi
RUN cd /opt/Kaldi_NL &&\
    if [ "$modelpack" != "/opt/Kaldi_NL/models" ]; then export NODOWNLOAD=1; fi && \
    ./configure.sh $MODELS

#mount-point reserved for external models (set MODELPATH=/models to make use of this)
VOLUME [ "/models" ]

WORKDIR /opt/Kaldi_NL
ENTRYPOINT [ "/opt/Kaldi_NL/entrypoint.sh" ]
