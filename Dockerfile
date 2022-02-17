FROM proycon/kaldi
ARG BRANCH="master"
ARG MODELS="utwente radboud_OH radboud_PR radboud_GN"
ARG MODELDIR="/opt/Kaldi_NL/models"
ENV modelpack=$MODELDIR
RUN apt-get update && \
    apt-get install -y --no-install-recommends python3-numpy default-jre-headless procps dialog
RUN git clone --branch "$BRANCH" https://github.com/opensource-spraakherkenning-nl/Kaldi_NL.git /opt/Kaldi_NL
ENV KALDI_ROOT=/opt/kaldi
RUN cd /opt/Kaldi_NL && ./configure.sh $MODELS


WORKDIR /opt/Kaldi_NL
CMD /bin/bash -l
