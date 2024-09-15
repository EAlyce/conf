#!/bin/bash

# 检查是否为 root 用户
check_root() {
    [ "$(id -u)" != "0" ] && echo "Error: You must be root to run this script" && exit 1
}

# 清理系统
clean_lock_files() {
    echo "Start cleaning the system..."
    pkill -9 apt dpkg || true
    rm -f /var/lib/dpkg/lock /var/lib/dpkg/lock-frontend /var/lib/apt/lists/lock || true
    dpkg --configure -a > /dev/null || true
    apt-get clean autoclean > /dev/null
    apt-get autoremove -y > /dev/null
    rm -rf /tmp/* > /dev/null
    history -c && history -w > /dev/null
    dpkg --list | awk '/^ii/{print $2}' | grep -E 'linux-(image|headers)-[0-9]' | grep -v $(uname -r) | xargs apt-get -y purge > /dev/null
    echo "Cleaning completed"
}

# 安装工具
install_tools() {
    echo "Start updating the system and installing software..."
    apt-get update -y > /dev/null && \
    apt-get install -y curl wget netcat-traditional apt-transport-https ca-certificates iptables-persistent netfilter-persistent software-properties-common > /dev/null
    echo "Operation completed"
}

# 获取公共 IP
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

# 获取主机位置
get_location() {
    local location_services=("http://ip-api.com/line?fields=city" "ipinfo.io/city")
    for service in "${location_services[@]}"; do
        LOCATION=$(curl -s "$service" 2>/dev/null)
        [ -n "$LOCATION" ] && echo "Host location: $LOCATION" && return
        sleep 1
    done
    echo "Unable to obtain city name."
}

# 设置环境
setup_environment() {
    echo "Setting up environment..."
    echo -e 'nameserver 8.8.4.4\nnameserver 8.8.8.8' > /etc/resolv.conf
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    if ! command -v docker &> /dev/null; then
        curl -fsSL https://get.docker.com | sh
        systemctl enable --now docker
    fi
    iptables -A INPUT -p udp --dport 60000:61000 -j ACCEPT
    iptables -A INPUT -p tcp --tcp-flags SYN SYN -j ACCEPT
    iptables-save > /etc/iptables/rules.v4
    netfilter-persistent reload
    echo 0 > /proc/sys/net/ipv4/tcp_fastopen
    docker system prune -af --volumes
    echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf && sysctl -p > /dev/null
}

# 选择 Snell 版本
select_version() {
    echo "选择 Snell 版本："
    echo "1. Snell v3"
    echo "2. Snell v4 Surge 专属"
    echo "0. Exit script"
    read -p "回车默认选择2: " choice
    choice="${choice:-2}"
    case $choice in
        0) echo "Exit script"; exit 0 ;;
        1) BASE_URL="https://github.com/EAlyce/conf/tree/main/Snell/source"; SUB_PATH="v3.0.1/snell-server-v3.0.1"; VERSION_NUMBER="3" ;;
        2) BASE_URL="https://dl.nssurge.com/snell"; SUB_PATH="snell-server-v4.1.0"; VERSION_NUMBER="4" ;;
        *) echo "Invalid selection"; exit 1 ;;
    esac
}

# 选择架构
select_architecture() {
    ARCH="$(uname -m)"
    ARCH_TYPE="linux-amd64.zip"
    [ "$ARCH" == "aarch64" ] && ARCH_TYPE="linux-aarch64.zip"
    SNELL_URL="${BASE_URL}/${SUB_PATH}-${ARCH_TYPE}"
}

# 生成端口号
generate_port() {
    local ALLOWED_PORTS=(23456 23556)
    command -v nc.traditional &> /dev/null || apt-get install -y netcat-traditional
    for PORT in "${ALLOWED_PORTS[@]}"; do
        if nc.traditional -z 127.0.0.1 "$PORT"; then
            echo "端口 $PORT 已被占用，跳过..."
        else
            PORT_NUMBER="$PORT"
            echo "选定的端口: $PORT_NUMBER"
            setup_firewall "$PORT_NUMBER"
            return
        fi
    done
    while true; do
        PORT_NUMBER=$(shuf -i 1000-9999 -n 1)
        if ! nc.traditional -z 127.0.0.1 "$PORT_NUMBER"; then
            echo "选定的随机端口: $PORT_NUMBER"
            setup_firewall "$PORT_NUMBER"
            break
        fi
    done
}

# 设置防火墙
setup_firewall() {
    local PORT="$1"
    iptables -A INPUT -p tcp --dport "$PORT" -j ACCEPT || { echo "错误: 无法添加防火墙规则"; exit 1; }
    echo "已添加防火墙规则，允许端口 $PORT 的流量"
}

# 生成密码
generate_password() {
    PASSWORD=$(openssl rand -base64 18) || { echo "Error: Unable to generate password"; exit 1; }
    echo "Password generated: $PASSWORD"
}

# 设置 Docker
setup_docker() {
    local NODE_DIR="/root/snelldocker/Snell$PORT_NUMBER"
    mkdir -p "$NODE_DIR/snell-conf" || { echo "Error: Unable to create directory $NODE_DIR"; exit 1; }
    cd "$NODE_DIR" || { echo "Error: Unable to change directory to $NODE_DIR"; exit 1; }
    cat <<EOF > docker-compose.yml
services:
  snell:
    image: accors/snell:latest
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
dns = 8.8.8.8,8.8.4.4,94.140.14.140,94.140.14.141,208.67.222.222,208.67.220.220
ipv6 = false
EOF
    docker-compose up -d || { echo "Error: Unable to start Docker container"; exit 1; }
    echo "Node setup completed. Here is your node information"
}

# 输出节点信息
print_node() {
    if [ "$choice" == "1" ]; then
        echo
        echo "  - name: $LOCATION Snell v$VERSION_NUMBER $PORT_NUMBER"
        echo "    type: snell"
        echo "    server: $public_ip"
        echo "    port: $PORT_NUMBER"
        echo "    cipher: chacha20-ietf-poly1305"
        echo "    psk: $PASSWORD"
        echo "    version: $VERSION_NUMBER"
        echo
    else
        echo "Proxy = snell, $public_ip, $PORT_NUMBER, psk=$PASSWORD, version=$VERSION_NUMBER, tfo=false"
    fi
}

# 主程序
main() {
    check_root
    clean_lock_files &
    get_public_ip
    get_location
    install_tools
    setup_environment
    select_version
    select_architecture
    generate_port
    generate_password
    setup_docker
    print_node
}

# 开始执行
main
