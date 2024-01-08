#!/bin/bash
# 定义设置 PATH 的函数
set_custom_path() {
    echo "开始检查 PATH 变量..."
    # 检查是否存在 PATH 变量，如果不存在则设置
    PATH_CHECK=$(crontab -l | grep -q '^PATH=' && echo "true" || echo "false")

    if [ "$PATH_CHECK" == "false" ]; then
        echo "PATH 变量不存在，开始设置..."
        # 设置全面的 PATH
        PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
        if [ $? -eq 0 ]; then
            echo "PATH 变量设置成功."
        else
            echo "错误：无法设置 PATH 变量"
            return 1
        fi
    else
        echo "PATH 变量已存在，无需设置."
    fi
}
# 安装 sudo 并隐藏输出过程
echo "开始优化"
apt-get install sudo > /dev/null 2>&1

# 检查是否以 root 权限运行
echo "检查root 权限"
if [[ $EUID -ne 0 ]]; then 
    echo "错误：本脚本需要 root 权限执行。" 1>&2
    exit 1
else
    echo "确认以 root 权限运行."
fi

# 定义停止 apt 和 dpkg 进程的函数
kill_process() {
    echo "开始停止 apt 和 dpkg 进程..."
    sudo pkill -9 apt || echo "没有找到正在运行的 apt 进程"
    sudo pkill -9 dpkg || echo "没有找到正在运行的 dpkg 进程"
    echo "apt 和 dpkg 进程已成功停止."
}

remove_locks() {
    echo "开始移除锁文件..."
    sudo rm -f /var/lib/dpkg/lock-frontend /var/lib/apt/lists/lock > /dev/null 2>&1 && echo "锁文件已成功移除." || echo "错误：无法移除锁文件"
}

configure_packages() {
    echo "开始配置未配置的包..."
    sudo dpkg --configure -a > /dev/null 2>&1 && echo "未配置的包已成功配置." || echo "错误：无法配置未配置的包"
}

install_curl() {
    echo "开始安装 curl..."
    apt-get install -y curl wget > /dev/null 2>&1 && echo "curl 已成功安装." || echo "错误：无法安装 curl"
}

update_dns() {
    echo "开始更新 DNS..."
    apt-get update > /dev/null 2>&1 && apt-get install -y curl wget git sudo > /dev/null 2>&1 && sudo sh -c 'echo "nameserver 8.8.8.8" > /etc/resolv.conf' > /dev/null 2>&1 && echo -e "net.core.default_qdisc=fq\nnet.ipv4.tcp_congestion_control=bbr\nnet.ipv4.tcp_ecn=1" | sudo tee -a /etc/sysctl.conf > /dev/null 2>&1 && sudo sysctl -p > /dev/null 2>&1 && sudo update-locale LANG=en_US.UTF-8 > /dev/null 2>&1 && sudo locale-gen en_US.UTF-8 > /dev/null 2>&1 && sudo update-locale LANG=en_US.UTF-8 > /dev/null 2>&1 && sudo timedatectl set-timezone Asia/Shanghai > /dev/null 2>&1 && echo "DNS 已成功更新." || echo "错误：无法更新 DNS"
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
    sudo find /var/lib/ -type f -name "Pagermaid.sh*" -exec rm -f {} \; > /dev/null 2>&1

    echo "开始下载 Installer..."
    curl -O "$installer_url" > /dev/null 2>&1 && echo "Installer 下载成功." || { echo "下载 Installer 失败"; exit 1; }

    echo "开始更改权限..."
    chmod +x "$(basename "$installer_url")" > /dev/null 2>&1 && echo "权限更改成功." || { echo "更改权限失败"; exit 1; }

    echo "开始执行 Installer..."
    "./$(basename "$installer_url")"
}
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
    echo "      PagerMaid安装选项"
    echo "----------------------------"
    echo "[1] Linux多用户(推荐)"
    echo "[2] Linux单用户"
    echo "[3] Docker多用户"
    echo "[0] 退出"
    echo "----------------------------"
    read -p "输入选项 [ 0 - 3 ]：" choice
    
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