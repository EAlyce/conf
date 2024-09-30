# 使用 Debian 的稳定版本作为基础镜像
FROM debian:bullseye-slim AS builder

# 设置构建参数和环境变量
ARG TARGETPLATFORM
ENV TARGETPLATFORM=${TARGETPLATFORM:-linux/amd64}
ENV SNELL_VERSION=v4.1.1
ENV SNELL_URL=https://dl.nssurge.com/snell/snell-server-${SNELL_VERSION}-linux

# 安装必要的工具
RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates wget unzip curl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 下载并安装 Snell 服务器
RUN set -ex && \
    case "${TARGETPLATFORM}" in \
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

# 使用多阶段构建来减小最终镜像大小
FROM debian:bullseye-slim

# 安装 tini
RUN apt-get update && \
    apt-get install -y --no-install-recommends tini procps netcat-openbsd && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 复制 Snell 服务器文件
COPY --from=builder /snell /snell

# 复制入口脚本
COPY entrypoint.sh /snell/
RUN chmod +x /snell/entrypoint.sh

# 设置工作目录
WORKDIR /snell

# 使用 tini 作为入口点
ENTRYPOINT ["/usr/bin/tini", "--", "/snell/entrypoint.sh"]

# 健康检查
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD nc -z localhost $(grep -oP 'listen = 0.0.0.0:\K\d+' /snell/snell.conf) || exit 1
