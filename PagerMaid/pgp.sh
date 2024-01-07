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
    sudo apt install --upgrade git -y > /dev/null 2>&1 || { echo "Git更新失败，脚本终止。"; exit 1; }
    echo "Git更新成功"

    # 拉取git文件到/root目录
    cd /root && git clone https://github.com/TeamPGM/PagerMaid-Pyro.git "pgp$name" && cd "pgp$name" > /dev/null 2>&1 || { echo "Git文件拉取失败，脚本终止。"; exit 1; }
    echo "Git文件拉取成功"
}

open_all_ports() {
    # 提示用户是否开放所有端口
    read -p "是否开放所有端口（y/n）: " choice

    if [[ $choice =~ ^[Yy](ES|es)?$ ]]
    then
        # 用户选择开放所有端口
        sudo iptables -P INPUT ACCEPT || { echo "开放所有端口失败，脚本终止。"; exit 1; }
        sudo iptables -P FORWARD ACCEPT || { echo "开放所有端口失败，脚本终止。"; exit 1; }
        sudo iptables -P OUTPUT ACCEPT || { echo "开放所有端口失败，脚本终止。"; exit 1; }
        sudo iptables -F || { echo "开放所有端口失败，脚本终止。"; exit 1; }
        echo "所有端口已开放成功"
    else
        # 用户选择不开放所有端口
        echo "所有端口保持原状"
    fi
}

update_packages() {
    sudo apt update || { echo "更新软件包信息失败，脚本终止。"; exit 1; }
    echo "软件包信息更新成功"

    sudo apt upgrade -y || { echo "升级软件包失败，脚本终止。"; exit 1; }
    echo "软件包升级成功"

    sudo apt install python3-pip python3-venv imagemagick libwebp-dev neofetch libzbar-dev libxml2-dev libxslt-dev tesseract-ocr tesseract-ocr-all -y || { echo "安装依赖包失败，脚本终止。"; exit 1; }
    echo "依赖包安装成功"
}

install_python() {
    # 首先，我们需要确认Python的版本是否为3.11或更高
    python_version=$(python3 --version 2>&1 | cut -d ' ' -f 2 | cut -d '.' -f 1,2)
    if [[ "$python_version" < "3.11" ]]; then
        echo "Python版本需要为3.11或更高，正在自动安装Python 3.11.0..."

        # 下载Python 3.11.0
        wget https://www.python.org/ftp/python/3.11.0/Python-3.11.0.tgz > /dev/null 2>&1

        # 解压下载的文件
        tar -xvf Python-3.11.0.tgz > /dev/null 2>&1

        # 进入解压后的目录
        cd Python-3.11.0

        # 配置并编译安装
        (
            echo -n "编译安装中，请稍候..."
            ./configure --enable-optimizations > /dev/null 2>&1
            make -j$(nproc) > /dev/null 2>&1
            sudo make altinstall > /dev/null 2>&1
            echo "完成"
        ) &

        # 调用spinner函数显示转圈圈
        spinner $!

        # 返回到原来的目录
        cd ..

        # 删除下载的文件和解压后的目录
        rm -rf Python-3.11.0.tgz Python-3.11.0

        # 更新python3链接
        sudo ln -sf /usr/local/bin/python3.11 /usr/bin/python3
        echo "alias python3='python3.11'" >> ~/.bashrc && source ~/.bashrc
    else
        echo "Python版本符合要求"
    fi
}

spinner() {
    local pid=$1
    local delay=0.1
    local spin='-\|/'

    while ps -p $pid > /dev/null; do
        for i in $(seq 0 3); do
            echo -ne "\r[${spin:$i:1}] 编译安装中，请稍候..."
            sleep $delay
        done
    done
    echo -ne "\r[ ] 编译安装完成.        "
    echo
}

