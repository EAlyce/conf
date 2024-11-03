#!/usr/bin/env bash
set -euo pipefail

check_root() {
    if [ "$(id -u)" -ne 0 ]; then exit 1; fi
}

install_packages() {
    if ! command -v docker &>/dev/null; then
        if ! curl -fsSL https://get.docker.com | bash; then exit 1; fi
        apt-get update && apt-get install -y docker-compose || exit 1
    fi
}

get_public_ip() {
    local ip_services=("ifconfig.me" "ipinfo.io/ip" "icanhazip.com" "ipecho.net/plain" "ident.me")
    for service in "${ip_services[@]}"; do
        if public_ip=$(curl -sS --connect-timeout 5 "$service"); then
            if [[ "$public_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                echo "$public_ip"; return
            fi
        fi
        sleep 1
    done
    exit 1
}

setup_docker() {
    local secret_key
    secret_key=$(openssl rand -hex 16)
    mkdir -p /root/sub-store-data
    docker rm -f sub-store >/dev/null 2>&1 || true
    docker compose -p sub-store down >/dev/null 2>&1 || true
    cat <<EOF > docker-compose.yml

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
    docker compose -p sub-store pull
    docker compose -p sub-store up -d
    if ! command -v cron &>/dev/null; then
        apt-get update >/dev/null 2>&1
        apt-get install -y cron >/dev/null 2>&1
    fi
    systemctl enable cron >/dev/null 2>&1
    systemctl start cron
    local cron_job="0 * * * * cd $(pwd) && docker stop sub-store && docker rm sub-store && docker compose pull sub-store && docker compose up -d sub-store >/dev/null 2>&1"
    (crontab -l 2>/dev/null || true; echo "$cron_job") | sort -u | crontab -
    sleep 5  # Add a short wait for the service to start
    if curl -s "http://127.0.0.1:3001" >/dev/null; then
        echo -e "\n部署成功！\nSub-Store 面板：\nhttp://$public_ip:3001\n\n后端地址：\nhttp://$public_ip:3001/$secret_key\n"
    else
        echo -e "\n服务未能在预期时间内启动。\n\n面板：\nhttp://$public_ip:3001\n\n后端地址：\nhttp://$public_ip:3001/$secret_key\n"
    fi
}


main() {
    check_root
    public_ip=$(get_public_ip)
    install_packages
    setup_docker
}

main
