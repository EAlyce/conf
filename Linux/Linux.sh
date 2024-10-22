
#!/usr/bin/env bash

# 检查是否为 root 用户
check_root() {
    [ "$(id -u)" -ne 0 ] && { echo "请以 root 权限运行此脚本。"; exit 1; }
}
check_root
setup_ssh_keepalive() {
    local config_path="$HOME/.ssh/config"
    local interval=60
    local count=3

    # 检查配置文件是否存在，如果不存在则创建
    if [[ ! -f $config_path ]]; then
        touch "$config_path"
        echo "# SSH Config" >> "$config_path"
    fi

    # 检查是否已存在相关配置，避免重复添加
    if ! grep -q "ServerAliveInterval" "$config_path"; then
        {
            echo ""
            echo "# KeepAlive settings"
            echo "ServerAliveInterval $interval"
            echo "ServerAliveCountMax $count"
        } >> "$config_path"
        echo "SSH KeepAlive 设置已更新。"
    else
        echo "SSH KeepAlive 配置已存在，无需重复设置。"
    fi
}

# 调用函数
setup_ssh_keepalive

    # 检查并清理 dpkg 锁
    clear_dpkg_lock() {
        echo "检查 dpkg 锁..."
        if fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; then
            echo "正在等待锁释放..."
            while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
                sleep 1
            done
        fi
        rm -f /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock
        dpkg --configure -a
    }

    # 设置系统语言和时区
    set_locale_and_timezone() {
        echo "设置系统语言和时区..."
        locale-gen en_US.UTF-8
        update-locale LANG=en_US.UTF-8
        timedatectl set-timezone Asia/Shanghai || echo "设置时区失败，请手动设置。"
    }

    # 配置 DNS
    configure_dns() {
        echo "配置 DNS..."
        cat <<EOF > /etc/resolv.conf
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF
    }

    # 安装必要软件
    install_all_software() {
        echo "安装所有必要软件..."
        apt update -y && apt upgrade -y && apt dist-upgrade -y && apt full-upgrade -y
        apt-get install -y curl wget git tmux cron vim htop net-tools zip unzip jq psmisc \
            apt-transport-https ca-certificates software-properties-common gnupg \
            python3 python3-pip docker.io docker-compose iptables
        systemctl enable --now docker
        crontab -l | grep -v '^#' | sed '/^\s*$/d' | sort | uniq | crontab -
    }

    # 清理系统和 Docker
    clean_system_and_docker() {
        echo "清理系统和未使用的 Docker 镜像..."
        sync && echo 3 | tee /proc/sys/vm/drop_caches
        apt-get clean
        journalctl --vacuum-time=2weeks
        rm -rf /tmp/*
        docker system prune -af --volumes
        apt-get autoremove --purge -y
    }

    # 验证 Docker
    verify_docker() {
        docker run hello-world || { echo "Docker 运行异常"; exit 1; }
    }

    # 配置 iptables 规则
    configure_iptables() {
        echo "配置 iptables 规则..."
        iptables -F
        iptables -X
        iptables -t nat -F
        iptables -t nat -X
        iptables -P INPUT ACCEPT
        iptables -P FORWARD ACCEPT
        iptables -P OUTPUT ACCEPT

        # 允许本地回环接口
        iptables -A INPUT -i lo -j ACCEPT
        iptables -A OUTPUT -o lo -j ACCEPT

        # 允许已建立连接
        iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

        # 允许 SSH、HTTP、HTTPS
        iptables -A INPUT -p tcp --dport 22 -j ACCEPT
        iptables -A INPUT -p tcp --dport 80 -j ACCEPT
        iptables -A INPUT -p tcp --dport 443 -j ACCEPT

        # 允许 ping 请求
        iptables -A INPUT -p icmp -j ACCEPT

        iptables-save > /etc/iptables/rules.v4
        echo "iptables 规则配置完成。"
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

    # 网络优化设置
    optimize_network() {
        echo "网络优化设置..."
        sysctl -w net.ipv4.ip_forward=1
        modprobe tcp_bbr
        cat <<EOF >> /etc/sysctl.conf
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.ipv4.ip_forward=1
net.ipv4.tcp_ecn=1
net.ipv4.tcp_fastopen=0
EOF
        sysctl -p
    }

    get_external_timestamp() {
        echo "获取外部时间戳..."
        timestamp=$(curl -s https://1.1.1.1/cdn-cgi/trace | grep -oP '(?<=ts=)\d+\.\d+' | cut -d '.' -f 1)
        if [ -n "$timestamp" ]; then
            date -d "@$timestamp"
        else
            echo "无法获取外部时间戳，跳过此步骤。"
        fi
    }

main() {
    clear_dpkg_lock >/dev/null 2>&1
    set_locale_and_timezone >/dev/null 2>&1
    get_external_timestamp >/dev/null 2>&1
    configure_dns >/dev/null 2>&1
    install_all_software >/dev/null 2>&1
    clean_system_and_docker >/dev/null 2>&1
    verify_docker >/dev/null 2>&1
    configure_iptables >/dev/null 2>&1
    set_mtu >/dev/null 2>&1
    disable_swap >/dev/null 2>&1
    optimize_network >/dev/null 2>&1
    echo "系统优化完成！"
}

main
