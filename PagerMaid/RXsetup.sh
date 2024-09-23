#!/bin/bash

# 函数：设置系统环境
system_setup() {
    echo "设置 DNS 和时区..."
    # 使用 resolvconf 设置 DNS
    echo "nameserver 8.8.8.8" > /etc/resolvconf/resolv.conf.d/head
    resolvconf -u

    timedatectl set-timezone Asia/Shanghai

    # 设置 PATH
    if ! grep -q '^export PATH=' /etc/profile; then
        echo 'export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH' >> /etc/profile
        echo "PATH 设置成功。"
    fi

    # 系统清理
    echo "正在清理系统..."
    apt update && apt upgrade -y
    apt clean -y
    apt autoclean -y
    apt autoremove -y
    if command -v docker &> /dev/null; then
        docker system prune -a --volumes -f
    fi

    # 更新软件包和安装所需软件
    echo "正在更新软件包..."
    apt-get update -y
    apt-get install -y curl wget git

    # 更新 DNS 配置和内核参数
    echo "更新 DNS 配置和内核参数..."
    declare -A sysctl_params=(
        ["net.core.default_qdisc"]="fq"
        ["net.ipv4.tcp_congestion_control"]="bbr"
        ["net.ipv4.tcp_ecn"]="1"
        ["net.ipv4.ip_forward"]="1"
        ["net.ipv6.conf.all.forwarding"]="1"
    )

    for key in "${!sysctl_params[@]}"; do
        if ! grep -q "^$key" /etc/sysctl.conf; then
            echo "$key=${sysctl_params[$key]}" >> /etc/sysctl.conf
        fi
    done
    sysctl -p

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
        *) echo "错误的安装类型。"; return 1 ;;
    esac

    cd /var/lib || { echo "无法切换到 /var/lib 目录"; return 1; }
    find /var/lib/ -type f -name "Pagermaid.sh*" -exec rm -f {} \;

    echo "开始下载 Installer..."
    if ! curl -O "$installer_url"; then
        echo "下载失败"
        return 1
    fi

    echo "开始更改权限并执行 Installer..."
    chmod +x "$(basename "$installer_url")"
    if ! "./$(basename "$installer_url")"; then
        echo "执行失败"
        return 1
    fi
}

# 检查 root 权限
if [[ $EUID -ne 0 ]]; then
    echo "错误：本脚本需要 root 权限执行。" >&2
    exit 1
fi

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
