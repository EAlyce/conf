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
    ip_services=("ifconfig.me" "ipinfo.io/ip" "icanhazip.com" "ipecho.net/plain" "ident.me")

    for service in "${ip_services[@]}"; do
        public_ip=$(curl -s "$service")
        if [[ "$public_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "Public IP: $public_ip"
            exit 0
        fi
    done

    echo "Unable to obtain public IP."
    exit 1
}

setup_docker() {
    read -p "请输入自定义密钥（或直接回车生成随机密钥）: " user_input
    if [ -z "$user_input" ]; then
        local secret_key=$(openssl rand -hex 16)
        echo "未输入自定义密钥，已生成随机密钥: $secret_key"
    else
        local secret_key=$user_input
        echo "使用自定义密钥: $secret_key"
    fi

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

  watchtower:
    image: containrrr/watchtower
    container_name: watchtower
    restart: always
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /etc/localtime:/etc/localtime:ro
    environment:
      - WATCHTOWER_CLEANUP=true
      - WATCHTOWER_POLL_INTERVAL=3600
EOF

    docker-compose up -d || { echo "Error: Unable to start Docker containers" >&2; exit 1; }
    echo "您的 Sub-Store 信息如下"
    echo -e "\nSub-Store面板：http://$public_ip:3001\n"
    echo -e "\n后端地址：http://$public_ip:3001/$secret_key\n"
}

main() {
    check_root
    public_ip=$(get_public_ip)
    install_packages
    setup_docker
}

main
