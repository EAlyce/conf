
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
    { echo -e "net.ipv4.tcp_fastopen = 0\nnet.core.default_qdisc = fq\nnet.ipv4.tcp_congestion_control = bbr\nnet.ipv4.tcp_ecn = 1\nvm.swappiness = 0" >> /etc/sysctl.conf && sysctl -p; } > /dev/null 2>&1 && echo "设置已完成"
    iptables -A INPUT -p udp --dport 60000:61000 -j ACCEPT > /dev/null || true
    for iface in $(ls /sys/class/net | grep -v lo); do
        ip link set dev "$iface" mtu 1500
    done
}
$RANDOM_PORT
设置端口范围


setup_firewall() {
    iptables -A INPUT -p tcp --dport "$RANDOM_PORT" -j ACCEPT || { echo "Error: Unable to add firewall rule"; exit 1; }
    echo "Firewall rule added for port $RANDOM_PORT."
}

generate_password() {
    PASSWORD=$(openssl rand -base64 32) || { echo "Error: Unable to generate password"; exit 1; }
    echo "Password generated: $PASSWORD"
}
# Step 1: 获取用户输入参数
read -p "请输入域名: " hk.cf.zhetengsha.eu.org
read -p "请输入密码: " $PASSWORD
read -p "请输入端口: " port
read -p "请输入最小端口: " min_port
read -p "请输入最大端口: " max_port
$domain = hk.cf.zhetengsha.eu.org
echo "域名: $domain"
echo "密码: $password"
echo "端口: $port"
echo "最小端口: $min_port"
echo "最大端口: $max_port"
echo "请注意域名必须指向服务器，否则无法使用!!!"
read -p "信息无误请按y回车: " confirm

if [ "$confirm" != "y" ]; then
    echo "安装终止"
    exit 1
fi

# Step 2: 检查 Docker 是否安装，如果未安装则安装 Docker
if ! command -v docker &> /dev/null; then
    read -p "检测到未安装 Docker，是否安装 Docker？(y/n): " install_docker
    if [ "$install_docker" == "y" ]; then
        echo "开始安装 Docker..."
        curl -sSL https://get.docker.com/ | sh
    else
        echo "未安装 Docker，退出脚本"
        exit 1
    fi
fi

# Step 3: 安装 Docker Compose 插件（如果需要）
if ! docker compose version &> /dev/null; then
    echo "Docker Compose 插件未安装，正在安装..."
    sudo apt-get update
    sudo apt-get install docker-compose-plugin
fi

# Step 4: 生成 Docker Compose 文件
echo "开始生成 Docker Compose 文件和 Hysteria 配置文件..."

cat > docker-compose.yaml <<EOL
version: "3.9"
services:
  hysteria:
    image: tobyxdd/hysteria
    container_name: hysteria
    restart: always
    network_mode: "host"
    volumes:
      - acme:/acme
      - ./hysteria.yaml:/etc/hysteria.yaml
    command: ["server", "-c", "/etc/hysteria.yaml"]
volumes:
  acme:
EOL

# Step 5: 生成 Hysteria 配置文件
cat > hysteria.yaml <<EOL
# hysteria.yaml
listen: :$port                # 自定义监听端口，不填默认443
auth:
  type: password
  password: $password         # 注意改复杂密码

masquerade:                     # 下面的可以不需要
  type: proxy
  proxy:
    url: https://www.baidu.com  # 伪装网站
    rewriteHost: true
EOL

# Step 6: 设置端口跳跃规则
echo "设置端口跳跃规则..."
iptables -t nat -A PREROUTING -i eth0 -p udp --dport $min_port:$max_port -j DNAT --to-destination :$port

# Step 7: 启动 Docker Compose
echo "启动 Docker Compose 容器..."
docker compose up -d

# Step 8: 打印容器日志
docker logs hysteria

# Step 9: 打印 Clash 配置
echo "Clash 配置:
- name: hysteria
  type: hysteria
  server: $domain
  port: $port
  ports: $min_port-$max_port/$port
  password: $password
  up: 100         # 这两项建议用 speedtest.cn 测速的值来填
  down: 1000"
