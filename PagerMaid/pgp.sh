#!/usr/bin/env bash

name=$(shuf -i 10-99 -n 1)

# 安装必要的软件包
install_dependencies() {
    apt install -y python3-pip python3-venv imagemagick libwebp-dev neofetch libzbar-dev libxml2-dev libxslt-dev tesseract-ocr tesseract-ocr-all git
}

# 检查并安装 Python
install_python() {
    if ! command -v python3 &>/dev/null; then
        apt update
        apt install -y python3 python3-pip
        echo "Python 安装成功"
    else
        echo "Python 已经安装"
    fi
}

# 设置 Python 环境
setup_environment() {
    python3 -m pip install --upgrade pip
    python3 -m pip install --break-system-packages coloredlogs
    cd /root/pgp$name || exit 1
    python3 -m pip install --break-system-packages -r requirements.txt
    pip install pydantic==1.10.9 pyyaml
}

# 生成配置文件
configure() {
    echo "生成配置文件中 . . ."
    local config_file=/root/pgp$name/data/config.yml

    mkdir -p /root/pgp$name/data || { echo "创建目录失败"; exit 1; }
    cp /root/pgp$name/config.gen.yml "$config_file" || { echo "复制配置文件失败"; exit 1; }

    read_api_id "$config_file"
    read_api_hash "$config_file"

    echo "配置文件生成完成."
}

# 输入并验证 api_id
read_api_id() {
    local config_file=$1
    while true; do
        read -p "请输入应用程序 api_id：" api_id
        if [[ $api_id =~ ^[0-9]{8}$ ]]; then
            sed -i "s/ID_HERE/$api_id/" "$config_file" && echo "api_id 配置完成." && break
        else
            echo "请输入8位数字的有效 api_id."
        fi
    done
}

# 输入并验证 api_hash
read_api_hash() {
    local config_file=$1
    while true; do
        read -p "请输入应用程序 api_hash：" api_hash
        if [[ $api_hash =~ ^[0-9a-fA-F]{32}$ ]]; then
            sed -i "s/HASH_HERE/$api_hash/" "$config_file" && echo "api_hash 配置完成." && break
        else
            echo "请输入32位十六进制字符串的有效 api_hash."
        fi
    done
}

# 设置 PagerMaid 服务
setup_pagermaid() {
    echo "进入目录 /root/pgp$name..."
    cd /root/pgp$name || { echo "无法进入目录"; return 1; }

    echo "运行Python模块..."
    if ! python3 -m pagermaid; then
        echo "错误：无法运行Python模块"
        return 1
    fi

    create_systemd_service
}

# 创建 systemd 服务文件
create_systemd_service() {
    local service_file=/etc/systemd/system/pgp$name.service
    cat > "$service_file" <<-EOF
[Unit]
Description=PagerMaid-Pyro telegram utility daemon
After=network.target

[Install]
WantedBy=multi-user.target

[Service]
Type=simple
WorkingDirectory=/root/pgp$name
ExecStart=/root/pgp$name/venv/bin/python3 -m pagermaid
Restart=always
EOF

    systemctl daemon-reload
    systemctl start pgp$name
    systemctl enable --now pgp$name

    echo "PagerMaid服务设置完成."
}

# 主函数
main() {
    install_dependencies
    install_python
    clone_git
    setup_environment
    configure
    setup_pagermaid
}

# 克隆 Git 仓库
clone_git() {
    echo "克隆 Git 仓库..."
    cd /root || exit 1
    git clone https://github.com/TeamPGM/PagerMaid-Pyro.git "pgp$name" || { echo "Git文件拉取失败"; exit 1; }
    echo "Git文件拉取成功"
}

# 脚本入口
main
