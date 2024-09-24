#!/bin/bash

check_root() {
    [ "$(id -u)" != "0" ] && echo "Error: You must be root to run this script" && exit 1
}

install_tools() {
    apt-get update -y > /dev/null

    # 仅安装必要的工具
    tools=(curl wget netcat-traditional iptables)
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            echo "$tool is not installed. Installing..."
            apt-get install -y "$tool" > /dev/null
        else
            echo "$tool is already installed."
        fi
    done
}

install_docker() {
    if ! command -v docker &> /dev/null; then
        echo "Installing Docker and Docker Compose..."
        curl -fsSL https://get.docker.com | bash > /dev/null
        apt-get install -y docker-compose > /dev/null
        echo "Docker installation completed"
    else
        echo "Docker and Docker Compose are already installed"
    fi
}

get_public_ip() {
    ip_services=("ifconfig.me" "ipinfo.io/ip")
    for service in "${ip_services[@]}"; do
        if public_ip=$(curl -s "$service" 2>/dev/null) && [[ "$public_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "Public IP: $public_ip"
            return
        fi
    done
    echo "Unable to obtain public IP address" && exit 1
}

get_location() {
    location_services=("ipinfo.io/city")
    for service in "${location_services[@]}"; do
        if LOCATION=$(curl -s "$service" 2>/dev/null) && [ -n "$LOCATION" ]; then
            echo "Host location: $LOCATION"
            return
        fi
    done
    echo "Unable to obtain location"
}

generate_port() {
    ALLOWED_PORTS=(23456 23556)
    for PORT_NUMBER in "${ALLOWED_PORTS[@]}"; do
        if ! nc -z 127.0.0.1 "$PORT_NUMBER"; then
            echo "Selected port: $PORT_NUMBER"
            return
        fi
    done
    while true; do
        PORT_NUMBER=$(shuf -i 1000-9999 -n 1)
        if ! nc -z 127.0.0.1 "$PORT_NUMBER"; then
            echo "Selected random port: $PORT_NUMBER"
            return
        fi
    done
}

setup_firewall() {
    iptables -A INPUT -p tcp --dport "$PORT_NUMBER" -j ACCEPT
    echo "Firewall rule added for port $PORT_NUMBER"
}

generate_password() {
    PASSWORD=$(openssl rand -base64 18)
    echo "Password generated: $PASSWORD"
}

setup_docker() {
    NODE_DIR="/root/snelldocker/Snell$PORT_NUMBER"
    mkdir -p "$NODE_DIR" && cd "$NODE_DIR" || { echo "Error: Unable to create/access $NODE_DIR"; exit 1; }
    
    PLATFORM=$(uname -m)
    case $PLATFORM in
        x86_64) PLATFORM="linux/amd64" ;;
        i386) PLATFORM="linux/i386" ;;
        aarch64) PLATFORM="linux/arm64" ;;
        armv7l) PLATFORM="linux/arm/v7" ;;
        *) echo "Unsupported architecture: $PLATFORM"; exit 1 ;;
    esac
    
    cat <<EOF > docker-compose.yml
services:
  snell:
    image: azurelane/snell:latest
    container_name: snell$PORT_NUMBER
    restart: always
    network_mode: host
    environment:
      - PORT=$PORT_NUMBER
      - PSK=$PASSWORD
      - IPV6=false
      - DNS=8.8.8.8,8.8.4.4,208.67.222.222,208.67.220.220
      - VERSION=v4.1.1
    platform: $PLATFORM
EOF
    
    docker-compose up -d
}

print_node() {
    echo
    echo "$LOCATION Snell $PORT_NUMBER = snell, $public_ip, $PORT_NUMBER, psk=$PASSWORD, version=4"
}

main() {
    check_root
    install_tools
    install_docker
    get_public_ip
    get_location
    generate_port
    setup_firewall
    generate_password
    setup_docker
    print_node
}

main
