# syntax=docker/dockerfile:1
FROM debian:bookworm-slim

ARG TARGETPLATFORM
ENV TARGETPLATFORM=${TARGETPLATFORM:-linux/amd64}

# 安装必要的软件包并清理
RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates wget unzip curl tini && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 设置 Snell 版本和下载 URL
ENV SNELL_VERSION=v4.1.1
ENV SNELL_URL=https://dl.nssurge.com/snell/snell-server-${SNELL_VERSION}-linux

# 下载并安装 Snell
RUN case "${TARGETPLATFORM}" in \
        "linux/amd64")  SNELL_ARCH="amd64" ;; \
        "linux/386")    SNELL_ARCH="i386" ;; \
        "linux/arm64")  SNELL_ARCH="aarch64" ;; \
        "linux/arm/v7") SNELL_ARCH="armv7l" ;; \
        *) echo "不支持的平台: ${TARGETPLATFORM}" && exit 1 ;; \
    esac && \
    wget -O snell.zip "${SNELL_URL}-${SNELL_ARCH}.zip" && \
    unzip snell.zip -d /snell && \
    rm snell.zip && \
    chmod +x /snell/snell-server

# 复制启动脚本
COPY entrypoint.sh /snell/
RUN chmod +x /snell/entrypoint.sh

# 设置工作目录
WORKDIR /snell

# 使用 tini 作为 init 系统
ENTRYPOINT ["/usr/bin/tini", "--", "/snell/entrypoint.sh"]

# 暴露默认端口（实际端口将由脚本随机生成）
EXPOSE 8388
