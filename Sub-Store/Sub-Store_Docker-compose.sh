#!/bin/bash
set -euo pipefail

check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo "运行脚本需要 root 权限" >&2
        exit 1
    fi
}

install_basic_tools() {
    # 更新包列表并安装基础工具
    apt-get update -y
    apt-get install -y curl gnupg lsb-release iptables net-tools netfilter-persistent software-properties-common
    echo "基础工具已安装。"
}

clean_system() {
    pkill -9 apt dpkg || true
    rm -f /var/lib/dpkg/lock* /var/lib/apt/lists/lock
    dpkg --configure -a
    apt-get clean autoclean
    apt-get autoremove -y
    rm -rf /tmp/*
    history -c && history -w
    dpkg --list | awk '/^ii/{print $2}' | grep -E 'linux-(image|headers)-[0-9]' | grep -v "$(uname -r)" | xargs apt-get -y purge || true
}

install_packages() {
    export DEBIAN_FRONTEND=noninteractive

    # 安装基础软件包
    apt-get update -y
    apt-get install -y curl gnupg lsb-release

    # 添加 Docker 的 GPG 密钥到新的密钥管理方式
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

    # 添加 Docker 的 APT 源
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    # 更新 APT 包列表并安装 Docker
    apt-get update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io

    # 安装 Docker Compose（如果需要）
    if ! command -v docker-compose &> /dev/null; then
        LATEST_COMPOSE_VERSION=$(curl -sS https://api.github.com/repos/docker/compose/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")')
        curl -sSL "https://github.com/docker/compose/releases/download/${LATEST_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
    fi

    # 启动并使 Docker 开机自启
    systemctl enable docker
    systemctl start docker

    # 输出 Docker 和 Docker Compose 版本
    echo "Docker version:"
    docker --version
    echo "Docker Compose version:"
    docker-compose --version
}

get_public_ip() {
    local ip_services=("ifconfig.me" "ipinfo.io/ip" "icanhazip.com" "ipecho.net/plain" "ident.me")
    for service in "${ip_services[@]}"; do
        public_ip=$(curl -sS "$service")
        if [[ "$public_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "$public_ip"
            return
        fi
        sleep 1
    done
    echo "无法获取公共 IP 地址。" >&2
    exit 1
}

setup_environment() {
    sudo locale-gen en_US.UTF-8 && sudo update-locale LANG=en_US.UTF-8 && sudo timedatectl set-timezone Asia/Shanghai
    echo -e 'nameserver 8.8.4.4\nnameserver 8.8.8.8' > /etc/resolv.conf
    
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

    # 更新系统包并安装 cron
    apt-get update -y && apt-get install -y cron

  # 定义 cron 任务
    cron_job="0 5 * * * docker-compose pull && docker-compose up -d"

# 获取现有的 cron 任务
    existing_cron_jobs=$(crontab -l 2>/dev/null)

# 检查是否已有相同的 cron 任务
if ! echo "$existing_cron_jobs" | grep -Fq "$cron_job"; then
    # 如果没有相同的任务，则添加新任务
    (crontab -l 2>/dev/null; echo "$cron_job") | crontab -
    echo "Cron job added."
else
    echo "Cron job already exists."
fi
    # 显示当前的 cron 任务以确认添加成功
    crontab -l

    # 启动 Docker 容器并检查是否成功
    docker-compose up -d || { echo "Error: Unable to start Docker containers" >&2; exit 1; }
    echo "您的Sub-Store信息如下"
    echo -e "\n后端地址：$public_ip:3001\n"
    echo -e "\nAPI：http://$public_ip:3001/$secret_key\n"
}

main() {
    check_root
    install_basic_tools
    clean_system
    public_ip=$(get_public_ip)
    install_packages
    setup_environment
    setup_docker
}

main