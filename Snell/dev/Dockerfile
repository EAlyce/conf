FROM debian:bookworm-slim

ARG TARGETPLATFORM
ENV TARGETPLATFORM=${TARGETPLATFORM:-linux/amd64}

RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates wget unzip curl tini && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

ENV SNELL_VERSION=v4.1.1
ENV SNELL_URL=https://dl.nssurge.com/snell/snell-server-${SNELL_VERSION}-linux
RUN case "${TARGETPLATFORM}" in \
        "linux/amd64")  SNELL_ARCH="amd64" ;; \
        "linux/386")    SNELL_ARCH="i386" ;; \
        "linux/arm64")  SNELL_ARCH="aarch64" ;; \
        "linux/arm/v7") SNELL_ARCH="armv7l" ;; \
        *) echo "不支持的平台: ${TARGETPLATFORM}" && exit 1 ;; \
    esac && \
    curl -L -o snell.zip "${SNELL_URL}-${SNELL_ARCH}.zip" && \
    unzip snell.zip -d /snell && \
    rm snell.zip && \
    chmod +x /snell/snell-server

COPY entrypoint.sh /snell/
RUN chmod +x /snell/entrypoint.sh


WORKDIR /snell

ENTRYPOINT ["/usr/bin/tini", "--", "/snell/entrypoint.sh"]

