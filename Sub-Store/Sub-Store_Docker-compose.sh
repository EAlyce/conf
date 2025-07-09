#!/usr/bin/env bash
set -euo pipefail

check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo "运行脚本需要 root 权限" >&2
        exit 1
    fi
}

install_packages() {
    if ! command -v docker &> /dev/null; then
        echo "正在安装 Docker 和 Docker Compose..."
        if ! curl -fsSL https://get.docker.com | bash; then
            echo "Docker 安装失败" >&2
            exit 1
        fi
        if ! apt-get update && apt-get install -y docker-compose; then
            echo "Docker Compose 安装失败" >&2
            exit 1
        fi
        echo "Docker 和 Docker Compose 安装完成。"
    else
        echo "Docker 和 Docker Compose 已安装。"
    fi
}

get_public_ip() {
    local ip_services=("ifconfig.me" "ipinfo.io/ip" "icanhazip.com" "ipecho.net/plain" "ident.me")
    local public_ip
    for service in "${ip_services[@]}"; do
        if public_ip=$(curl -sS --connect-timeout 5 "$service"); then
            if [[ "$public_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                echo "$public_ip"
                return 0
            fi
        fi
        sleep 1
    done
    echo "无法获取公共 IP 地址。" >&2
    exit 1
}

setup_docker() {
    local secret_key
    secret_key=$(openssl rand -hex 16)
    echo "生成的密钥: $secret_key"
    mkdir -p /root/sub-store-data
    echo "清理旧容器和配置..."
    docker rm -f sub-store >/dev/null 2>&1 || true
    docker compose -p sub-store down >/dev/null 2>&1 || true
    cat <<EOF > docker-compose.yml
name: sub-store-app
services:
  sub-store:
    image: xream/sub-store
    container_name: sub-store
    restart: always
    environment:
      - SUB_STORE_BACKEND_UPLOAD_CRON=55 23 * * *
      - SUB_STORE_FRONTEND_BACKEND_PATH=/$secret_key
    ports:
      - "3001:3001"
    volumes:
      - /root/sub-store-data:/opt/app/data
EOF
    echo "拉取最新镜像..."
    docker compose -p sub-store pull
    echo "启动容器..."
    docker compose -p sub-store up -d

    echo "正在清理未使用的镜像和缓存..."
    unused_images=$(docker images -f "dangling=true" -q)
    if [ -n "$unused_images" ]; then
        echo "以下镜像将被删除："
        docker images -f "dangling=true"
        docker image prune -f
    else
        echo "没有未使用的镜像需要清理。"
    fi

    if ! command -v cron &>/dev/null; then
        echo "安装 cron..."
        apt-get update >/dev/null 2>&1
        apt-get install -y cron >/dev/null 2>&1
    fi

    systemctl enable cron >/dev/null 2>&1
    systemctl start cron

    local cron_job="0 * * * * cd $(pwd) && docker stop sub-store && docker rm sub-store && docker compose pull sub-store && docker compose up -d sub-store && docker image prune -f >/dev/null 2>&1"
    (crontab -l 2>/dev/null || true; echo "$cron_job") | sort -u | crontab -

    echo "等待服务启动..."
    for i in {1..30}; do
        if curl -s "http://127.0.0.1:3001" >/dev/null; then
            echo -e "\n部署成功！您的 Sub-Store 信息如下："
            echo -e "\nSub-Store 面板：http://$public_ip:3001"
            echo -e "后端地址：http://$public_ip:3001/$secret_key\n"
            return 0
        fi
        sleep 1
    done

    echo "警告: 服务似乎未能在预期时间内启动，但可能仍在进行中。"
    echo
    echo -e "\n您的 Sub-Store 信息如下："
    echo
    echo -e "\nSub-Store 面板：http://$public_ip:3001"
    echo
    echo -e "后端地址：http://$public_ip:3001/$secret_key\n"
    echo
}

main() {
    check_root
    public_ip=$(get_public_ip)
    install_packages
    setup_docker
}

trap 'echo "错误发生在第 $LINENO 行"; exit 1' ERR
main
