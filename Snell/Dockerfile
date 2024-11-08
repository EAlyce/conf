FROM debian:bookworm

ARG TARGETPLATFORM
ENV TARGETPLATFORM=${TARGETPLATFORM:-linux/amd64}

RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y wget unzip curl tini jq && \
    rm -rf /var/lib/apt/lists/* && \
    LATEST_VERSION=$(curl -s https://dl.nssurge.com/snell/ | grep -oE 'snell-server-v[0-9]+\.[0-9]+\.[0-9]+' | sort -V | tail -n 1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+') && \
    case "${TARGETPLATFORM}" in \
        "linux/amd64")  ARCH="amd64" ;; \
        "linux/386")    ARCH="i386" ;; \
        "linux/arm64")  ARCH="aarch64" ;; \
        "linux/arm/v7") ARCH="armv7l" ;; \
        *) echo "Unsupported platform: ${TARGETPLATFORM}" && exit 1 ;; \
    esac && \
    SNELL_URL="https://dl.nssurge.com/snell/snell-server-v${LATEST_VERSION}-linux-${ARCH}.zip" && \
    echo "Downloading from: ${SNELL_URL}" && \
    wget -O snell.zip ${SNELL_URL} && \
    unzip snell.zip -d /snell && \
    rm snell.zip && \
    chmod +x /snell/snell-server

COPY entrypoint.sh /snell/
RUN chmod +x /snell/entrypoint.sh

WORKDIR /snell

ENTRYPOINT ["/usr/bin/tini", "--", "/snell/entrypoint.sh"]
