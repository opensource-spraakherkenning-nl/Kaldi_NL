#note: this is the non-GPU function, suitable for production use but less suitable for training!
FROM debian:11.2-slim
LABEL org.opencontainers.image.title="kaldi" \
      org.opencontainers.image.authors="Maarten van Gompel <proycon@anaproy.nl>" \
      org.opencontainers.image.description="Kaldi ASR system" \
      org.opencontainers.image.source="https://github.com/opensource-spraakherkenning-nl/Kaldi_NL/kaldi.Dockerfile"

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        bash \
        g++ \
        make \
        automake \
        autoconf \
        bzip2 \
        unzip \
        wget \
        sox \
        libsox-fmt-mp3 \
        libtool \
        git \
        subversion \
        python2.7-minimal \
        python3-minimal \
        zlib1g-dev \
        ca-certificates \
        gfortran \
        patch

RUN ln -s /usr/bin/python3 /usr/bin/python
ENV KALDI_ROOT=/opt/kaldi
WORKDIR /opt/kaldi/
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
       rm -rf /opt/kaldi/.git /opt/kaldi/tools/*gz /opt/kaldi/tools/openfst-*/src /opt/kaldi/tools/sctk*/src /opt/kaldi/windows /opt/kaldi/misc  && \
       apt-get remove -y autoconf automake &&\
       apt-get clean -y && \
       apt-get autoremove -y && \
       apt-get autoclean -y && \
       rm -rf /tmp/* && \
       rm -rf /var/lib/apt/lists/*

CMD /bin/bash -l
