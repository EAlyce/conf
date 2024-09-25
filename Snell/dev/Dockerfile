# syntax=docker/dockerfile:1
FROM debian:bookworm

# 设置非交互模式，避免debconf错误
ENV DEBIAN_FRONTEND=noninteractive

# 传递构建时的平台信息
ARG TARGETPLATFORM
ENV TARGETPLATFORM=${TARGETPLATFORM:-linux/amd64}

# 安装依赖并清理缓存
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends wget unzip curl tini && \
    rm -rf /var/lib/apt/lists/* && \
    # 根据平台选择合适的 Snell 二进制下载链接
    case "${TARGETPLATFORM}" in \
        "linux/amd64")  SNELL_URL="https://dl.nssurge.com/snell/snell-server-v4.1.1-linux-amd64.zip" ;; \
        "linux/386")    SNELL_URL="https://dl.nssurge.com/snell/snell-server-v4.1.1-linux-i386.zip" ;; \
        "linux/arm64")  SNELL_URL="https://dl.nssurge.com/snell/snell-server-v4.1.1-linux-aarch64.zip" ;; \
        "linux/arm/v7") SNELL_URL="https://dl.nssurge.com/snell/snell-server-v4.1.1-linux-armv7l.zip" ;; \
        *) echo "Unsupported platform: ${TARGETPLATFORM}" && exit 1 ;; \
    esac && \
    # 下载和解压Snell并删除压缩包
    wget -O snell.zip ${SNELL_URL} && \
    unzip snell.zip -d /snell && \
    rm snell.zip && \
    chmod +x /snell/snell-server && \
    # 如果不需要在运行时使用 wget 和 unzip，可以移除它们以优化镜像
    apt-get purge -y --auto-remove wget unzip && \
    rm -rf /var/lib/apt/lists/*

# 复制 entrypoint 脚本并赋予执行权限
COPY entrypoint.sh /snell/
RUN chmod +x /snell/entrypoint.sh

# 设置工作目录
WORKDIR /snell

# 使用 tini 管理进程
ENTRYPOINT ["/usr/bin/tini", "--", "/snell/entrypoint.sh"]
