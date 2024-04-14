#!/bin/bash

# 定义变量
DNS_SERVERS="8.8.4.4 8.8.8.8"
UDP_PORTS="60000:61000"

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
        printf 'PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin\n' >> /etc/crontab
        systemctl reload cron > /dev/null
    fi
}

check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo "Error: You must be root to run this script"
        exit 1
    fi
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
    dpkg --list | egrep -i 'linux-image|linux-headers' | awk '/^ii/{print $2}' | grep -v `uname -r` | xargs apt-get -y purge > /dev/null && \
    echo "Cleaning completed"
}

install_docker_and_compose(){
    if ! command -v docker &> /dev/null; then
        echo "Docker 未安装，开始安装..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
    else
        echo "Docker 已安装，跳过安装步骤。"
    fi

    if ! command -v docker-compose &> /dev/null; then
        echo "Docker Compose 未安装，开始安装..."
        sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
    else
        echo "Docker Compose 已安装，跳过安装步骤。"
    fi
}

get_public_ip() {
    ip_services=("ifconfig.me" "ipinfo.io/ip" "icanhazip.com" "ipecho.net/plain" "ident.me")
    public_ip=""
    for service in "${ip_services[@]}"; do
        if public_ip=$(curl -s "$service" 2>/dev/null); then
            if [[ "$public_ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
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
    [[ "$public_ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || { echo "All services are unable to obtain public IP addresses"; exit 1; }
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
    printf 'nameserver %s\nnameserver %s\n' $DNS_SERVERS > /etc/resolv.conf
    echo "DNS servers updated successfully."

    export DEBIAN_FRONTEND=noninteractive
    apt-get update > /dev/null || true
    echo "Necessary packages installed."

    iptables -A INPUT -p udp --dport $UDP_PORTS -j ACCEPT > /dev/null || true
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
}

# 调用函数
check_root
set_custom_path
clean_lock_files
install_docker_and_compose
get_public_ip
get_location
setup_environment
