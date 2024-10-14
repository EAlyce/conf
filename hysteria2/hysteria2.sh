
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
