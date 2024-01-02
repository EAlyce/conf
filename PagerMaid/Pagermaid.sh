#!/bin/bash
check_ip() {
    ip_services=("ifconfig.me" "ipinfo.io/ip" "icanhazip.com" "ipecho.net/plain" "ident.me")
    public_ip=""

    for service in "${ip_services[@]}"; do
        if public_ip=$(curl -s "$service" 2>/dev/null); then
            if [[ "$public_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                echo "公网IP: $public_ip"
                break
            else
                echo "$service 返回的不是一个有效的IP地址：$public_ip"
            fi
        else
            echo "$service 无法连接或响应太慢"
        fi
        sleep 1  # 在尝试下一个服务之前稍微延迟
    done

    [[ "$public_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "所有服务都无法获取公网IP。"; exit 1; }

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
    # 更新系统
    sudo apt-get update > /dev/null || true
    sudo apt-get upgrade > /dev/null || true

    # 安装一些必要的库和工具
    sudo apt install python3-pip python3-venv imagemagick libwebp-dev neofetch libzbar-dev libxml2-dev libxslt-dev tesseract-ocr tesseract-ocr-all -y > /dev/null || true

    # 安装一些Python的构建依赖
    sudo apt-get install -y build-essential checkinstall > /dev/null || true
    sudo apt-get install -y libncursesw5-dev libssl-dev libsqlite3-dev tk-dev libgdbm-dev > /dev/null || true libc6-dev libbz2-dev libffi-dev zlib1g-dev libreadline-dev > /dev/null || true

    # 使用apt自动安装和升级Python
    sudo apt-get install -y python3 > /dev/null || true
    sudo apt-get upgrade -y python3 > /dev/null || true
    
    apt update && apt install -y python3 python3-pip && ln -s /usr/bin/python3 /usr/bin/python && ln -s /usr/bin/pip3 /usr/bin/pip

    # 设置Python的别名并激活
    echo "alias python='python3'" >> ~/.bashrc
    source ~/.bashrc
    apt update && apt install -y python3 python3-pip && ln -s /usr/bin/python3 /usr/bin/python && ln -s /usr/bin/pip3 /usr/bin/pip

    python3 --version
}
configure() {
    echo "生成配置文件中 . . ."
    config_file=/var/lib/pagermaid/data/config.yml
    cp /var/lib/pagermaid/config.gen.yml $config_file
    read -p "请输入应用程序 api_id：" -e api_id
    sed -i "s/ID_HERE/$api_id/" $config_file
    read -p "请输入应用程序 api_hash：" -e api_hash
    sed -i "s/HASH_HERE/$api_hash/" $config_file
}

systemctl_reload() {
    echo "正在写入系统进程守护 . . ."
    sudo cat <<-'TEXT' > /etc/systemd/system/pagermaid.service
    [Unit]
    Description=PagerMaid-Pyro Telegram Utility Daemon
    After=network.target

    [Service]
    Type=simple
    WorkingDirectory=/var/lib/pagermaid
    ExecStart=/var/lib/pagermaid/venv/bin/python3 -m pagermaid
    Restart=always

    [Install]
    WantedBy=multi-user.target
TEXT
    sudo systemctl daemon-reload >>/dev/null 2>&1
    sudo systemctl start pagermaid >>/dev/null 2>&1
    sudo systemctl enable --now pagermaid >>/dev/null 2>&1
}

start_installation() {
    check_sys
    check_ip
    install_python
    sudo rm -rf /var/lib/PagerMaid-Pyro
    git clone https://github.com/TeamPGM/PagerMaid-Pyro.git > /dev/null || true
    mv PagerMaid-Pyro /var/lib/pagermaid
    cd /var/lib/pagermaid
    python3 -m venv venv
    source venv/bin/activate
    python3 -m pip install --upgrade pip > /dev/null || true
    pip install coloredlogs > /dev/null || true
    pip3 install -r requirements.txt > /dev/null || true
    mkdir -p /var/lib/pagermaid/data > /dev/null || true
    configure
    python3 -m pagermaid
    systemctl_reload
    # 离开虚拟环境
    deactivate
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

shon_online