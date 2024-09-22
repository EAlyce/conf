#!/bin/bash

# 立即终止遇到的任何错误
set -e

# 检查命令是否存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 安装缺失的包
install_if_not_exists() {
    if ! command_exists "$1"; then
        echo "安装 $1..."
        apt install -y "$1"
    else
        echo "$1 已安装."
    fi
}

# 检查是否为 root 用户
check_root() {
    [ "$(id -u)" -ne 0 ] && { echo "请以 root 权限运行此脚本。"; exit 1; }
}

# 停止所有进程锁
stop_process_locks() {
    echo "停止所有进程锁..."
    install_if_not_exists psmisc
    killall -9 lockfile || true
}

# 设置系统语言和时区
set_locale_and_timezone() {
    echo "设置系统语言和时区..."
    install_if_not_exists locales
    locale-gen en_US.UTF-8
    update-locale LANG=en_US.UTF-8

    install_if_not_exists tzdata
    timedatectl set-timezone Asia/Shanghai || echo "设置时区失败，请手动设置。"
    timedatectl status
}

# 配置DNS
configure_dns() {
    echo "配置DNS..."
    echo "nameserver 8.8.8.8" > /etc/resolv.conf
    echo "nameserver 8.8.4.4" >> /etc/resolv.conf
}

# 更新系统
update_system() {
    echo "更新系统..."
    apt-get update -y && apt-get upgrade -y && apt-get dist-upgrade -y && apt full-upgrade -y
}

# 安装常用软件
install_common_software() {
    echo "安装常用软件..."
    apt install -y curl wget git vim htop net-tools zip unzip jq
}

# 安装Docker和Docker Compose
install_docker() {
    if ! command_exists docker || ! docker compose version &>/dev/null; then
        echo "安装Docker及Compose..."
        apt install -y apt-transport-https ca-certificates curl software-properties-common gnupg
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
        apt update
        apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
        systemctl enable --now docker
    fi
}

# 清理系统和Docker镜像
clean_system_and_docker() {
    echo "清理系统和Docker镜像..."
    apt autoremove -y
    docker system prune -a -f
}

# 验证Docker是否正常运行
verify_docker() {
    docker run hello-world || { echo "Docker 运行异常"; exit 1; }
}

# 开放端口
configure_iptables() {
    install_if_not_exists iptables
    iptables -P INPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -P OUTPUT ACCEPT
    iptables -F
}

# 检测并安装缺失的软件
install_if_missing() {
    if ! command -v "$1" &> /dev/null; then
        echo "未检测到 $1，正在安装..."
        apt-get update
        apt-get install -y "$2"
    else
        echo "$1 已安装。"
    fi
}

# 设置网络接口MTU
set_mtu() {
    echo "设置网络接口MTU..."
    for iface in $(ls /sys/class/net | grep -v lo); do
        echo "设置接口 $iface 的MTU为1500"
        ip link set dev "$iface" mtu 1500
    done
}

# 重启NetworkManager服务
restart_network_manager() {
    if systemctl is-active --quiet NetworkManager; then
        echo "重启NetworkManager服务..."
        systemctl restart NetworkManager
    else
        echo "NetworkManager未安装或未启用，跳过重启。"
    fi
}

# 安装Python3和pip3
install_python() {
    echo "安装Python3和pip3..."
    apt install -y python3 python3-pip
}

# 网络优化
optimize_network() {
    echo "网络优化设置..."
    install_if_not_exists procps
    sysctl -w net.ipv4.ip_forward=1
    modprobe tcp_bbr
    echo -e "net.core.default_qdisc=fq\nnet.ipv4.tcp_congestion_control=bbr\nnet.ipv4.ip_forward=1\nnet.ipv4.tcp_ecn=1" >> /etc/sysctl.conf
    sysctl -p
}

# 禁用swap
disable_swap() {
    echo "禁用swap..."
    swapoff -a
    sed -i '/ swap / s/^/#/' /etc/fstab
}

# 进程优化
optimize_process() {
    echo "进程优化..."
    echo "* soft nproc 65535" >> /etc/security/limits.conf
    echo "* hard nproc 65535" >> /etc/security/limits.conf
}

# 主函数
main() {
    check_root
    stop_process_locks
    set_locale_and_timezone
    configure_dns
    update_system
    install_common_software
    install_docker
    clean_system_and_docker
    verify_docker
    configure_iptables
    install_if_missing ip iproute2
    install_if_missing nmcli network-manager
    set_mtu
    restart_network_manager
    install_python
    optimize_network
    disable_swap
    optimize_process
    echo "系统优化完成！"
}

main
