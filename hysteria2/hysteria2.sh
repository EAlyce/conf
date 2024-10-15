#!/usr/bin/env bash

# Check if the script is run as root
check_root() {
    if [[ "$(id -u)" -ne 0 ]]; then
        echo "Error: You must be root to run this script."
        exit 1
    fi
}

# Install necessary tools
install_tools() {
    echo "Updating package list and installing tools..."
    apt-get update -y > /dev/null
    for tool in curl wget git iptables; do
        if ! command -v "$tool" &> /dev/null; then
            apt-get install -y "$tool" > /dev/null
        fi
    done
    echo "Tools installation completed."
}

# Install Docker and Docker Compose (new version)
install_docker_and_compose() {
    if ! command -v docker &> /dev/null; then
        echo "Installing Docker..."
        curl -fsSL https://get.docker.com | bash > /dev/null 2>&1
        apt-get install -y docker-compose-plugin > /dev/null
        echo "Docker and Docker Compose installed."
    else
        echo "Docker and Docker Compose are already installed."
    fi
}

# Get the public IP address and location
get_public_ip() {
    ip_services=("ifconfig.me" "ipinfo.io/ip" "icanhazip.com" "ipecho.net/plain" "ident.me")
    for service in "${ip_services[@]}"; do
        public_ip=$(curl -s --max-time 3 "$service")
        if [[ "$public_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "Public IP: $public_ip"
            LOCATION=$(curl -s --max-time 3 ipinfo.io/city)
            [ -n "$LOCATION" ] && echo "Host location: $LOCATION" || echo "Unable to obtain location."
            return
        fi
    done
    echo "Unable to obtain public IP."
    exit 1
}

# Set up system environment and network configurations
setup_environment() {
    locale-gen en_US.UTF-8
    update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
    sysctl_conf="/etc/sysctl.conf"
    {
        echo "net.ipv4.tcp_fastopen = 0"
        echo "net.core.default_qdisc = fq"
        echo "net.ipv4.tcp_congestion_control = bbr"
        echo "net.ipv4.tcp_ecn = 1"
        echo "vm.swappiness = 0"
    } >> "$sysctl_conf" && sysctl -p > /dev/null 2>&1
    echo "System configuration completed."

    iptables -A INPUT -p udp --dport 60000:61000 -j ACCEPT > /dev/null
    for iface in $(ls /sys/class/net | grep -v lo); do
        ip link set dev "$iface" mtu 1500
    done
}

# Generate a random password
generate_password() {
    PASSWORD=$(openssl rand -base64 32)
    echo "Generated password: $PASSWORD"
}


generate_port() {
    RANDOM_PORT=$(shuf -i 10000-65535 -n 1)
    while ss -tunlp | grep -w udp | grep -q "$RANDOM_PORT"; do
        RANDOM_PORT=$(shuf -i 10000-65535 -n 1)
    done
    echo "Assigned port: $RANDOM_PORT"
}

setup_firewall() {
    RANDOM_PORT=$((RANDOM % (63556 - 23556 + 1) + 23556))
    iptables -A INPUT -p tcp --dport "$RANDOM_PORT" -j ACCEPT

    for PORT in 23556 63556; do
        iptables -A INPUT -p tcp --dport "$PORT" -j ACCEPT
    done

    iptables -t nat -A PREROUTING -i eth0 -p udp -m multiport --dport 23556,63556 -j DNAT --to-destination :$RANDOM_PORT

    echo "防火墙设置完成."
}

install_hysteria() {
    # Set the node directory
    NODE_DIR="/root/hysteria2/hysteria$RANDOM_PORT"

    # Create the directory
    mkdir -p "$NODE_DIR"

    # 创建必要的目录和文件
    mkdir -p "$NODE_DIR/acme"
    touch "$NODE_DIR/acme/cert.crt"
    touch "$NODE_DIR/acme/private.key"
    cert_path="$NODE_DIR/acme/cert.crt"
    key_path="$NODE_DIR/acme/private.key"
    openssl ecparam -genkey -name prime256v1 -out "$key_path"
    openssl req -new -x509 -days 36500 -key "$key_path" -out "$cert_path" -subj "/CN=wew.bing.com"
    chmod 777 "$cert_path" "$key_path"

    # 创建 docker-compose.yml
    cat <<EOF > "$NODE_DIR/docker-compose.yml"
services:
  hysteria:
    image: tobyxdd/hysteria
    container_name: hysteria$RANDOM_PORT
    restart: always
    network_mode: "host"
    volumes:
      - $NODE_DIR/acme:/acme
      - $NODE_DIR/hysteria.yaml:/etc/hysteria.yaml
    command: ["server", "-c", "/etc/hysteria.yaml"]
volumes:
  acme:
EOF

    # 创建 hysteria.yaml
    cat <<EOF > "$NODE_DIR/hysteria.yaml"
listen: :$RANDOM_PORT
tls:
  cert: /acme/cert.crt
  key: /acme/private.key
auth:
  type: password
  password: $PASSWORD
masquerade:
  type: proxy
  proxy:
    url: https://www.bing.com
    rewriteHost: true
EOF

    docker compose -f "$NODE_DIR/docker-compose.yml" up -d

    LOCATION=${LOCATION:-"Unknown"}
node_info="$LOCATION $RANDOM_PORT = hysteria2, $public_ip, $RANDOM_PORT, password=$PASSWORD, ecn=true, skip-cert-verify=true, sni=wew.bing.com, port-hopping=23557-63555, port-hopping-interval=30"
echo 
echo "$node_info"
echo 

}

install_hysteria() {

    check_root
    install_tools
    install_docker_and_compose
    get_public_ip
    setup_environment
    generate_port
    generate_password
    setup_firewall
    install_hysteria
}

main