setup_environment() {
    # 创建并进入虚拟环境
    echo "正在设置虚拟环境..."
    if python3.11 -m venv venv > /dev/null; then
        source venv/bin/activate
        echo "虚拟环境设置成功."
    else
        echo "设置虚拟环境失败，脚本终止."
        exit 1
    fi

    # 更新pip
    echo "正在更新 pip..."
    if python3.11 -m pip install --upgrade pip > /dev/null; then
        echo "pip 更新成功."
    else
        echo "更新 pip 失败，脚本终止."
        exit 1
    fi

    # 清除pip缓存
    echo "清除 pip 缓存..."
    if python3.11 -m pip cache purge; then
        echo "pip 缓存清除成功."
    else
        echo "清除 pip 缓存失败，脚本终止."
        exit 1
    fi

# 强制重新安装 coloredlogs
echo "强制重新安装 coloredlogs..."

# 使用 Debian 默认的 python3.11 版本进行 pip 安装
if python3.11 -m pip uninstall -y coloredlogs > /dev/null && python3.11 -m pip install coloredlogs > /dev/null; then
    echo "coloredlogs 安装成功."
else
    echo "安装 coloredlogs 失败，脚本终止."
    exit 1
fi


    # 切换到目录并安装依赖
    cd /root/pgp$name
    echo "安装依赖..."
    if python3.11 -m pip install --force-reinstall -r requirements.txt > /dev/null; then
        echo "依赖安装成功."
    else
        echo "安装依赖失败，脚本终止."
        exit 1
    fi

    echo "环境设置完成."
}

configure() {
    echo "生成配置文件中 . . ."

    # 创建目录
    if mkdir -p /root/pgp$name/data; then
        echo "创建目录成功."
    else
        echo "创建目录失败，脚本终止."
        exit 1
    fi

    config_file=/root/pgp$name/data/config.yml

    # 复制配置文件
    if cp /root/pgp$name/config.gen.yml $config_file; then
        echo "复制配置文件成功."
    else
        echo "复制配置文件失败，脚本终止."
        exit 1
    fi

    # 输入并验证 api_id
    while true; do
        read -p "请输入应用程序 api_id：" -e api_id
        if sed -i "s/ID_HERE/$api_id/" $config_file; then
            echo "api_id 配置完成."
            break
        else
            echo "配置 api_id 失败，请重新输入."
        fi
    done

    # 输入并验证 api_hash
    while true; do
        read -p "请输入应用程序 api_hash：" -e api_hash
        if sed -i "s/HASH_HERE/$api_hash/" $config_file; then
            echo "api_hash 配置完成."
            break
        else
            echo "配置 api_hash 失败，请重新输入."
        fi
    done

    echo "配置文件生成完成."
}
setup_pagermaid() {
    # 进入目录
    echo "进入目录 /root/pgp$name..."
    cd /root/pgp$name || {
        echo "错误：无法进入目录 /root/pgp$name"
        return 1
    }
    echo "成功进入目录 /root/pgp$name."

    # 运行Python模块
    echo "运行Python模块..."
    if python3.11 -m pagermaid; then
        echo "Python模块运行成功."
    else
        echo "错误：无法运行Python模块"
        return 1
    fi

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

    echo "重新加载systemd守护进程..."
    if sudo systemctl daemon-reload; then
        echo "systemd守护进程重新加载成功."
    else
        echo "错误：无法重新加载systemd守护进程"
        return 1
    fi

    echo "启动PagerMaid服务..."
    if sudo systemctl start pagermaid; then
        echo "PagerMaid服务启动成功."
    else
        echo "错误：无法启动PagerMaid服务"
        return 1
    fi

    echo "设置PagerMaid服务开机自启..."
    if sudo systemctl enable --now pagermaid; then
        echo "PagerMaid服务设置开机自启成功."
    else
        echo "错误：无法设置PagerMaid服务开机自启"
        return 1
    fi

    echo "PagerMaid设置完成."
}

echo "正在使用PagerMaid多用户安装"
echo
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
