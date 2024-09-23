#!/bin/bash

# 函数：设置系统环境
system_setup() {
    echo "设置 DNS 和时区..."
    echo "nameserver 8.8.8.8" > /etc/resolv.conf
    timedatectl set-timezone Asia/Shanghai > /dev/null 2>&1

    # 设置 PATH
    crontab -l 2>/dev/null | grep -q '^PATH=' || {
        export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
        echo "PATH 设置成功。"
    }

    # 系统清理
    echo "正在清理系统..."
    apt clean -y > /dev/null 2>&1
    apt autoclean -y > /dev/null 2>&1
    apt autoremove -y > /dev/null 2>&1
    docker system prune -a --volumes -f > /dev/null 2>&1

    # 更新软件包和安装所需软件
    echo "正在更新软件包..."
    apt-get update -y > /dev/null 2>&1
    apt-get install -y curl wget git sudo > /dev/null 2>&1

    # 更新 DNS 配置和内核参数
    echo "更新 DNS 配置和内核参数..."
    cat <<EOF >> /etc/sysctl.conf
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.ipv4.tcp_ecn=1
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=1
EOF
    sysctl -p > /dev/null 2>&1
    echo "系统设置完成。"
}

# 函数：安装 PagerMaid
install_pagermaid() {
    local install_type="$1"
    local installer_url

    case "$install_type" in
        "Linuxpgp") installer_url="https://raw.githubusercontent.com/EAlyce/conf/main/PagerMaid/pgp.sh" ;;
        "Linux") installer_url="https://raw.githubusercontent.com/EAlyce/conf/main/PagerMaid/Pagermaid.sh" ;;
        "Docker") installer_url="https://raw.githubusercontent.com/EAlyce/conf/main/PagerMaid/DockerPagermaid.sh" ;;
        *) echo "错误的安装类型。"; exit 1 ;;
    esac

    cd /var/lib || exit 1
    find /var/lib/ -type f -name "Pagermaid.sh*" -exec rm -f {} \; > /dev/null 2>&1

    echo "开始下载 Installer..."
    curl -O "$installer_url" > /dev/null 2>&1 || { echo "下载失败"; exit 1; }

    echo "开始更改权限并执行 Installer..."
    chmod +x "$(basename "$installer_url")" && "./$(basename "$installer_url")" || { echo "执行失败"; exit 1; }
}

# 检查 root 权限
[[ $EUID -ne 0 ]] && { echo "错误：本脚本需要 root 权限执行。" >&2; exit 1; }
echo "确认以 root 权限运行."

# 调用系统设置函数
system_setup

# 主循环菜单
while true; do
    clear
    echo "----------------------------"
    echo "      PagerMaid安装选项"
    echo "----------------------------"
    echo "[1] Linux多用户"
    echo "[2] 官方Linux单用户"
    echo "[3] Docker多用户(推荐)"
    echo "[0] 退出"
    echo "----------------------------"
    read -p "输入选项 [ 0 - 3 ]：" choice
    
    case $choice in
        1) install_pagermaid "Linuxpgp" ;;
        2) install_pagermaid "Linux" ;;
        3) install_pagermaid "Docker" ;;
        0) echo "退出"; exit ;;
        *) echo "错误输入，请重新选择!" ;;
    esac

    read -p "按任意键返回菜单 "
done
