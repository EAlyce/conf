#!/bin/bash
set_custom_path() {
    if ! command -v cron &> /dev/null; then
    sudo apt-get update > /dev/null
    sudo apt-get install -y cron > /dev/null
fi

if ! systemctl is-active --quiet cron; then
    sudo systemctl start cron > /dev/null
fi

if ! systemctl is-enabled --quiet cron; then
    sudo systemctl enable cron > /dev/null
fi

if ! grep -q '^PATH=' /etc/crontab; then
    echo 'PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin' >> /etc/crontab
    systemctl reload cron > /dev/null
fi
}


check_root() {
    [ "$(id -u)" != "0" ] && echo "Error: You must be root to run this script" && exit 1
}

install_tools() {

    echo "Start updating the system..." && sudo apt-get update -y > /dev/null || true && \
echo "Start installing software..." && sudo apt-get install -y curl wget mosh ncat netcat-traditional nmap apt-utils apt-transport-https ca-certificates iptables netfilter-persistent software-properties-common > /dev/null || true && \
echo "operation completed"
}

clean_lock_files() {

   echo "Start cleaning the system..." && \
sudo pkill -9 apt > /dev/null || true && \
sudo pkill -9 dpkg > /dev/null || true && \
sudo rm -f /var/{lib/dpkg/{lock,lock-frontend},lib/apt/lists/lock} > /dev/null || true && \
sudo dpkg --configure -a > /dev/null || true && \
sudo apt-get clean > /dev/null && \
sudo apt-get autoclean > /dev/null && \
sudo apt-get autoremove -y > /dev/null && \
sudo rm -rf /tmp/* > /dev/null && \
history -c > /dev/null && \
history -w > /dev/null && \
#docker system prune -a --volumes -f > /dev/null && \
dpkg --list | egrep -i 'linux-image|linux-headers' | awk '/^ii/{print $2}' | grep -v `uname -r` | xargs apt-get -y purge > /dev/null && \
echo "Cleaning completed"
}

# 错误代码
ERR_DOCKER_INSTALL=1
ERR_COMPOSE_INSTALL=2
install_docker_and_compose(){
#sudo rm -rf /sys/fs/cgroup/systemd && sudo mkdir /sys/fs/cgroup/systemd && sudo mount -t cgroup -o none,name=systemd cgroup /sys/fs/cgroup/systemd && echo "修复完成"

echo -e "net.core.default_qdisc=fq\nnet.ipv4.tcp_congestion_control=bbr\nnet.ipv4.tcp_ecn=1" | sudo tee -a /etc/sysctl.conf > /dev/null 2>&1 && sudo sysctl -p > /dev/null 2>&1 && echo "System settings have been updated"


echo "Update Docker Key..." && sudo rm -f /usr/share/keyrings/docker-archive-keyring.gpg > /dev/null 2>&1 && sudo curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg > /dev/null 2>&1 && echo "Docker key updated"
sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common > /dev/null 2>&1 && curl -fsSL https://get.docker.com | sudo bash > /dev/null 2>&1 && sudo apt-get update > /dev/null 2>&1 && sudo apt-get install -y docker-compose > /dev/null 2>&1 && echo "Docker installation completed"

# 如果系统版本是 Debian 12，则重新添加 Docker 存储库，使用新的 signed-by 选项来指定验证存储库的 GPG 公钥
if [ "$(lsb_release -cs)" = "bookworm" ]; then
    # 重新下载 Docker GPG 公钥并保存到 /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null && echo "Source added"
fi

# 更新 apt 存储库
sudo apt update > /dev/null 2>&1 && sudo apt upgrade -y > /dev/null 2>&1 && sudo apt autoremove -y > /dev/null 2>&1 && echo "System update completed"

# 如果未安装，则使用包管理器安装 Docker
if ! command -v docker &> /dev/null; then
    sudo apt install -y docker-ce docker-ce-cli containerd.io > /dev/null 2>&1
    sudo systemctl enable --now docker > /dev/null 2>&1
    echo "Docker installed and started successfully"
else
    echo "Docker has been installed"
fi

# 安装 Docker Compose
if ! command -v docker-compose &> /dev/null; then
    sudo apt install -y docker-compose
    echo "Docker Composite installed successfully"
else
    echo "Docker Composite installed successfully"
fi
}
get_public_ip() {
    ip_services=("ifconfig.me" "ipinfo.io/ip" "icanhazip.com" "ipecho.net/plain" "ident.me")
    public_ip=""
    for service in "${ip_services[@]}"; do
        if public_ip=$(curl -s "$service" 2>/dev/null); then
            if [[ "$public_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                echo "Local IP: $public_ip"
                break
            else
                echo "$service 返回的不是一个有效的IP地址：$public_ip"
            fi
        else
            echo "$service Unable to connect or slow response"
        fi
        sleep 1
    done
    [[ "$public_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "All services are unable to obtain public IP addresses"; exit 1; }
}

get_location() {
    location_services=("http://ip-api.com/line?fields=city" "ipinfo.io/city" "https://ip-api.io/json | jq -r .city")
    for service in "${location_services[@]}"; do
        LOCATION=$(curl -s "$service" 2>/dev/null)
        if [ -n "$LOCATION" ]; then
            echo "Host location：$LOCATION"
            break
        else
            echo "Unable to obtain city name from $service."
            continue
        fi
    done
    [ -n "$LOCATION" ] || echo "Unable to obtain city name."
}

setup_environment() {
echo -e "nameserver 8.8.4.4\nnameserver 8.8.8.8" > /etc/resolv.conf
echo "DNS servers updated successfully."

export DEBIAN_FRONTEND=noninteractive
apt-get update > /dev/null || true
echo "Necessary packages installed."

iptables -A INPUT -p udp --dport 60000:61000 -j ACCEPT > /dev/null || true
echo "UDP port range opened."
sudo mkdir -p /etc/iptables
sudo touch /etc/iptables/rules.v4 > /dev/null || true
iptables-save > /etc/iptables/rules.v4
service netfilter-persistent reload > /dev/null || true
echo "Iptables saved."

apt-get upgrade -y > /dev/null || true
echo "Packages updated."

echo "export HISTSIZE=10000" >> ~/.bashrc
source ~/.bashrc

if [ -f "/proc/sys/net/ipv4/tcp_fastopen" ]; then
  echo 3 > /proc/sys/net/ipv4/tcp_fastopen > /dev/null || true
  echo "TCP fast open enabled."
fi

docker system prune -af --volumes > /dev/null || true
echo "Docker system pruned."

iptables -A INPUT -p tcp --tcp-flags SYN SYN -j ACCEPT > /dev/null || true
echo "SYN packets accepted."

curl -fsSL https://raw.githubusercontent.com/EAlyce/ToolboxScripts/master/Linux.sh | bash > /dev/null && echo "Network optimization completed"

}

select_version() {
  echo "Please select the version of Snell："
  echo "1. v3 "
  echo "2. v4 Exclusive to Surge"
  echo "0. 退出脚本"
  read -p "输入选择（回车默认2）: " choice

  choice="${choice:-2}"

  case $choice in
    0) echo "退出脚本"; exit 0 ;;
    1) BASE_URL="https://github.com/xOS/Others/raw/master/snell"; SUB_PATH="v3.0.1/snell-server-v3.0.1"; VERSION_NUMBER="3" ;;
    2) BASE_URL="https://dl.nssurge.com/snell"; SUB_PATH="snell-server-v4.0.1"; VERSION_NUMBER="4" ;;
    *) echo "无效选择"; exit 1 ;;
  esac
}


select_architecture() {
  ARCH="$(uname -m)"
  ARCH_TYPE="linux-amd64.zip"

  if [ "$ARCH" == "aarch64" ]; then
    ARCH_TYPE="linux-aarch64.zip"
  fi

  SNELL_URL="${BASE_URL}/${SUB_PATH}-${ARCH_TYPE}"
}

generate_port() {
  EXCLUDED_PORTS=(5432 5554 5800 5900 6379 8080 9996 1053 5353 8053 9153 9253)

  if ! command -v nc.traditional &> /dev/null; then
    sudo apt-get update
    sudo apt-get install netcat-traditional
  fi

  while true; do
    PORT_NUMBER=$(shuf -i 5000-9999 -n 1)

    if ! nc.traditional -z 127.0.0.1 "$PORT_NUMBER" && [[ ! " ${EXCLUDED_PORTS[@]} " =~ " ${PORT_NUMBER} " ]]; then
      break
    fi
  done
}

setup_firewall() {
  sudo iptables -A INPUT -p tcp --dport "$PORT_NUMBER" -j ACCEPT || { echo "Error: Unable to add firewall rule"; exit 1; }
  echo "Firewall rule added, allowing port $PORT_NUMBER's traffic"
}

generate_password() {
  PASSWORD=$(openssl rand -base64 12) || { echo "Error: Unable to generate password"; exit 1; }
  echo "Password generated：$PASSWORD"
}

setup_docker() {
  NODE_DIR="/root/snelldocker/Snell$PORT_NUMBER"
  
  mkdir -p "$NODE_DIR" || { echo "Error: Unable to create directory $NODE_DIR"; exit 1; }
  cd "$NODE_DIR" || { echo "Error: Unable to change directory to $NODE_DIR"; exit 1; }

  cat <<EOF > docker-compose.yml
version: "3.9"
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

  mkdir -p ./snell-conf || { echo "Error: Unable to create directory $NODE_DIR/snell-conf"; exit 1; }
  cat <<EOF > ./snell-conf/snell.conf
[snell-server]
listen = 0.0.0.0:$PORT_NUMBER
psk = $PASSWORD
tfo = true
obfs = off
ipv6 = false
EOF

  docker-compose up -d || { echo "Error: Unable to start Docker container"; exit 1; }

  echo "Node setup completed. Here is your node information"
}
print_node() {
  if [ "$choice" == "1" ]; then
    echo
    echo
    echo "  - name: $LOCATION Snell v$VERSION_NUMBER $PORT_NUMBER"
    echo "    type: snell"
    echo "    server: $public_ip"
    echo "    port: $PORT_NUMBER"
    echo "    psk: $PASSWORD"
    echo "    version: $VERSION_NUMBER"
    echo "    udp: true"
    echo
    echo "$LOCATION Snell v$VERSION_NUMBER $PORT_NUMBER = snell, $public_ip, $PORT_NUMBER, psk=$PASSWORD, version=$VERSION_NUMBER"
    echo
    echo
  elif [ "$choice" == "2" ]; then
    echo
    echo "$LOCATION Snell v$VERSION_NUMBER $PORT_NUMBER = snell, $public_ip, $PORT_NUMBER, psk=$PASSWORD, version=$VERSION_NUMBER"
    echo
  fi
}


main(){
check_root
sudo apt-get autoremove -y > /dev/null
apt-get install sudo > /dev/null
select_version
set_custom_path
clean_lock_files
install_tools
install_docker_and_compose
get_public_ip
get_location
setup_environment
select_architecture
generate_port
setup_firewall
generate_password
setup_docker
print_node
}

main
