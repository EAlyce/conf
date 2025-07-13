FROM debian:bookworm

ARG TARGETPLATFORM
ENV TARGETPLATFORM=${TARGETPLATFORM:-linux/amd64}
ENV VERSION=v5.0.0

RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y wget unzip curl tini jq && \
    rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    case "${TARGETPLATFORM}" in \
        "linux/amd64")  ARCH="amd64" ;; \
        "linux/386")    ARCH="i386" ;; \
        "linux/arm64")  ARCH="aarch64" ;; \
        "linux/arm/v7") ARCH="armv7l" ;; \
        *) echo "Unsupported platform: ${TARGETPLATFORM}" && exit 1 ;; \
    esac; \
    URL="https://github.com/EAlyce/conf/raw/refs/heads/main/Snell/source/${VERSION}/snell-server-${VERSION}-linux-${ARCH}.zip"; \
    echo "Downloading from: ${URL}"; \
    wget -O snell.zip "${URL}"; \
    unzip snell.zip -d /snell; \
    rm snell.zip; \
    chmod +x /snell/snell-server

COPY entrypoint.sh /snell/
RUN chmod +x /snell/entrypoint.sh

WORKDIR /snell

ENTRYPOINT ["/usr/bin/tini", "--", "/snell/entrypoint.sh"]
