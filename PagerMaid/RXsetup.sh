#!/bin/bash

if [[ $EUID -ne 0 ]]; then
    echo "错误：本脚本需要 root 权限执行。" 1>&2
    exit 1
fi

echo "正在安装 sudo，请稍候..."
sudo apt-get install -qq sudo

kill_process() {
    echo "正在停止 apt 和 dpkg 进程..."
    sudo pkill -9 apt || true
    sudo pkill -9 dpkg || true
}

echo "sudo 安装完成。"
remove_locks() {
    echo "正在移除锁文件..."
    sudo rm -f /var/lib/dpkg/lock-frontend /var/lib/apt/lists/lock
    echo "锁文件移除完成。"
}
configure_packages() {
    echo "正在配置未配置的包..."
    sudo dpkg --configure -a
    echo "包配置完成。"
}

update_dns() {
    echo "正在更新 DNS 设置..."
    
    sudo apt-get update > /dev/null && sudo apt-get install -y curl wget git sudo > /dev/null || true
    sudo sh -c 'echo "nameserver 8.8.8.8" > /etc/resolv.conf' > /dev/null || true
    echo -e "net.core.default_qdisc=fq\nnet.ipv4.tcp_congestion_control=bbr\nnet.ipv4.tcp_ecn=1" | sudo tee -a /etc/sysctl.conf > /dev/null || true
    sudo sysctl -p > /dev/null || true

    sudo update-locale LANG=en_US.UTF-8 > /dev/null && sudo locale-gen en_US.UTF-8 > /dev/null && sudo update-locale LANG=en_US.UTF-8 > /dev/null || true
    sudo timedatectl set-timezone Asia/Shanghai > /dev/null || true

    echo "DNS 更新完成."
    echo "export HISTSIZE=10000" >> ~/.bashrc
    source ~/.bashrc
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

install_pagermaid() {
    local install_type="$1"
    local installer_url

    if [ "$install_type" == "Linuxpgp" ]; then
        echo "您选择了 Linux多用户 环境下安装。"
        installer_url="https://raw.githubusercontent.com/EAlyce/conf/main/PagerMaid/pgp.sh"
    elif [ "$install_type" == "Linux" ]; then
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

    echo "正在执行 PagerMaid 安装脚本..."
    "./$(basename "$installer_url")"
    echo "PagerMaid 安装脚本执行完毕."
}
    while :
    do
        echo "----------------------------"
        echo "      PagerMaid安装选项"
        echo "----------------------------"
        echo "[1] Linux多用户版本"
        echo "[2] Linux(不推荐)"
        echo "[3] Docker版本"
        echo "[0] 退出"
        echo "----------------------------"

        read -p "输入选项 [0 - 3]: " choice

        case "$choice" in
            [0-3]) break;;
            *) echo "输入无效，请重新输入";;
        esac

        case $choice in
            1) 
                install_pagermaid "Linuxpgp"
                ;;
            2)
                install_pagermaid "Linux"
                ;;
            3)
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