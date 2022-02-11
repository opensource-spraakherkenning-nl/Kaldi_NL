FROM proycon/lamachine:core
MAINTAINER Maarten van Gompel <proycon@anaproy.nl>
LABEL description="A LaMachine installation with Automatic Speech Recognition for Dutch (command-line usage only)"

# (opt-out sending some basic anonymized statistics about the installation)
#RUN lamachine-config private true

# (set this to your own)
#RUN lamachine-config maintainer_name "Your name here"
#RUN lamachine-config maintainer_mail "your@mail.here"

# (this is the mount point where the external volume can be mounted that holds all user-data for the webservice)
# (i.e. the input and output files users upload and obtain. Uncomment all this if you want to store the data
# within the container (not recommended) or if you're not planning on using the webservice anyway)
VOLUME ["/data"]

# (python-core is only there because we need numpy):
RUN lamachine-add python-core
# (this is the backend):
RUN lamachine-add kaldi_nl

# (this step performs all the actual actions defined above)
RUN lamachine-update

WORKDIR /usr/local/opt/kaldi_nl
CMD /bin/bash -l

