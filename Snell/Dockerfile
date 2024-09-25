# syntax=docker/dockerfile:1
FROM debian:bookworm

ARG TARGETPLATFORM
ENV TARGETPLATFORM=${TARGETPLATFORM:-linux/amd64}

RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y wget unzip curl tini && \
    rm -rf /var/lib/apt/lists/* && \
    case "${TARGETPLATFORM}" in \
        "linux/amd64")  SNELL_URL="https://dl.nssurge.com/snell/snell-server-v4.1.1-linux-amd64.zip" ;; \
        "linux/386")    SNELL_URL="https://dl.nssurge.com/snell/snell-server-v4.1.1-linux-i386.zip" ;; \
        "linux/arm64")  SNELL_URL="https://dl.nssurge.com/snell/snell-server-v4.1.1-linux-aarch64.zip" ;; \
        "linux/arm/v7") SNELL_URL="https://dl.nssurge.com/snell/snell-server-v4.1.1-linux-armv7l.zip" ;; \
        *) echo "Unsupported platform: ${TARGETPLATFORM}" && exit 1 ;; \
    esac && \
    wget -O snell.zip ${SNELL_URL} && \
    unzip snell.zip -d /snell && \
    rm snell.zip && \
    chmod +x /snell/snell-server

COPY entrypoint.sh /snell/
RUN chmod +x /snell/entrypoint.sh

WORKDIR /snell

ENTRYPOINT ["/usr/bin/tini", "--", "/snell/entrypoint.sh"]
