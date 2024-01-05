#!/bin/bash
#搭建多用户pagermaid-pyro
#位置存放于/root/pgp$name

define_name() {
    # 使用openssl生成5位随机数
    random_number=$(openssl rand -hex 5)

    while true; do
        # 提示用户是否使用自定义名字
        read -p "是否使用自定义名字（y/n）: " choice

        if [[ $choice =~ ^[Yy](ES|es)?$ ]]
        then
            # 用户选择使用自定义名字
            read -p "请输入自定义名字（仅限大小写英文和阿拉伯数字）: " custom_name

            # 检查用户输入是否符合规则
            if [[ $custom_name =~ ^[A-Za-z0-9]+$ ]]
            then
                name=$custom_name
            else
                echo "输入不符合规则，请重新输入"
                continue
            fi
        else
            # 用户选择不使用自定义名字，使用openssl生成的随机数作为名字
            name=$random_number
        fi

        # 检查/root/pgp$name目录是否已经存在
        if [ -d "/root/pgp$name" ]; then
            echo "/root/pgp$name目录已经存在，请重新输入名字"
        else
            break
        fi
    done

    # 输出结果
    echo "你的名字是: $name"
}

clone_git() {
    # 更新Git
    sudo apt install --upgrade git -y
    # 拉取git文件到/root目录
    cd /root && git clone https://github.com/TeamPGM/PagerMaid-Pyro.git "pgp$name" && cd "pgp$name"
}

open_all_ports() {
    # 提示用户是否开放所有端口
    read -p "是否开放所有端口（y/n）: " choice

    if [[ $choice =~ ^[Yy](ES|es)?$ ]]
    then
        # 用户选择开放所有端口
        sudo iptables -P INPUT ACCEPT
        sudo iptables -P FORWARD ACCEPT
        sudo iptables -P OUTPUT ACCEPT
        sudo iptables -F
        echo "所有端口已开放"
    else
        # 用户选择不开放所有端口
        echo "所有端口保持原状"
    fi
}

update_packages() {
    sudo apt update && sudo apt upgrade -y
    sudo apt install python3-pip python3-venv imagemagick libwebp-dev neofetch libzbar-dev libxml2-dev libxslt-dev tesseract-ocr tesseract-ocr-all -y
}

install_python() {
    # 首先，我们需要确认Python的版本是否为3.11或更高
    python_version=$(python3 --version 2>&1 | cut -d ' ' -f 2 | cut -d '.' -f 1,2)
    if [[ "$python_version" < "3.11" ]]; then
        echo "Python版本需要为3.11或更高，正在自动安装Python 3.11.0..."
        
        # 下载Python 3.11.0
        wget https://www.python.org/ftp/python/3.11.0/Python-3.11.0.tgz
        
        # 解压下载的文件
        tar -xvf Python-3.11.0.tgz
        
        # 进入解压后的目录
        cd Python-3.11.0
        
        # 配置并编译安装
        ./configure --enable-optimizations
        make -j$(nproc)
        sudo make altinstall
        
        # 返回到原来的目录
        cd ..
        
        # 删除下载的文件和解压后的目录
        rm -rf Python-3.11.0.tgz Python-3.11.0
        
        # 更新python3链接
        sudo ln -sf /usr/local/bin/python3.11 /usr/bin/python3
        echo "alias python3='python3.11'" >> ~/.bashrc && source ~/.bashrc
    fi
}

setup_environment() {
    # 创建并进入虚拟环境
    python3.11 -m venv venv
    source venv/bin/activate

    # 更新pip
    python3.11 -m pip install --upgrade pip

    # 清除pip缓存
    python3.11 -m pip cache purge

    # 升级pip
    # python3 -m pip install --upgrade pip

    # 强制重新安装 coloredlogs
    python3.11 -m pip install --force-reinstall coloredlogs
    cd /root/pgp$name
    python3.11 -m pip install --force-reinstall -r /root/pgp$name/requirements.txt > /dev/null || true
}

