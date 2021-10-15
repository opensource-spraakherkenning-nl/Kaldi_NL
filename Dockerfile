FROM proycon/lamachine:core
MAINTAINER Maarten van Gompel <proycon@anaproy.nl>
LABEL description="A LaMachine installation with Kaldi NL and Oral History (CLST)"

# (Set this to the *public* domain you want to access this service on,
# HTTPS should be handled by your own reverse proxy, LaMachine does
# not provide one)

#RUN lamachine-config lm_base_url https://your.domain.here
#RUN lamachine-config force_https yes

# The oral history webservice will be served on the /oralhistory path

# (opt-out sending some basic anonymized statistics about the installation)
#RUN lamachine-config private true

# (set this to your own)
#RUN lamachine-config maintainer_name "Your name here"
#RUN lamachine-config maintainer_mail "your@mail.here"

# (By default, there is no authentication on the service,
# which is most likely not what you want. You can connect
# your own Oauth2/OpenID Connect authorization provider as follows,
# the example uses the CLARIAH authentication provider):

#RUN lamachine-config oauth_auth_url "https://authentication.clariah.nl/Saml2/OIDC/authorization"
#RUN lamachine-config oauth_token_url "https://authentication.clariah.nl/OIDC/token"
#RUN lamachine-config oauth_userinfo_url "https://authentication.clariah.nl/OIDC/userinfo"

# (shared oauth2 client ID)
#RUN lamachine-config oauth_client_id "<your client id here>"

# (shared oauth2 client secret (always keep this private))
#RUN lamachine-config oauth_client_secret "<your client secret here>"

# (See https://github.com/proycon/LaMachine/tree/master/docs/service#openid-connect for
# extra documentation on authentication
# - the oauth client id and client secret must be registered with/provider by your
#   authentication provider
# - the callback URL to register with the authentication provider, for the oralhistory
#   webservice,  will be https://your.domain/oralhistory/login)

# (this is the mount point where the external volume can be mounted that holds all user-data for the webservice)
# (i.e. the input and output files users upload and obtain. Uncomment all this if you want to store the data
# within the container (not recommended) or if you're not planning on using the webservice anyway)
RUN lamachine-config shared_www_data yes
RUN lamachine-config move_share_www_data yes
VOLUME ["/data"]

# (python-core is only there because we need numpy):
RUN lamachine-add python-core
# (this is the portal interface server on the root URL, comment it if you don't want it)
RUN lamachine-add labirinto
# (this is the backend):
RUN lamachine-add kaldi_nl
# (this is webservice frontend)
RUN lamachine-add oralhistory

# (this step performs all the actual actions defined above)
RUN lamachine-update

# (If you're not interested in the webservice but only in the
# command-line interface, then set this CMD *instead of* the ENTRYPOINT)
#CMD /bin/bash -l

ENTRYPOINT [ "/usr/local/bin/lamachine-start-webserver", "-f" ]
