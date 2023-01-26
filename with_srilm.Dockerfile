FROM proycon/kaldi_nl
#or:
#FROM proycon/kaldi

RUN apt-get update && \
    apt-get install -y --no-install-recommends gawk

ENV SRILM=/opt/kaldi/tools/srilm

RUN mkdir /opt/kaldi/tools/srilm

# This requires you to provide the srilm.tar.gz yourself in the directory where you are building this container!
# SRI demands you fill a download form and add data, so this is not automated. Make sure to use version 1.7.3 or above

COPY srilm.tar.gz /opt/kaldi/tools/srilm/srilm.tar.gz

RUN cd /opt/kaldi/tools &&\
    extras/install_liblbfgs.sh &&\
    cd /opt/kaldi/tools/srilm && tar -xzf srilm.tar.gz &&\
    mtype=$(sbin/machine-type) &&\
    echo HAVE_LIBLBFGS=1 >> common/Makefile.machine.$mtype &&\
    grep ADDITIONAL_INCLUDES common/Makefile.machine.$mtype | \
        sed 's|$| -I$(SRILM)/../liblbfgs-1.10/include|' \
        >> common/Makefile.machine.$mtype &&\
    grep ADDITIONAL_LDFLAGS common/Makefile.machine.$mtype | \
        sed 's|$| -L$(SRILM)/../liblbfgs-1.10/lib/ -Wl,-rpath -Wl,$(SRILM)/../liblbfgs-1.10/lib/|' \
        >> common/Makefile.machine.$mtype &&\
    make && cp bin/$mtype/* /usr/local/bin/ && echo "export SRILM=/opt/kaldi/tools/srilm" >> /opt/kaldi/tools/env.sh

