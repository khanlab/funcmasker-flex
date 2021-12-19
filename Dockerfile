FROM python:3.8.12-bullseye

MAINTAINER alik@robarts.ca

COPY . /src/

RUN apt install -y graphviz-dev && pip install --upgrade pip && pip install /src

ENV PATH=/src/ext-bin:$PATH

ENTRYPOINT [ "funcmasker-flex" ]
