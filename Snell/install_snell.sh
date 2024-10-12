#!/usr/bin/env bash

check_root() {
    [ "$(id -u)" != "0" ] && echo "Error: You must be root to run this script" && exit 1
}

install_tools() {
    apt-get update -y > /dev/null || true
    apt-get install -y curl wget git iptables > /dev/null || true
    echo "Tools installation completed."
}


install_docker_and_compose() {
    if ! command -v docker &> /dev/null; then
        echo "Installing Docker..."
        # Remove any old versions
        for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do
            sudo apt-get remove $pkg
        done

        # Add Docker's official GPG key
        sudo apt-get update
        sudo apt-get install -y ca-certificates curl gnupg
        sudo install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        sudo chmod a+r /etc/apt/keyrings/docker.gpg

        # Add the repository to Apt sources
        echo \
          "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
          "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
          sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

        # Install Docker
        sudo apt-get update
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

        # Start and enable Docker service
        sudo systemctl start docker
        sudo systemctl enable docker

        echo "Docker installation completed."
    else
        echo "Docker is already installed."
    fi

    # Install Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        echo "Installing Docker Compose..."
        sudo curl -L "https://github.com/docker/compose/releases/download/v2.18.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        echo "Docker Compose installation completed."
    else
        echo "Docker Compose is already installed."
    fi
}
get_public_ip() {
    ip_services=("ifconfig.me" "ipinfo.io/ip" "icanhazip.com" "ipecho.net/plain" "ident.me")
    for service in "${ip_services[@]}"; do
        public_ip=$(curl -s "$service")
        if [[ "$public_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "Public IP: $public_ip"
            
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
    sudo locale-gen en_US.UTF-8
    sudo update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

    echo -e "nameserver 8.8.4.4\nnameserver 8.8.8.8" > /etc/resolv.conf
    { echo -e "net.ipv4.tcp_fastopen = 0\nnet.core.default_qdisc = fq\nnet.ipv4.tcp_congestion_control = bbr\nnet.ipv4.tcp_ecn = 1\nvm.swappiness = 0" >> /etc/sysctl.conf && sysctl -p; } > /dev/null 2>&1 && echo "设置已完成"
    iptables -A INPUT -p udp --dport 60000:61000 -j ACCEPT > /dev/null || true
    for iface in $(ls /sys/class/net | grep -v lo); do
        ip link set dev "$iface" mtu 1500
    done
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
    PASSWORD=$(openssl rand -base64 32) || { echo "Error: Unable to generate password"; exit 1; }
    echo "Password generated: $PASSWORD"
}

setup_docker() {
    local NODE_DIR="/root/snelldocker/Snell$RANDOM_PORT"
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
    container_name: Snell$RANDOM_PORT
    restart: always
    network_mode: host
    privileged: true
    platform: $PLATFORM
    environment:
      - PORT=$RANDOM_PORT
      - PSK=$PASSWORD
      - IPV6=false
      - DNS=8.8.8.8,8.8.4.4
    volumes:
      - $NODE_DIR/snell-conf:/etc/snell
      - $NODE_DIR/data:/var/lib/snell
EOF

    cat <<EOF > "$NODE_DIR/snell-conf/snell.conf"
[snell-server]
listen = 0.0.0.0:$RANDOM_PORT
psk = $PASSWORD
tfo = false
obfs = off
dns = 8.8.8.4,9.9.9.12,208.67.220.220,94.140.14.141
ipv6 = false
EOF

    mkdir -p "$NODE_DIR/data"
    docker-compose -f "$NODE_DIR/docker-compose.yml" up -d || { echo "Error: Unable to start Docker container"; exit 1; }
    echo 
    echo "Snell 查看日志请输入：docker logs Snell$RANDOM_PORT"
    echo 
}

print_node() {
    echo 
    echo "$LOCATION Snell $RANDOM_PORT = snell, $public_ip, $RANDOM_PORT, psk=$PASSWORD, version=4"
    echo 
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
