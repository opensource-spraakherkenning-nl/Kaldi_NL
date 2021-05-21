FROM proycon/lamachine:core
MAINTAINER Maarten van Gompel <proycon@anaproy.nl>
LABEL description="A LaMachine installation with Kaldi NL and Oral History (CLST)"
#RUN lamachine-config lm_base_url https://your.domain.here
#RUN lamachine-config force_https yes
#RUN lamachine-config private true
#RUN lamachine-config maintainer_name "Your name here"
#RUN lamachine-config maintainer_mail "your@mail.here"
#(python-core is only there because we need numpy):
RUN lamachine-add python-core
RUN lamachine-add labirinto
RUN lamachine-add kaldi_nl
RUN lamachine-add oralhistory
RUN lamachine-update
CMD /bin/bash -l
