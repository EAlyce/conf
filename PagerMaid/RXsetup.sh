#!/bin/bash

system_setup() {
    # 设置 DNS 和时区，隐藏输出
    echo "设置 DNS 和时区..."
    echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf > /dev/null
    sudo timedatectl set-timezone Asia/Shanghai > /dev/null 2>&1

    # 设置 PATH
    if ! crontab -l 2>/dev/null | grep -q '^PATH='; then
        export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
        echo "PATH 设置成功。"
    else
        echo "PATH 已存在。"
    fi

    # 系统清理
    echo "正在清理系统..."
    sudo apt clean > /dev/null 2>&1
    sudo apt autoclean > /dev/null 2>&1
    sudo apt autoremove -y > /dev/null 2>&1
    sudo rm -rf /tmp/* > /dev/null 2>&1
    sudo docker system prune -a --volumes -f > /dev/null 2>&1

    # 更新软件包和安装所需软件
    echo "正在更新软件包..."
    sudo apt-get update > /dev/null 2>&1
    sudo apt-get install -y curl wget git sudo > /dev/null 2>&1

    # 更新 DNS 配置和内核参数
    echo "更新 DNS 配置和内核参数..."
    echo -e "net.core.default_qdisc=fq\nnet.ipv4.tcp_congestion_control=bbr\nnet.ipv4.tcp_ecn=1\nnet.ipv4.ip_forward=1\nnet.ipv6.conf.all.forwarding=1" | sudo tee -a /etc/sysctl.conf > /dev/null
    sudo sysctl -p > /dev/null 2>&1

    echo "系统设置完成。"
}


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
    sudo find /var/lib/ -type f -name "Pagermaid.sh*" -exec rm -f {} \; > /dev/null 2>&1

    echo "开始下载 Installer..."
    curl -O "$installer_url" > /dev/null 2>&1 && echo "Installer 下载成功." || { echo "下载 Installer 失败"; exit 1; }

    echo "开始更改权限..."
    chmod +x "$(basename "$installer_url")" > /dev/null 2>&1 && echo "权限更改成功." || { echo "更改权限失败"; exit 1; }

    echo "开始执行 Installer..."
    "./$(basename "$installer_url")"
}

# 主脚本执行流程
echo "检查root权限"
if [[ $EUID -ne 0 ]]; then 
    echo "错误：本脚本需要 root 权限执行。" 1>&2
    exit 1
else
    echo "确认以 root 权限运行."
fi

system_setup

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
