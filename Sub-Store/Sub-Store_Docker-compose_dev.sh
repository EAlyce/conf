#!/usr/bin/env bash
set -euo pipefail

check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo "运行脚本需要 root 权限" >&2
        exit 1
    fi
}

update_mmdb() {
    if ! command -v cron &>/dev/null; then
        echo "安装 cron..."
        if ! apt-get update >/dev/null 2>&1; then
            echo "更新软件包列表失败" >&2
            exit 1
        fi
        if ! apt-get install -y cron >/dev/null 2>&1; then
            echo "安装 cron 失败" >&2
            exit 1
        fi
    fi

    if ! systemctl enable cron >/dev/null 2>&1 || ! systemctl start cron; then
        echo "启动 cron 服务失败" >&2
        exit 1
    fi

    PRIMARY_COUNTRY_URL="https://github.com/P3TERX/GeoLite.mmdb/raw/download/GeoLite2-Country.mmdb"
    PRIMARY_ASN_URL="https://github.com/P3TERX/GeoLite.mmdb/raw/download/GeoLite2-ASN.mmdb"
    BACKUP_COUNTRY_URL="https://raw.githubusercontent.com/Loyalsoldier/geoip/release/GeoLite2-Country.mmdb"
    BACKUP_ASN_URL="https://raw.githubusercontent.com/Loyalsoldier/geoip/release/GeoLite2-ASN.mmdb"

    download_file() {
        local file_path=$1
        local primary_url=$2
        local backup_url=$3

        if ! curl -L -o "$file_path" "$primary_url"; then
            echo "从主源下载失败，尝试备用源..."
            if ! curl -L -o "$file_path" "$backup_url"; then
                echo "下载 $file_path 失败" >&2
                exit 1
            fi
        fi
    }

    # Change mmdb file paths to root directory
    download_file /GeoLite2-Country.mmdb "$PRIMARY_COUNTRY_URL" "$BACKUP_COUNTRY_URL"
    download_file /GeoLite2-ASN.mmdb "$PRIMARY_ASN_URL" "$BACKUP_ASN_URL"

    CRON_CMD="0 * * * * curl -L -o /GeoLite2-Country.mmdb $PRIMARY_COUNTRY_URL || curl -L -o /GeoLite2-Country.mmdb $BACKUP_COUNTRY_URL && curl -L -o /GeoLite2-ASN.mmdb $PRIMARY_ASN_URL || curl -L -o /GeoLite2-ASN.mmdb $BACKUP_ASN_URL"
    (crontab -l 2>/dev/null | grep -Fq "$CRON_CMD") || (
        (crontab -l 2>/dev/null; echo "$CRON_CMD") | crontab -
    )
    crontab -l | grep -v '^#' | sed '/^\s*$/d' | sort | uniq | crontab -
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
    # 生成随机密钥
    local secret_key
    secret_key=$(openssl rand -hex 16)
    echo "生成的密钥: $secret_key"
    
    # 创建数据目录
    mkdir -p /root/sub-store-data
    
    # 清理旧容器和配置
    echo "清理旧容器和配置..."
    docker rm -f sub-store >/dev/null 2>&1 || true
    docker compose -p sub-store down >/dev/null 2>&1 || true
    
    # 创建 docker-compose.yml 文件，更新mmdb文件路径
    cat <<EOF > docker-compose.yml
name: sub-store
services:
  sub-store:
    image: xream/sub-store:http-meta
    container_name: sub-store
    restart: always
    environment:
      SUB_STORE_BACKEND_UPLOAD_CRON: "55 23 * * *"
      SUB_STORE_FRONTEND_BACKEND_PATH: "/$secret_key"
      SUB_STORE_MMDB_COUNTRY_PATH: "/GeoLite2-Country.mmdb"
      SUB_STORE_MMDB_ASN_PATH: "/GeoLite2-ASN.mmdb"
    ports:
      - "3001:3001"
    volumes:
      - /root/sub-store-data:/opt/app/data
EOF
    
    # 拉取最新镜像并启动容器
    echo "拉取最新镜像..."
    docker compose -p sub-store pull
    
    echo "启动容器..."
    docker compose -p sub-store up -d
    
    # 安装和配置 cron
    if ! command -v cron &>/dev/null; then
        echo "安装 cron..."
        apt-get update >/dev/null 2>&1
        apt-get install -y cron >/dev/null 2>&1
    fi
    
    systemctl enable cron >/dev/null 2>&1
    systemctl start cron
    
    # 更新 cron 任务
    local cron_job="0 * * * * cd $(pwd) && docker stop sub-store && docker rm sub-store && docker compose pull sub-store && docker compose up -d sub-store >/dev/null 2>&1"
    (crontab -l 2>/dev/null || true; echo "$cron_job") | sort -u | crontab -
    
    # 等待容器完全启动
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
    update_mmdb
    setup_docker
}

trap 'echo "错误发生在第 $LINENO 行"; exit 1' ERR
main
