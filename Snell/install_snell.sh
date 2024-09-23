#!/bin/bash

system_setup() {
    echo "开始设置系统环境..."
    
    # 动画函数
    animate() {
        local spin='-\|/'
        local i=0
        while true; do
            i=$(( (i+1) % 4 ))
            printf "\r[%c] 正在设置..." "${spin:$i:1}"
            sleep 0.1
        done
    }

    # 开始动画
    animate &
    ANIMATE_PID=$!

    # 执行实际的设置命令并捕获输出
    OUTPUT=$(bash -c "$(curl -fsSL https://raw.githubusercontent.com/EAlyce/conf/refs/heads/main/Linux/Linux.sh)" 2>&1)
    EXIT_CODE=$?

    # 停止动画
    kill $ANIMATE_PID
    wait $ANIMATE_PID 2>/dev/null

    # 清除动画行
    echo -e "\r\033[K"

    if [ $EXIT_CODE -ne 0 ]; then
        echo "错误：系统环境设置失败"
        echo "错误信息："
        echo "$OUTPUT"
        return 1
    else
        echo "系统环境设置成功"
    fi
}



get_public_ip() {
    local ip_services=("ifconfig.me" "ipinfo.io/ip" "icanhazip.com" "ipecho.net/plain" "ident.me")
    for service in "${ip_services[@]}"; do
        public_ip=$(curl -s "$service" 2>/dev/null)
        if [[ "$public_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "Local IP: $public_ip"
            return
        fi
        sleep 1
    done
    echo "Unable to obtain public IP address from all services."
    exit 1
}

get_location() {
    local service="http://ipinfo.io/city"
    LOCATION=$(curl -s "$service" 2>/dev/null)
    if [ -n "$LOCATION" ]; then
        echo "Host location: $LOCATION"
    else
        echo "Unable to obtain city name."
    fi
}

select_version() {
    echo "选择 Snell 版本："
    echo "1. Snell v3"
    echo "2. Snell v4 Surge 专属"
    echo "0. Exit script"
    read -p "回车默认选择2: " choice
    choice="${choice:-2}"
    case $choice in
        0) echo "Exit script"; exit 0 ;;
        1) BASE_URL="https://github.com/EAlyce/conf/raw/main/Snell/source"; SUB_PATH="v3.0.1/snell-server-v3.0.1"; VERSION_NUMBER="3" ;;
        2) BASE_URL="https://dl.nssurge.com/snell"; SUB_PATH="snell-server-v4.1.0"; VERSION_NUMBER="4" ;;
        *) echo "Invalid selection"; exit 1 ;;
    esac
}

select_architecture() {
    ARCH="$(uname -m)"
    ARCH_TYPE="linux-amd64.zip"
    [ "$ARCH" == "aarch64" ] && ARCH_TYPE="linux-aarch64.zip"
    SNELL_URL="${BASE_URL}/${SUB_PATH}-${ARCH_TYPE}"
}

generate_port() {
    local ALLOWED_PORTS=(23456 23556)
    apt-get install -y netcat-traditional
    for PORT in "${ALLOWED_PORTS[@]}"; do
        if ! nc.traditional -z 127.0.0.1 "$PORT"; then
            PORT_NUMBER="$PORT"
            setup_firewall "$PORT_NUMBER"
            return
        fi
    done
    while true; do
        PORT_NUMBER=$(shuf -i 1000-9999 -n 1)
        if ! nc.traditional -z 127.0.0.1 "$PORT_NUMBER"; then
            setup_firewall "$PORT_NUMBER"
            break
        fi
    done
}

setup_firewall() {
    local PORT="$1"
    iptables -A INPUT -p tcp --dport "$PORT" -j ACCEPT || { echo "Error: Unable to add firewall rule"; exit 1; }
}

generate_password() {
    PASSWORD=$(openssl rand -base64 18) || { echo "Error: Unable to generate password"; exit 1; }
}

setup_docker() {
    local NODE_DIR="/root/snelldocker/Snell$PORT_NUMBER"
    mkdir -p "$NODE_DIR/snell-conf" || { echo "Error: Unable to create directory $NODE_DIR"; exit 1; }
    cd "$NODE_DIR" || { echo "Error: Unable to change directory to $NODE_DIR"; exit 1; }
    cat <<EOF > docker-compose.yml
services:
  snell:
    image: ghcr.io/skyxim/snell:latest
    container_name: Snell$PORT_NUMBER
    restart: always
    network_mode: host
    privileged: true
    environment:
      - SNELL_URL=$SNELL_URL
    volumes:
      - ./snell-conf/snell.conf:/etc/snell-server.conf
EOF
    cat <<EOF > ./snell-conf/snell.conf
[snell-server]
listen = 0.0.0.0:$PORT_NUMBER
psk = $PASSWORD
tfo = false
obfs = off
dns = 8.8.8.8,8.8.4.4,208.67.222.222,208.67.220.220
ipv6 = false
EOF
    docker-compose up -d || { echo "Error: Unable to start Docker container"; exit 1; }
    echo "节点信息如下"
}

print_node() {
    echo -e "\n\n\n$LOCATION $PORT_NUMBER = snell, $public_ip, $PORT_NUMBER, psk=$PASSWORD, version=$VERSION_NUMBER\n\n\n"
}

main() {
    if [[ $EUID -ne 0 ]]; then
        echo "This script must be run as root" 
        exit 1
    fi
    
    system_setup
    get_public_ip
    get_location
    select_version
    select_architecture
    generate_port
    generate_password
    setup_docker
    print_node
}

main
