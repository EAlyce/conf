#!/bin/bash
# 检测本地系统是否安装Python 3.11+
install_or_update_python() {
    # 检测本地系统是否安装Python 3.11+
    if command -v python3.11 &> /dev/null; then
        # 如果已安装，则将python3默认使用3.11+
        update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1
    else
        # 如果未安装，则执行安装Python 3.11的代码
        install_python() {
            # 更新系统
            apt update

            # 安装编译Python所需的依赖项
            apt install -y build-essential zlib1g-dev libffi-dev libssl-dev libncurses-dev libsqlite3-dev libreadline-dev libbz2-dev liblzma-dev libgdbm-dev libdb5.3-dev libexpat1-dev libmpdec-dev libffi-dev tk-dev

            # 下载Python 3.11源代码
            wget https://www.python.org/ftp/python/3.11.0/Python-3.11.0.tar.xz

            # 解压缩源代码
            tar -xf Python-3.11.0.tar.xz

            # 进入源代码目录
            cd Python-3.11.0

            # 配置并安装Python 3.11
            ./configure --enable-optimizations
            make -j $(nproc)
            make altinstall

            # 清理安装过程中的临时文件
            cd ..
            rm -rf Python-3.11.0
            rm Python-3.11.0.tar.xz

            # 创建软链接以使python3.11命令可用
            ln -s /usr/local/bin/python3.11 /usr/bin/python3.11
            alias python=python3.11
            python --version
        }

        # 执行安装Python 3.11的函数
        install_python
    fi
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
    # 创建 Python 3.11 虚拟环境并输出信息到/dev/null
python3.11 -m venv venv > /dev/null

# 激活虚拟环境
source venv/bin/activate

# 清除pip缓存
python3.11 -m pip cache purge

# 升级pip
python3.11 -m pip install --upgrade pip

# 强制重新安装 coloredlogs
python3.11 -m pip install --force-reinstall coloredlogs

# 强制重新安装 requirements.txt 中的依赖项并输出信息到/dev/null
python3.11 -m pip install --force-reinstall -r requirements.txt > /dev/null || true

# 创建目录
mkdir -p /var/lib/pagermaid/data

# 运行 configure（假设这是一个可执行文件）
configure

# 运行 pagermaid
python3.11 -m pagermaid

    systemctl_reload
    # 离开虚拟环境
    deactivate
    echo "PagerMaid部署完成"
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