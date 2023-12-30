#!/bin/bash
apt-get install sudo
if [[ $EUID -ne 0 ]]; then echo "错误：本脚本需要 root 权限执行。" 1>&2; exit 1; fi
kill_process() {
    echo "正在停止 apt 和 dpkg 进程..."
    sudo pkill -9 apt || true
    sudo pkill -9 dpkg || true
}

remove_locks() {
    echo "正在移除锁文件..."
    sudo rm -f /var/lib/dpkg/lock-frontend /var/lib/apt/lists/lock
}

configure_packages() {
    echo "正在配置未配置的包..."
    sudo dpkg --configure -a
}

install_curl() {
    echo "正在安装 curl..."
    sudo apt install -y curl || {
        echo "安装 curl 失败"
        exit 1
    }
}

update_dns() {
    echo "正在更新 DNS 到 Google 的 DNS..."
    echo -e "nameserver 8.8.4.4\nnameserver 8.8.8.8" | sudo tee /etc/resolv.conf
}

install_pagermaid() {
    local install_type="$1"
    local installer_url

    if [ "$install_type" == "Linux" ]; then
        echo "您选择了 Linux 环境下安装。"
        installer_url="https://raw.githubusercontent.com/EAlyce/conf/main/PagerMaid/Pagermaid.sh"
    elif [ "$install_type" == "Docker" ]; then
        echo "您选择了 Docker 环境下安装。"
        installer_url="https://raw.githubusercontent.com/EAlyce/conf/main/PagerMaid/DockerPagermaid.sh"
    else
        echo "错误的安装类型。"
        exit 1
    fi

    cd /var/lib || exit 1
    sudo find /var/lib/ -type f -name "Pagermaid.sh*" -exec rm -f {} \;

    curl -O "$installer_url" || {
        echo "下载 Installer 失败"
        exit 1
    }

    chmod +x "$(basename "$installer_url")" || {
        echo "更改权限失败"
        exit 1
    }

    "./$(basename "$installer_url")"
}

# 定义设置 PATH 的函数
set_custom_path() {
    # 检查是否存在 PATH 变量，如果不存在则设置
    PATH_CHECK=$(crontab -l | grep -q '^PATH=' && echo "true" || echo "false")

    if [ "$PATH_CHECK" == "false" ]; then
        # 设置全面的 PATH
        PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
    fi
}

# 调用设置 PATH 函数
set_custom_path
kill_process
remove_locks
configure_packages
install_curl
update_dns

while :
do
    clear
    echo "----------------------------"
    echo " PagerMaid安装选项"
    echo "----------------------------"
    echo "[1] Linux环境下安装"
    echo "[2] Docker环境下安装"
    echo "[0] 退出"
    echo "----------------------------"
    read -p "输入选项 [ 0 - 2 ] " choice
    
    case $choice in
        1) 
            install_pagermaid "Linux"
            ;;
        
        2)
            install_pagermaid "Docker"
            ;;
        
        0) 
            echo "退出"
            exit
            ;;
       
        *)
            echo "错误输入，请重新选择!"
            ;;
    esac

    read -p "按任意键返回菜单 " 
done
