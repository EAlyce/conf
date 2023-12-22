#!/bin/bash

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "错误：本脚本需要 root 权限执行。" 1>&2
        exit 1
    fi
}

check_ip() {
    country=$(curl --noproxy '*' -sSL https://api.myip.com/ | jq -r '.country' 2>/dev/null)
    if [[ $? -ne 0 ]]; then
        echo "警告：无法获取IP地址信息。" 1>&2
    else
        if [[ $country == "China" ]]; then
            echo "错误：本脚本不支持境内服务器使用。" 1>&2
            exit 1
        fi
    fi
}

check_sys() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        ID_LIKE=$(echo "$ID_LIKE" | awk '{print tolower($0)}')
        ID=$(echo "$ID" | awk '{print tolower($0)}')
        if [[ $ID == "debian" || $ID_LIKE == "debian" ]]; then
            release="debian"
        elif [[ $ID == "ubuntu" || $ID_LIKE == "ubuntu" ]]; then
            release="ubuntu"
        else
            echo "错误：本脚本只支持 Debian 和 Ubuntu。" 1>&2
            exit 1
        fi
    else
        echo "错误：无法检测操作系统。" 1>&2
        exit 1
    fi
}

install_python() {
    apt-get update -qq && apt-get upgrade -y -qq
    apt-get install -y python3 python3-pip neofetch libzbar-dev git -qq
}

configure() {
    sudo mkdir -p /var/lib/pagermaid/data
    cd /var/lib/pagermaid
    config_file=/var/lib/pagermaid/data/config.yml
    echo "生成配置文件中 . . ."
    cp /var/lib/pagermaid/config.gen.yml $config_file
    read -p "请输入应用程序 api_id：" -e api_id
    sed -i "s/ID_HERE/$api_id/" $config_file
    read -p "请输入应用程序 api_hash：" -e api_hash
    sed -i "s/HASH_HERE/$api_hash/" $config_file
}

login_screen() {
    cd /var/lib/pagermaid
    python3 -m pagermaid
    systemctl_reload
}

systemctl_reload() {
    echo "正在写入系统进程守护 . . ."
    sudo cat <<'TEXT' > /etc/systemd/system/pagermaid.service
    [Unit]
    Description=PagerMaid-Pyro Telegram Utility Daemon
    After=network.target

    [Install]
    WantedBy=multi-user.target

    [Service]
    Type=simple
    WorkingDirectory=/var/lib/pagermaid
    ExecStart=/usr/bin/python3 -m pagermaid
    Restart=always
TEXT
    sudo systemctl daemon-reload >>/dev/null 2>&1
    sudo systemctl start pagermaid >>/dev/null 2>&1
    sudo systemctl enable --now pagermaid >>/dev/null 2>&1
}

start_installation() {
    check_sys
    check_root
    check_ip
    echo "正在克隆仓库"
    if ! git clone https://github.com/TeamPGM/PagerMaid-Pyro.git; then
        echo "错误：无法克隆仓库。" 1>&2
        exit 1
    fi
    mv PagerMaid-Pyro /var/lib/pagermaid
    
    cd /var/lib/pagermaid
    pip3 install -r requirements.txt
    mkdir -p /var/lib/pagermaid/data
    configure
    login_screen
    log_file="/var/lib/pagermaid/data/pagermaid.log.txt"
    key1="PagerMaid-Pyro"
    key2="已启动"
    key3=",help"
    key4="以获得帮助消息"
    tail -f $log_file | awk "/$key1/ && /$key2/ && /$key3/ && /$key4/ {exit}" || exit 1
    echo "完成"
}

cleanup() {
    if [ ! -x "/var/lib/pagermaid" ]; then
        echo "目录不存在不需要卸载。"
    else
        echo "正在关闭 PagerMaid . . ."
        if ! systemctl disable pagermaid >>/dev/null 2>&1; then
            echo "错误：无法关闭 PagerMaid。" 1>&2
            exit 1
        fi
        systemctl stop pagermaid >>/dev/null 2>&1
        echo "正在删除 PagerMaid 文件 . . ."
        
        rm -rf /etc/systemd/system/pagermaid.service >>/dev/null 2>&1
        rm -rf /var/lib/pagermaid >>/dev/null 2>&1

        echo "卸载完成 . . ."
    fi
}

shon_online() {
    echo "一键脚本出现任何问题请转手动搭建！ https://xtaolabs.com/"
    echo ""
    echo ""
    echo "请选择您需要进行的操作:"
    echo "  1) 安装 PagerMaid"
    echo "  2) 卸载 PagerMaid"
    echo "  3) 退出脚本"
    echo ""
    echo "     Version：2.0"
    echo ""
    echo -n "请输入编号: "
    read N
    case $N in
    1) start_installation ;;
    2) cleanup ;;
    3) exit ;;
    *) echo "Wrong input!" ;;
    esac
}

check_sys
shon_online