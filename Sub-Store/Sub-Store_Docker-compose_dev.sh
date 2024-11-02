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
        
        # 启动并启用 Docker 服务
        if ! systemctl start docker || ! systemctl enable docker; then
            echo "Docker 服务启动失败" >&2
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
    
    if [ ! -d "/root/MaxMind" ]; then
        mkdir -p /root/MaxMind || {
            echo "创建 MaxMind 目录失败" >&2
            exit 1
        }
    fi

    cd /root/MaxMind || {
        echo "切换到 MaxMind 目录失败" >&2
        exit 1
    }

    if ! curl -L -O https://github.com/P3TERX/GeoLite.mmdb/raw/download/GeoLite2-Country.mmdb || \
       ! curl -L -O https://github.com/P3TERX/GeoLite.mmdb/raw/download/GeoLite2-ASN.mmdb; then
        echo "下载 MMDB 文件失败" >&2
        exit 1
    }

    # 添加每小时更新 MMDB 的 cron 任务
    CRON_CMD="0 * * * * cd /root/MaxMind && curl -L -O https://github.com/P3TERX/GeoLite.mmdb/raw/download/GeoLite2-Country.mmdb && curl -L -O https://github.com/P3TERX/GeoLite.mmdb/raw/download/GeoLite2-ASN.mmdb"
    (crontab -l 2>/dev/null | grep -Fq "$CRON_CMD") || (
        (crontab -l 2>/dev/null; echo "$CRON_CMD") | crontab -
    )
    crontab -l | grep -v '^#' | sed '/^\s*$/d' | sort | uniq | crontab -
}

setup_docker() {
    local secret_key
    secret_key=$(openssl rand -hex 16)
    echo "生成的密钥: $secret_key"

    # 检查数据目录
    if [ ! -d "/root/sub-store-data" ]; then
        mkdir -p /root/sub-store-data || {
            echo "创建数据目录失败" >&2
            exit 1
        }
    }

    # 清理可能存在的旧容器
    docker rm -f sub-store >/dev/null 2>&1 || true
    docker compose -p sub-store down >/dev/null 2>&1 || true

    # 创建 docker-compose.yml
    cat <<EOF > docker-compose.yml
name: sub-store
services:
  sub-store:
    image: xream/sub-store:http-meta
    container_name: sub-store
    restart: always
    environment:
      - SUB_STORE_BACKEND_UPLOAD_CRON=55 23 * * *
      - SUB_STORE_FRONTEND_BACKEND_PATH=/$secret_key
      - SUB_STORE_MMDB_COUNTRY_PATH=/root/MaxMind/GeoLite2-Country.mmdb
      - SUB_STORE_MMDB_ASN_PATH=/root/MaxMind/GeoLite2-ASN.mmdb
    ports:
      - "3001:3001"
    volumes:
      - /root/sub-store-data:/opt/app/data
EOF

    # 拉取和启动容器
    if ! docker compose -p sub-store pull || ! docker compose -p sub-store up -d; then
        echo "Docker 容器启动失败" >&2
        exit 1
    }

    # 添加每小时更新容器的 cron 任务
    local cron_job="0 * * * * cd $(pwd) && docker stop sub-store && docker rm sub-store && docker compose pull sub-store && docker compose up -d sub-store >/dev/null 2>&1"
    (crontab -l 2>/dev/null || true; echo "$cron_job") | sort -u | crontab -

    # 等待服务启动
    echo "等待服务启动..."
    for i in {1..30}; do
        if curl -s "http://127.0.0.1:3001" >/dev/null; then
            echo 
            echo -e "\n您的 Sub-Store 信息如下："
            echo 
            echo -e "Sub-Store 面板：http://$public_ip:3001"
            echo 
            echo -e "后端地址：http://$public_ip:3001/$secret_key\n"
            echo 
            return 0
        fi
        sleep 1
    done
    
    echo "警告: 服务似乎未能在预期时间内启动，但可能仍在进行中。"
    echo 
    echo -e "\n您的 Sub-Store 信息如下："
    echo 
    echo -e "Sub-Store 面板：http://$public_ip:3001"
    echo 
    echo -e "后端地址：http://$public_ip:3001/$secret_key\n"
    echo 
}

main() {
    check_root
    update_mmdb
    
    public_ip=$(get_public_ip)
    if [ -z "$public_ip" ]; then
        echo "获取公网 IP 失败" >&2
        exit 1
    fi
    
    install_packages
    setup_docker
}

main
