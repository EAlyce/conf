#!/usr/bin/env bash

# 检查是否为 root 用户
check_root() {
    [ "$(id -u)" -ne 0 ] && { echo "请以 root 权限运行此脚本。"; exit 1; }
}

# 停止所有进程锁
stop_process_locks() {
# 清空现有规则
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X

# 创建 DOCKER 链
iptables -t nat -N DOCKER 2>/dev/null
iptables -t nat -A DOCKER -j RETURN

# 设置默认策略
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT

# 允许本地流量
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# 允许已建立的连接
iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# 保存规则
iptables-save > /etc/iptables/rules.v4

# 重启 Docker
systemctl restart docker
    echo "停止所有进程锁..."
    killall -9 lockfile apt apt-get dpkg || true
}

# 检查并清理 dpkg 锁
clear_dpkg_lock() {
    echo "检查 dpkg 锁..."
    if fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; then
        echo "正在等待锁释放..."
        while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
            sleep 1
        done
    fi
    rm -f /var/lib/dpkg/lock-frontend
    rm -f /var/lib/dpkg/lock
    dpkg --configure -a
}

# 设置系统语言和时区
set_locale_and_timezone() {
    echo "设置系统语言和时区..."
    locale-gen en_US.UTF-8
    update-locale LANG=en_US.UTF-8
    timedatectl set-timezone Asia/Shanghai || echo "设置时区失败，请手动设置。"
}

# 配置DNS
configure_dns() {
    echo "配置DNS..."
    echo "nameserver 8.8.8.8" > /etc/resolv.conf
    echo "nameserver 8.8.4.4" >> /etc/resolv.conf
}

# 一键安装所有软件
install_all_software() {
    echo "安装所有必要软件..."
    apt-get update -y
    apt-get install -y \
        curl wget git vim htop net-tools zip unzip jq psmisc \
        apt-transport-https ca-certificates software-properties-common gnupg \
        python3 python3-pip docker.io docker-compose iptables
    systemctl enable --now docker
}

# 清理系统和 Docker 镜像
clean_system_and_docker() {
    echo "清理系统和 Docker 镜像..."
    apt-get autoremove -y
    docker system prune -a -f
}

# 验证 Docker 是否正常运行
verify_docker() {
    docker run hello-world || { echo "Docker 运行异常"; exit 1; }
}

# 开放端口
configure_iptables() {
    echo "配置防火墙..."
    iptables -P INPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -P OUTPUT ACCEPT
    iptables -F
}

# 设置网络接口 MTU
set_mtu() {
    echo "设置网络接口 MTU..."
    for iface in $(ls /sys/class/net | grep -v lo); do
        echo "设置接口 $iface 的 MTU 为 1500"
        ip link set dev "$iface" mtu 1500
    done
}

# 禁用 swap
disable_swap() {
    echo "禁用 swap..."
    swapoff -a
    sed -i '/ swap / s/^/#/' /etc/fstab
}

# 网络优化
optimize_network() {
    echo "网络优化设置..."
    sysctl -w net.ipv4.ip_forward=1
    modprobe tcp_bbr
    echo -e "net.core.default_qdisc=fq\nnet.ipv4.tcp_congestion_control=bbr\nnet.ipv4.ip_forward=1\nnet.ipv4.tcp_ecn=1\nnet.ipv4.tcp_fastopen=0" >> /etc/sysctl.conf
    sysctl -p
}

# 主函数
main() {
    check_root
    stop_process_locks
    clear_dpkg_lock
    set_locale_and_timezone
    configure_dns
    install_all_software
    clean_system_and_docker
    verify_docker
    configure_iptables
    set_mtu
    disable_swap
    optimize_network
    echo "系统优化完成！"
}

main
