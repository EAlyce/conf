#!/bin/bash

install_or_update_python() {
    # 检测是否已安装 Python 3
    if command -v python3 &> /dev/null; then
        INSTALLED_VERSION=$(python3 --version | awk '{print $2}')
        echo "已安装的 Python 版本: $INSTALLED_VERSION"
        
        # 比较当前安装的 Python 版本是否高于 3.10
        if [[ $(echo "$INSTALLED_VERSION" | awk -F. '{print ($1 * 100 + $2)}') -ge 310 ]]; then
            echo "已安装的 Python 版本高于 3.10，无需安装或更新。"
            return
        else
            echo "已安装的 Python 版本低于 3.10，正在更新 Python..."
        fi
    else
        echo "Python 3 未安装，正在安装最新版本的 Python 3..."
    fi

    # 更新系统
    sudo apt update

    # 安装编译 Python 所需的依赖项
    sudo apt install -y build-essential zlib1g-dev libffi-dev libssl-dev \
    libncurses-dev libsqlite3-dev libreadline-dev libbz2-dev liblzma-dev \
    libgdbm-dev libdb5.3-dev libexpat1-dev libmpdec-dev tk-dev wget

    # 获取最新版本的 Python 3
    PYTHON_VERSION=$(wget -qO- https://www.python.org/ftp/python/ | grep -oP 'href="\K[0-9.]+(?=/")' | sort -V | tail -n 1)
    
    # 比较最新版本是否高于 3.10
    if [[ $(echo "$PYTHON_VERSION" | awk -F. '{print ($1 * 100 + $2)}') -lt 310 ]]; then
        echo "最新的 Python 版本 ($PYTHON_VERSION) 低于 3.10，无需安装。"
        return
    fi

    echo "正在安装 Python $PYTHON_VERSION..."

    # 下载 Python 源代码
    wget https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tar.xz

    # 解压缩源代码
    tar -xf Python-${PYTHON_VERSION}.tar.xz

    # 进入源代码目录
    cd Python-${PYTHON_VERSION}

    # 配置并安装 Python
    ./configure --enable-optimizations
    make -j $(nproc)
    sudo make altinstall

    # 清理安装过程中的临时文件
    cd ..
    rm -rf Python-${PYTHON_VERSION} Python-${PYTHON_VERSION}.tar.xz

    # 创建软链接以确保 python3 命令可用
    sudo ln -sf /usr/local/bin/python3.${PYTHON_VERSION%.*} /usr/bin/python3

    # 设置默认 python3 版本为最新版本
    sudo update-alternatives --install /usr/bin/python3 python3 /usr/local/bin/python3.${PYTHON_VERSION%.*} 1

    # 输出 Python 版本以验证安装
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
    sudo systemctl enable pagermaid >>/dev/null 2>&1
}

start_installation() {
    install_or_update_python
    sudo apt-get update && sudo apt-get install -y python3-venv

    # 进入目录
    cd /var/lib

    # 删除旧文件夹
    sudo rm -rf /var/lib/PagerMaid-Pyro
    sudo rm -rf /var/lib/pagermaid

    # 克隆新仓库
    git clone https://github.com/TeamPGM/PagerMaid-Pyro.git

    # 移动新文件夹
    sudo mv PagerMaid-Pyro /var/lib/pagermaid

    # 进入新目录
    cd /var/lib/pagermaid

    # 创建 Python 虚拟环境并输出信息到/dev/null
    python3 -m venv venv > /dev/null

    # 激活虚拟环境
    source venv/bin/activate

    # 清除pip缓存
    python -m pip cache purge

    # 升级pip
    python -m pip install --upgrade pip

    # 强制重新安装 coloredlogs
    python -m pip install --force-reinstall coloredlogs emoji

    # 强制重新安装 requirements.txt 中的依赖项并输出信息到/dev/null
    python -m pip install --force-reinstall -r requirements.txt > /dev/null || true

    # 创建目录
    mkdir -p /var/lib/pagermaid/data

    # 运行 configure（假设这是一个可执行文件）
    configure

    # 运行 pagermaid
    python -m pagermaid

    systemctl_reload

    # 离开虚拟环境
    deactivate

    echo "PagerMaid部署完成"
}

cleanup() {
    if [ ! -d "/var/lib/pagermaid" ]; then
        echo "目录不存在不需要卸载。"
    else
        echo "正在关闭 PagerMaid . . ."
        if ! sudo systemctl disable pagermaid >>/dev/null 2>&1; then
            echo "错误：无法关闭 PagerMaid。" 1>&2
            exit 1
        fi
        sudo systemctl stop pagermaid >>/dev/null 2>&1
        echo "正在删除 PagerMaid 文件 . . ."
        
        sudo rm -rf /etc/systemd/system/pagermaid.service >>/dev/null 2>&1
        sudo rm -rf /var/lib/pagermaid >>/dev/null 2>&1

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
    *) echo "输入错误！" ;;
    esac
}

shon_online
