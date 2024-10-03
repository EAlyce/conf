#!/usr/bin/env bash

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