configure() {
    echo "生成配置文件中 . . ."
    mkdir -p /root/pgp$name/data
    config_file=/root/pgp$name/data/config.yml
    cp /root/pgp$name/config.gen.yml $config_file
    read -p "请输入应用程序 api_id：" -e api_id
    sed -i "s/ID_HERE/$api_id/" $config_file
    read -p "请输入应用程序 api_hash：" -e api_hash
    sed -i "s/HASH_HERE/$api_hash/" $config_file
}

setup_pagermaid() {
    # 进入目录
    cd /root
   
    cd /root/pgp$name || {
        echo "错误：无法进入目录 /root/pgp$name"
        return 1
    }

    # 运行Python模块
    python3 -m pagermaid || {
        echo "错误：无法运行Python模块"
        return 1
    }

    # 创建systemd服务文件
    echo "正在写入系统进程守护 . . ."
cat <<-'TEXT' > /etc/systemd/system/pgp$name.service
[Unit]
Description=PagerMaid-Pyro telegram utility daemon
After=network.target

[Install]
WantedBy=multi-user.target

[Service]
Type=simple
WorkingDirectory=/var/lib/pgp
ExecStart=/root/pgp$name/venv/bin/python3 -m pagermaid
Restart=always
TEXT

    sudo systemctl daemon-reload >>/dev/null 2>&1
    sudo systemctl start pagermaid >>/dev/null 2>&1
    sudo systemctl enable --now pagermaid >>/dev/null 2>&1
    }
{
    echo "PagerMaid服务'$name'已成功设置并启动。"
}
prompt_choice() {
    while true; do
        echo "1: 安装"
        echo "2: 卸载"
        echo "0: 退出脚本"
        read -p "请输入您的选择: " choice
        case $choice in
            0|1|2) break;;
            *) echo "无效的选择，请重新输入。";;
        esac
    done
}
install() {
    echo "开始安装..."
    open_all_ports
    define_name
    clone_git
    update_packages
    install_python
    setup_environment
    configure
    setup_pagermaid
    deactivate
    echo "安装完成"
}

uninstall() {
    echo "开始卸载..."

    # 列出 /root 下所有的 pgp$name 目录
    echo "以下是 /root 下所有的 pgp$name 目录："
    dirs=($(ls /root | grep pgp))
    if [ ${#dirs[@]} -eq 0 ]; then
        echo "没有找到任何 pgp$name 目录。"
        return 0
    fi
    for i in "${!dirs[@]}"; do
        echo "$((i+1)). ${dirs[$i]}"
    done

    # 询问用户是否要删除这些目录
    echo "请选择以下操作："
    echo "1. 删除全部"
    echo "2. 删除单个"
    echo "3. 不删除并退出"
    read -p "你的选择是： " choice

    case "$choice" in
        1)
            echo "正在删除全部..."
            for dir in "${dirs[@]}"; do
                sudo rm -rf /root/$dir
            done
            echo "卸载完成"
            ;;
        2)
            read -p "请输入你想要删除的目录的序号： " index
            if [[ "$index" =~ ^[0-9]+$ ]] && [ "$index" -gt 0 ] && [ "$index" -le "${#dirs[@]}" ]; then
                echo "正在删除 ${dirs[$((index-1))]}..."
                sudo rm -rf /root/${dirs[$((index-1))]}
                echo "卸载完成"
            else
                echo "错误：无效的序号"
            fi
            ;;
        3)
            echo "你选择了不删除。卸载操作已取消。"
            ;;
        *)
            echo "错误：无效的选择"
            ;;
    esac
}

main() {
    while true
    do
        prompt_choice
        case $choice in
            1) install ;;
            2) uninstall ;;
            0) echo "退出脚本"; exit 0 ;;
            *) echo "无效的选择，请重新输入" ;;
        esac
    done
}

main
