FROM python:3.8.12-bullseye

MAINTAINER alik@robarts.ca

COPY . /src/

RUN apt-get update && apt-get install -y libopenblas-dev libgraphviz-dev && pip install --upgrade pip && pip install /src

ENV PATH=/src/ext-bin:$PATH

ENTRYPOINT [ "funcmasker-flex" ]
