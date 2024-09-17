#!/bin/bash
check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo "运行脚本需要 root 权限" >&2
        exit 1
    fi
}

install_basic_tools() {
    # 更新包列表并安装基础工具
    apt-get update -y > /dev/null 2>&1
    apt-get install -y curl gnupg lsb-release iptables net-tools netfilter-persistent software-properties-common > /dev/null 2>&1
    echo "基础工具已安装。"
}
clean_system() {
    pkill -9 apt || true
    pkill -9 dpkg || true
    rm -f /var/lib/dpkg/lock* /var/lib/apt/lists/lock
    dpkg --configure -a > /dev/null 2>&1
    apt-get clean autoclean > /dev/null 2>&1
    apt-get autoremove -y > /dev/null 2>&1
    rm -rf /tmp/*
    history -c && history -w
    dpkg --list | awk '/^ii/{print $2}' | grep -E 'linux-(image|headers)-[0-9]' | grep -v "$(uname -r)" | xargs apt-get -y purge > /dev/null 2>&1 || true
    echo "系统清理已完成。"

install_packages() {
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y > /dev/null 2>&1
    apt-get install -y \
        netcat-traditional apt-transport-https ca-certificates \
        iptables-persistent netfilter-persistent software-properties-common \
        curl gnupg lsb-release > /dev/null 2>&1

    OS=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
    CODENAME=$(lsb_release -cs)
    ARCH=$(dpkg --print-architecture)

    # 使用 -sSfL 保证静默输出，使用 -o 强制覆盖已存在的文件
    curl -fsSL https://download.docker.com/linux/${OS}/gpg -o /usr/share/keyrings/docker-archive-keyring.gpg > /dev/null 2>&1

    # 添加 Docker 源仓库
    echo "deb [arch=${ARCH} signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/${OS} ${CODENAME} stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt-get update -y > /dev/null 2>&1
    apt-get install -y docker-ce docker-ce-cli containerd.io > /dev/null 2>&1

    if ! command -v docker-compose &> /dev/null; then
        LATEST_COMPOSE_VERSION=$(curl -sS https://api.github.com/repos/docker/compose/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")')
        curl -sSL "https://github.com/docker/compose/releases/download/${LATEST_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose > /dev/null 2>&1
        chmod +x /usr/local/bin/docker-compose
    fi

    apt-get clean > /dev/null 2>&1
    rm -rf /var/lib/apt/lists/*

    systemctl enable docker > /dev/null 2>&1
    systemctl start docker > /dev/null 2>&1

    echo "Docker 和 Docker Compose 已成功安装。"
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
    sudo locale-gen en_US.UTF-8 > /dev/null 2>&1 && sudo update-locale LANG=en_US.UTF-8 > /dev/null 2>&1 && sudo timedatectl set-timezone Asia/Shanghai > /dev/null 2>&1
    echo -e 'nameserver 8.8.4.4\nnameserver 8.8.8.8' > /etc/resolv.conf
    
    iptables -A INPUT -p udp --dport 60000:61000 -j ACCEPT
    iptables -A INPUT -p tcp --tcp-flags SYN SYN -j ACCEPT
    iptables-save > /etc/iptables/rules.v4
    netfilter-persistent reload > /dev/null 2>&1
    
    echo 0 > /proc/sys/net/ipv4/tcp_fastopen
    docker system prune -af --volumes > /dev/null 2>&1
    echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf && sysctl -p > /dev/null
    echo "环境设置已完成。"
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
    apt-get update -y > /dev/null 2>&1 && apt-get install -y cron > /dev/null 2>&1

    # 添加 cron 任务：每天凌晨5点更新 Docker 镜像并重启容器
    (crontab -l 2>/dev/null; echo "0 5 * * * docker-compose pull && docker-compose up -d || { echo 'Error: Unable to restart Docker containers' >&2; }") | crontab -

    # 启动 Docker 容器并检查是否成功
    docker-compose up -d > /dev/null 2>&1 || { echo "错误：无法启动 Docker 容器。" >&2; exit 1; }
    echo "Sub-Store 已成功设置。"
    echo -e "\nSub-Store地址：$public_ip:3001\n"
    echo -e "\nAPI：http://$public_ip:3001/$secret_key\n"
}

main() {
    check_root
    clean_system
    install_basic_tools
    public_ip=$(get_public_ip)
    install_packages
    setup_environment
    setup_docker
}

main
