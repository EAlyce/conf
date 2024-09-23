#!/bin/bash

check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo "运行脚本需要 root 权限" >&2
        exit 1
    fi
}

install_basic_tools() {
    apt-get update -y
    apt-get install -y curl gnupg lsb-release iptables net-tools netfilter-persistent software-properties-common
    echo "基础工具已安装。"
}
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


setup_docker() {
    read -p "请输入自定义密钥（或直接回车生成随机密钥）: " user_input
    if [ -z "$user_input" ]; then
        local secret_key=$(openssl rand -hex 16)
        echo "未输入自定义密钥，已生成随机密钥: $secret_key"
    else
        local secret_key=$user_input
        echo "使用自定义密钥: $secret_key"
    fi

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

  watchtower:
    image: containrrr/watchtower
    container_name: watchtower
    restart: always
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /etc/localtime:/etc/localtime:ro
    environment:
      - WATCHTOWER_CLEANUP=true
      - WATCHTOWER_POLL_INTERVAL=86400
EOF

    docker-compose up -d || { echo "Error: Unable to start Docker containers" >&2; exit 1; }

    echo "您的 Sub-Store 信息如下"
    echo -e "\nSub-Store面板：http://$public_ip:3001\n"
    echo -e "\n后端地址：http://$public_ip:3001/$secret_key\n"
}

main() {
    check_root
    install_basic_tools
    system_setup
    public_ip=$(get_public_ip)
    setup_docker
}

main
