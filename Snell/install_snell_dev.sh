#!/usr/bin/env bash

check_root() {
    [ "$(id -u)" != "0" ] && echo "Error: You must be root to run this script" && exit 1
}

install_tools() {
    apt-get update -y > /dev/null || true
    apt-get install -y curl wget git netcat-traditional apt-transport-https ca-certificates iptables netfilter-persistent software-properties-common > /dev/null || true
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
    ip_services=("ifconfig.me" "ipinfo.io/ip" "icanhazip.com" "ipecho.net/plain" "ident.me")
    for service in "${ip_services[@]}"; do
        public_ip=$(curl -s "$service")
        if [[ "$public_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "Public IP: $public_ip"
            
            # 获取地理位置信息
            LOCATION=$(curl -s ipinfo.io/city)
            if [ -n "$LOCATION" ]; then
                echo "Host location: $LOCATION"
            else
                echo "Unable to obtain location from ipinfo.io."
            fi
            return
        fi
    done
    echo "Unable to obtain public IP."
    exit 1
}


setup_environment() {
    echo -e "nameserver 8.8.4.4\nnameserver 8.8.8.8" > /etc/resolv.conf
    iptables -A INPUT -p udp --dport 60000:61000 -j ACCEPT > /dev/null || true
    echo "Environment setup completed."
}

generate_port() {
    while true; do
        RANDOM_PORT=$(shuf -i 5000-30000 -n 1)
        if ! nc.traditional -z 127.0.0.1 "$RANDOM_PORT"; then
            echo "Selected random port: $RANDOM_PORT"
            break
        fi
    done
}

setup_firewall() {
    iptables -A INPUT -p tcp --dport "$RANDOM_PORT" -j ACCEPT || { echo "Error: Unable to add firewall rule"; exit 1; }
    echo "Firewall rule added for port $RANDOM_PORT."
}

generate_password() {
    PASSWORD=$(openssl rand -base64 18) || { echo "Error: Unable to generate password"; exit 1; }
    echo "Password generated: $PASSWORD"
}

setup_docker() {
    NODE_DIR="/root/snelldocker/Snell$RANDOM_PORT"
    
    # 创建节点目录
    mkdir -p "$NODE_DIR" || { echo "Error: Unable to create directory $NODE_DIR"; exit 1; }

    # 切换到该目录
    cd "$NODE_DIR" || { echo "Error: Unable to change directory to $NODE_DIR"; exit 1; }

    # 生成 Docker Compose 文件
    cat <<EOF > docker-compose.yml
services:
  snell:
    image: azurelane/snell:latest
    container_name: Snell$RANDOM_PORT
    restart: always
    network_mode: host  # 使用 host 网络模式
    privileged: true
    environment:
      - PORT=$RANDOM_PORT
      - PSK=$PASSWORD
      - IPV6=false
      - DNS=8.8.8.8,8.8.4.4,94.140.14.140,94.140.14.141,208.67.222.222,208.67.220.220,9.9.9.9
    volumes:
      - $NODE_DIR/snell-conf:/etc/snell  # 确保挂载到 /etc/snell
      - $NODE_DIR/data:/var/lib/snell
EOF

    # 创建 snell-conf 目录并生成配置文件
    mkdir -p "$NODE_DIR/snell-conf"
    cat <<EOF > "$NODE_DIR/snell-conf/snell.conf"
[snell-server]
listen = 0.0.0.0:$RANDOM_PORT
psk = $PASSWORD
tfo = false
obfs = off
dns = 8.8.8.8,8.8.4.4,94.140.14.140,94.140.14.141,208.67.222.222,208.67.220.220,9.9.9.9
ipv6 = false
EOF

    # 创建 data 目录
    mkdir -p "$NODE_DIR/data"

    # 使用 Docker Compose 启动 Snell 容器
    docker-compose up -d || { echo "Error: Unable to start Docker container"; exit 1; }
    echo
    echo "Snell 查看日志请输入：docker logs Snell$RANDOM_PORT"
    echo
    echo
    
    echo "Snell 节点信息："
}


print_node() {
    echo
    echo "$LOCATION Snell $RANDOM_PORT = snell, $public_ip, $RANDOM_PORT, psk=$PASSWORD, version=4"
    echo
}

main() {
    check_root
    
    install_tools
    install_docker_and_compose
    get_public_ip
    setup_environment
    generate_port
    setup_firewall
    generate_password
    setup_docker
    print_node
}

main
