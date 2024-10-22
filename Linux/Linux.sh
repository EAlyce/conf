#!/usr/bin/env bash

# 检查是否为 root 用户
check_root() {
    [ "$(id -u)" -ne 0 ] && { echo "请以 root 权限运行此脚本。"; exit 1; }
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
    date -d "@$(curl -s https://1.1.1.1/cdn-cgi/trace | grep -oP '(?<=ts=)\d+\.\d+' | cut -d '.' -f 1)"
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
    echo "清理系统和未使用 Docker 镜像..."
    sudo sync && echo 3 | sudo tee /proc/sys/vm/drop_caches && sudo apt-get clean && sudo journalctl --vacuum-time=2weeks && sudo rm -rf /tmp/* && docker container prune -f && docker image prune -af && docker volume prune -f && docker network prune -f && docker system prune -af && sudo apt-get autoremove --purge -y

}

# 验证 Docker 是否正常运行
verify_docker() {
    docker run hello-world || { echo "Docker 运行异常"; exit 1; }
}

# 开放端口
configure_iptables() {
    echo "配置防火墙..."
    #!/usr/bin/env bash

# 清空所有现有规则和链
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X

# 创建 DOCKER 链（如果不存在）
iptables -t nat -N DOCKER 2>/dev/null || true
iptables -t nat -A DOCKER -j RETURN

# 允许所有流量的默认策略
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT

# 允许本地回环接口流量
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# 允许已建立和相关的连接流量
iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# 添加 SSH 规则，防止远程连接中断 (假设使用默认的22端口)
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# 添加 HTTP 和 HTTPS 规则
iptables -A INPUT -p tcp --dport 80 -j ACCEPT  # HTTP
iptables -A INPUT -p tcp --dport 443 -j ACCEPT # HTTPS

# 允许 ping（ICMP 请求）
iptables -A INPUT -p icmp -j ACCEPT

# 清理其他常见链（如果需要）
iptables -t nat -F
iptables -t mangle -F
iptables -X
iptables -A INPUT -p ipv4 -j ACCEPT

# 打印当前规则
iptables -L -n -v

# 打印规则总结
echo "iptables 规则已成功重置并更新。"

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
    iptables-save > /etc/iptables/rules.v4
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
