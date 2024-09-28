#!/usr/bin/env bash

check_root() {
    [[ "$(id -u)" != "0" ]] && echo "Error: You must be root to run this script" && exit 1
}

install_tools() {
    apt-get update -y > /dev/null || true
    apt-get install -y curl wget git iptables > /dev/null || true
    echo "Tools installation completed."
}

install_docker_and_compose() {
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
        public_ip=$(curl -s "$service")
        if [[ "$public_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "Public IP: $public_ip"
            LOCATION=$(curl -s ipinfo.io/city)
            [[ -n "$LOCATION" ]] && echo "Host location: $LOCATION" || echo "Unable to obtain location from ipinfo.io."
            return
        fi
    done
    echo "Unable to obtain public IP."
    exit 1
}

setup_environment() {
    echo -e "nameserver 8.8.4.4\nnameserver 8.8.8.8" > /etc/resolv.conf
    iptables -A INPUT -p udp --dport 60000:61000 -j ACCEPT > /dev/null 2>&1 || true
    for iface in /sys/class/net/*; do
        [[ "$(basename "$iface")" != "lo" ]] && ip link set dev "$iface" mtu 1500
    done
}

generate_random_port() {
    while true; do
        RANDOM_PORT=$(shuf -i 5000-30000 -n 1)
        ! nc.traditional -z 127.0.0.1 "$RANDOM_PORT" && break
    done
    echo "Selected random port: $RANDOM_PORT"
}

setup_firewall() {
    iptables -A INPUT -p tcp --dport "$1" -j ACCEPT || { echo "Error: Unable to add firewall rule"; exit 1; }
    echo "Firewall rule added for port $1."
}

generate_password() {
    PASSWORD=$(openssl rand -base64 32) || { echo "Error: Unable to generate password"; exit 1; }
    echo "Password generated: $PASSWORD"
}

setup_docker() {
    local NODE_DIR="/root/snelldocker/Snell$1"
    local PLATFORM
    case "$(uname -m)" in
        x86_64) PLATFORM="linux/amd64" ;;
        aarch64) PLATFORM="linux/arm64" ;;
        armv7l) PLATFORM="linux/arm/v7" ;;
        i386) PLATFORM="linux/386" ;;
        *) echo "Error: Unsupported architecture: $(uname -m)"; exit 1 ;;
    esac

    mkdir -p "$NODE_DIR/snell-conf" || { echo "Error: Unable to create directory $NODE_DIR"; exit 1; }
    cat <<EOF > "$NODE_DIR/docker-compose.yml"
services:
  snell:
    image: azurelane/snell:latest
    container_name: Snell$1
    restart: always
    network_mode: host
    privileged: true
    platform: $PLATFORM
    environment:
      - PORT=$1
      - PSK=$2
      - IPV6=false
      - DNS=8.8.8.8,8.8.4.4
    volumes:
      - $NODE_DIR/snell-conf:/etc/snell
      - $NODE_DIR/data:/var/lib/snell
EOF

    cat <<EOF > "$NODE_DIR/snell-conf/snell.conf"
[snell-server]
listen = 0.0.0.0:$1
psk = $2
tfo = false
obfs = off
dns = 8.8.8.4,9.9.9.12,208.67.220.220,94.140.14.141
ipv6 = false
EOF

    mkdir -p "$NODE_DIR/data"
    docker-compose -f "$NODE_DIR/docker-compose.yml" up -d || { echo "Error: 启动失败,请使用非Docker版本Snell安装"; exit 1; }
    echo "Snell 查看日志请输入：docker logs Snell$1"
}

print_node_info() {
    echo "\033[32m$LOCATION Snell $1 = snell, $public_ip, $1, psk=$2, version=4\033[0m\n\n\n"
}

main() {
    check_root
    install_tools
    install_docker_and_compose
    get_public_ip
    setup_environment
    generate_random_port
    setup_firewall
    generate_password
    setup_docker
    print_node_info
}

main
