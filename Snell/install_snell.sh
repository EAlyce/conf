#!/usr/bin/env bash
set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 日志函数
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# 错误处理
trap 'log_error "An error occurred. Exiting..."; exit 1' ERR

check_root() {
    if [ "$(id -u)" != "0" ]; then
        log_error "You must be root to run this script"
        exit 1
    fi
}

install_tools() {
    log_info "Installing required tools..."
    {
        DEBIAN_FRONTEND=noninteractive apt-get update -qq
        DEBIAN_FRONTEND=noninteractive apt-get install -qq -y curl wget git iptables netcat openssl
    } &>/dev/null || log_warn "Some packages might not have installed correctly"
    log_info "Tools installation completed"
}

install_docker_and_compose() {
    if ! command -v docker &>/dev/null; then
        log_info "Installing Docker and Docker Compose..."
        curl -fsSL https://get.docker.com | bash &>/dev/null
        DEBIAN_FRONTEND=noninteractive apt-get install -qq -y docker-compose
        systemctl enable docker
        systemctl start docker
        log_info "Docker and Docker Compose installation completed"
    else
        log_info "Docker and Docker Compose are already installed"
    fi
}

get_public_ip() {
    local ip_services=("ifconfig.me" "ipinfo.io/ip" "icanhazip.com" "ipecho.net/plain" "ident.me")
    
    for service in "${ip_services[@]}"; do
        if public_ip=$(curl -s --connect-timeout 5 "$service"); then
            if [[ "$public_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                log_info "Public IP: $public_ip"
                if LOCATION=$(curl -s --connect-timeout 5 ipinfo.io/city); then
                    log_info "Host location: $LOCATION"
                    return 0
                fi
            fi
        fi
    done
    
    log_error "Unable to obtain public IP"
    exit 1
}

setup_environment() {
    log_info "Setting up environment..."
    
    {
        locale-gen en_US.UTF-8
        update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
        
        # DNS configuration
        echo -e "nameserver 8.8.4.4\nnameserver 8.8.8.8" > /etc/resolv.conf
        
        # System optimization
        cat >> /etc/sysctl.conf <<EOF
net.ipv4.tcp_fastopen = 0
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_ecn = 1
vm.swappiness = 0
EOF
        sysctl -p
        
        # Firewall setup
        iptables -A INPUT -p udp --dport 60000:61000 -j ACCEPT
        
        # MTU configuration
        while read -r iface; do
            [ "$iface" != "lo" ] && ip link set dev "$iface" mtu 1500
        done < <(ls /sys/class/net)
    } &>/dev/null || log_warn "Some environment settings might not have applied correctly"
    
    log_info "Environment setup completed"
}

generate_port() {
    local attempts=0
    local max_attempts=10
    
    while [ $attempts -lt $max_attempts ]; do
        RANDOM_PORT=$(shuf -i 5000-30000 -n 1)
        if ! nc -z 127.0.0.1 "$RANDOM_PORT" 2>/dev/null; then
            log_info "Selected port: $RANDOM_PORT"
            return 0
        fi
        ((attempts++))
    done
    
    log_error "Failed to find available port after $max_attempts attempts"
    exit 1
}

setup_firewall() {
    log_info "Configuring firewall..."
    iptables -A INPUT -p tcp --dport "$RANDOM_PORT" -j ACCEPT || {
        log_error "Failed to add firewall rule"
        exit 1
    }
    log_info "Firewall configured successfully"
}

generate_password() {
    PASSWORD=$(openssl rand -base64 32) || {
        log_error "Failed to generate password"
        exit 1
    }
    log_info "Password generated successfully"
}

setup_docker() {
    local NODE_DIR="/root/snelldocker/Snell$RANDOM_PORT"
    
    # 检测系统架构
    local PLATFORM
    case "$(uname -m)" in
        x86_64)  PLATFORM="linux/amd64" ;;
        aarch64) PLATFORM="linux/arm64" ;;
        armv7l)  PLATFORM="linux/arm/v7" ;;
        i386)    PLATFORM="linux/386" ;;
        *)       log_error "Unsupported architecture: $(uname -m)"; exit 1 ;;
    esac
    
    log_info "Setting up Docker configuration..."
    
    mkdir -p "$NODE_DIR/snell-conf" "$NODE_DIR/data" || {
        log_error "Failed to create directories"
        exit 1
    }
    
    # 创建配置文件
    create_docker_compose "$NODE_DIR" "$PLATFORM"
    create_snell_config "$NODE_DIR"
    
    log_info "Starting Docker container..."
    if ! docker compose -f "$NODE_DIR/docker-compose.yml" up -d; then
        log_error "Failed to start Docker container"
        exit 1
    fi
    
    log_info "Docker setup completed"
    log_info "To view logs, run: docker logs Snell$RANDOM_PORT"
}

create_docker_compose() {
    local node_dir="$1"
    local platform="$2"
    
    cat > "$node_dir/docker-compose.yml" <<EOF
services:
  snell:
    image: azurelane/snell:latest
    container_name: Snell$RANDOM_PORT
    restart: always
    network_mode: host
    privileged: true
    platform: $platform
    environment:
      - PORT=$RANDOM_PORT
      - PSK=$PASSWORD
      - IPV6=false
      - DNS=8.8.8.8,8.8.4.4
    volumes:
      - $node_dir/snell-conf:/etc/snell
      - $node_dir/data:/var/lib/snell
EOF
}

create_snell_config() {
    local node_dir="$1"
    
    cat > "$node_dir/snell-conf/snell.conf" <<EOF
[snell-server]
listen = 0.0.0.0:$RANDOM_PORT
psk = $PASSWORD
tfo = false
obfs = off
dns = 8.8.8.4,9.9.9.12,208.67.220.220,94.140.14.141
ipv6 = false
EOF
}

print_node() {
    echo
    log_info "Configuration Summary:"
    echo "-------------------------"
    echo "$LOCATION Snell $RANDOM_PORT = snell, $public_ip, $RANDOM_PORT, psk=$PASSWORD, version=4"
    echo "-------------------------"
    echo
}

main() {
    log_info "Starting installation..."
    
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
    
    log_info "Installation completed successfully!"
}

main

