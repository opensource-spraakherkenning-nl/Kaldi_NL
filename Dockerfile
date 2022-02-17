#note: this is the non-GPU function, suitable for production use but less suitable for training!
FROM debian:11 AS kaldi
LABEL org.opencontainers.image.authors="Maarten van Gompel <proycon@anaproy.nl>"
LABEL description="Kaldi_NL"

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        g++ \
        make \
        automake \
        autoconf \
        bzip2 \
        unzip \
        wget \
        sox \
        libtool \
        git \
        subversion \
        python2.7 \
        python3 \
        zlib1g-dev \
        ca-certificates \
        gfortran \
        patch \
        ffmpeg \
	vim && \
    rm -rf /var/lib/apt/lists/*

RUN ln -s /usr/bin/python3 /usr/bin/python
ENV KALDI_ROOT=/opt/kaldi
WORKDIR /opt/kaldi/
CMD /bin/bash -l

#multistage build:
FROM kaldi
ARG BRANCH="master"
ARG MODELS="utwente radboud_OH radboud_PR radboud_GN"
RUN git clone --depth 1 https://github.com/kaldi-asr/kaldi.git /opt/kaldi
RUN cd /opt/kaldi/tools && \
       ./extras/install_mkl.sh && \
       make -j $(nproc) && \
       cd /opt/kaldi/src && \
       ./configure --shared && \
       make depend -j $(nproc) && \
       make -j $(nproc) && \
       find /opt/kaldi -type f \( -name "*.o" -o -name "*.la" -o -name "*.a" \) -exec rm {} \; && \
       find /opt/intel -type f -name "*.a" -exec rm {} \; && \
       find /opt/intel -type f -regex '.*\(_mc.?\|_mic\|_thread\|_ilp64\)\.so' -exec rm {} \; && \
       rm -rf /opt/kaldi/.git

RUN git clone --branch "$BRANCH" https://github.com/opensource-spraakherkenning-nl/Kaldi_NL.git /opt/Kaldi_NL
RUN cd /opt/Kaldi_NL && ./configure.sh $MODELS

WORKDIR /opt/Kaldi_NL
