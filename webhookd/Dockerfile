FROM python:3.10
RUN apt update && apt install -y jq
USER $USER
RUN curl -s https://raw.githubusercontent.com/ncarlier/webhookd/master/install.sh | bash
RUN mkdir -p /data
ENV PATH="${PATH}:/root/.local/bin"
CMD [ "webhookd" ]