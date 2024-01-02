#!/bin/bash
install_python() {
    # 更新系统
sudo apt-get update > /dev/null || true
sudo apt-get upgrade -y > /dev/null || true

# 安装必要的库和工具
sudo apt-get install -y python3-pip python3-venv imagemagick libwebp-dev neofetch libzbar-dev libxml2-dev libxslt-dev tesseract-ocr tesseract-ocr-all > /dev/null || true

# 安装Python构建依赖
sudo apt-get install -y build-essential checkinstall libncursesw5-dev libssl-dev libsqlite3-dev tk-dev libgdbm-dev libc6-dev libbz2-dev libffi-dev zlib1g-dev libreadline-dev > /dev/null || true

# 使用apt自动安装和升级Python
sudo apt-get install -y python3 > /dev/null || true
sudo apt-get upgrade -y python3 > /dev/null || true

# 链接Python和pip
sudo apt-get update && sudo apt-get install -y python3 python3-pip && ln -s /usr/bin/python3 /usr/bin/python && ln -s /usr/bin/pip3 /usr/bin/pip

# 设置Python别名并激活
echo "alias python='python3'" >> ~/.bashrc
source ~/.bashrc

# 验证Python版本
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