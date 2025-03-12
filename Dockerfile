FROM postgres:latest

RUN apt-get update && apt-get install -y \
    build-essential \
    postgresql-server-dev-all \
    git \
    && rm -rf /var/lib/apt/lists/*

COPY . /usr/src/logsddl
WORKDIR /usr/src/logsddl

RUN make && make install
