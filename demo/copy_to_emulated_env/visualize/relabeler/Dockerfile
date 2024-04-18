FROM python:3.11.9-bookworm

RUN apt-get update && apt-get upgrade -y && pip install Flask==3.0.3 pyyaml==6.0.1 prometheus-client==0.20.0 requests==2.31.0

COPY ./ /opt/relabeler/

ENV PYTHONPATH /opt/relabeler

WORKDIR /opt/relabeler

ENTRYPOINT [ "python", "main.py" ]
#ENTRYPOINT [ "/usr/bin/bash", "-c" ]
