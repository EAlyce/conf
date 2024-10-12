#!/usr/bin/env bash

check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo "运行脚本需要 root 权限" >&2
        exit 1
    fi
}

install_packages() {
    if ! command -v docker &> /dev/null; then
        echo "Installing Docker and Docker Compose..."
        curl -fsSL https://get.docker.com | bash > /dev/null 2>&1
        apt-get install -y docker-compose > /dev/null
        echo "Docker and Docker Compose installation completed."
    else
        echo "Docker and Docker Compose are already installed."
    fi
}

get_public_ip() {
    local ip_services=("ifconfig.me" "ipinfo.io/ip" "icanhazip.com" "ipecho.net/plain" "ident.me")
    for service in "${ip_services[@]}"; do
        public_ip=$(curl -sS "$service")
        if [[ "$public_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "$public_ip"
            return
        fi
        sleep 1
    done
    echo "无法获取公共 IP 地址。" >&2
    exit 1
}

setup_docker() {
    read -p "请输入自定义密钥（或直接回车生成随机密钥）: " user_input
    local secret_key=${user_input:-$(openssl rand -hex 16)}
    echo "使用密钥: $secret_key"

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

    docker compose up -d || { echo "Error: Unable to start Docker containers" >&2; exit 1; }

    apt-get update && apt-get install -y cron
    systemctl enable cron && systemctl start cron

    local cron_job="0 * * * * cd $(pwd) && docker-compose pull && docker-compose up -d"
    (crontab -l 2>/dev/null; echo "$cron_job") | crontab -

    echo "您的 Sub-Store 信息如下"
    echo -e "\nSub-Store面板：http://$public_ip:3001"
    echo -e "\n后端地址：http://$public_ip:3001/$secret_key\n"
}

main() {
    check_root
    public_ip=$(get_public_ip)
    install_packages
    setup_docker
}

main
