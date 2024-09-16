#!/bin/bash

check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo "运行脚本需要root权限" >&2
        exit 1
    fi
    if ! command -v apt &> /dev/null; then
        echo "警告: 脚本仅支持 Debian 或 Ubuntu 系统。" >&2
        exit 1
    fi
}

clean_system() {
    pkill -9 apt dpkg
    rm -f /var/lib/dpkg/lock* /var/lib/apt/lists/lock
    dpkg --configure -a
    apt-get clean autoclean
    apt-get autoremove -y
    rm -rf /tmp/*
    history -c && history -w
    dpkg --list | awk '/^ii/{print $2}' | grep -E 'linux-(image|headers)-[0-9]' | grep -v "$(uname -r)" | xargs apt-get -y purge
}

install_packages() {
    apt-get update -y && apt-get install -y \
        netcat-traditional apt-transport-https ca-certificates \
        iptables-persistent netfilter-persistent software-properties-common \
        docker.io curl
    
    if ! command -v docker-compose &> /dev/null; then
        latest_version=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep tag_name | cut -d '"' -f 4)
        curl -L "https://github.com/docker/compose/releases/download/${latest_version}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
    fi
}

get_public_ip() {
    local ip_services=("ifconfig.me" "ipinfo.io/ip" "icanhazip.com" "ipecho.net/plain" "ident.me")
    for service in "${ip_services[@]}"; do
        public_ip=$(curl -s "$service")
        [[ "$public_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && { echo "$public_ip"; return; }
        sleep 1
    done
    echo "Unable to obtain public IP address." >&2
    exit 1
}

setup_environment() {
    sudo locale-gen en_US.UTF-8 && sudo update-locale LANG=en_US.UTF-8 && sudo timedatectl set-timezone Asia/Shanghai
    echo -e 'nameserver 8.8.4.4\nnameserver 8.8.8.8' > /etc/resolv.conf
    export DEBIAN_FRONTEND=noninteractive
    
    systemctl enable --now docker
    
    iptables -A INPUT -p udp --dport 60000:61000 -j ACCEPT
    iptables -A INPUT -p tcp --tcp-flags SYN SYN -j ACCEPT
    iptables-save > /etc/iptables/rules.v4
    netfilter-persistent reload
    
    echo 0 > /proc/sys/net/ipv4/tcp_fastopen
    docker system prune -af --volumes
    echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf && sysctl -p > /dev/null
}

setup_docker() {
    local secret_key=$(openssl rand -hex 16)
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
EOF
    docker-compose up -d || { echo "Error: Unable to start Docker container" >&2; exit 1; }
    echo "您的Sub-Store信息如下"
    echo -e "\n后端地址：$public_ip:3001\n"
    echo -e "\nAPI：$public_ip:3001/$secret_key\n"
}

main() {
    check_root
    clean_system
    public_ip=$(get_public_ip)
    install_packages
    setup_environment
    setup_docker
}

main
