FROM ncarlier/webhookd
USER root
RUN apk add curl git python3-dev py3-pip
RUN pip install rdflib tqdm requests
USER $USER
RUN mkdir -p /data
