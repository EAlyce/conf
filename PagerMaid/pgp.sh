#!/usr/bin/env bash

clone_git() {
    apt install python3-pip python3-venv imagemagick libwebp-dev neofetch libzbar-dev libxml2-dev libxslt-dev tesseract-ocr tesseract-ocr-all -y
    # 更新Git
    apt install --upgrade git -y > /dev/null 2>&1 || { echo "Git更新失败，脚本终止。"; exit 1; }
    echo "Git更新成功"

    # 拉取git文件到/root目录
    cd /root && git clone https://github.com/TeamPGM/PagerMaid-Pyro.git "pgp$name" && cd "pgp$name" > /dev/null 2>&1 || { echo "Git文件拉取失败，脚本终止。"; exit 1; }
    echo "Git文件拉取成功"
}

install_python() {
    # 检查是否已经安装 Python
    if command -v python3 &>/dev/null; then
        echo "Python 已经安装"
        return
    fi
    # 更新包管理器
    apt update
    # 安装 Python
    apt install -y python3 python3-pip
    # 验证安装
    if command -v python3 &>/dev/null; then
        echo "Python 安装成功"
    else
        echo "Python 安装失败"
    fi
}

setup_environment() {
python3 -m pip install --upgrade pip
python3 -m pip install --break-system-packages coloredlogs
cd /root/pgp$name
python3 -m pip install --break-system-packages -r requirements.txt
pip install pydantic==1.10.9
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
    if [[ $api_id =~ ^[0-9]{8}$ ]]; then
        if sed -i "s/ID_HERE/$api_id/" "$config_file"; then
            echo "api_id 配置完成."
            break
        else
            echo "配置 api_id 失败，请重新输入."
        fi
    else
        echo "请输入8位数字的有效 api_id."
    fi
done

# 输入并验证 api_hash
while true; do
    read -p "请输入应用程序 api_hash：" -e api_hash
    if [[ $api_hash =~ ^[0-9a-fA-F]{32}$ ]]; then
        if sed -i "s/HASH_HERE/$api_hash/" "$config_file"; then
            echo "api_hash 配置完成."
            break
        else
            echo "配置 api_hash 失败，请重新输入."
        fi
    else
        echo "请输入32位十六进制字符串的有效 api_hash."
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
cat > /etc/systemd/system/pgp$name.service <<-TEXT
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
TEXT
# 进入目录
cd /root/pgp$name || { echo "错误：无法进入目录 /root/pgp$name"; return 1; }

# 替换systemd服务文件中的pgp$name
echo "替换systemd服务文件中的pgp$name..."
sed -i "s/pgp\$name/pgp$name/g" /etc/systemd/system/pgp$name.service

# 重新加载systemd守护进程
echo "重新加载systemd守护进程..."
if systemctl daemon-reload; then
    echo "systemd守护进程重新加载成功."
else
    echo "错误：无法重新加载systemd守护进程"
    return 1
fi

# 启动PagerMaid服务
echo "启动PagerMaid服务..."
if systemctl start pgp$name; then
    echo "PagerMaid服务启动成功."
else
    echo "错误：无法启动PagerMaid服务"
    journalctl -xe
    return 1
fi

# 设置PagerMaid服务开机自启
echo "设置PagerMaid服务开机自启..."
if systemctl enable --now pgp$name; then
    echo "PagerMaid服务设置开机自启成功."
else
    echo "错误：无法设置PagerMaid服务开机自启"
    return 1
fi

# 重新启动PagerMaid服务
echo "重新启动PagerMaid服务..."
if systemctl restart pgp$name; then
    echo "PagerMaid服务重新启动成功."
else
    echo "错误：无法重新启动PagerMaid服务"
    journalctl -xe
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
    
    clone_git
    install_python
    setup_environment
    configure
    setup_pagermaid
    deactivate
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
                rm -rf /root/$dir
            done
            echo "卸载完成"
            ;;
        2)
            read -p "请输入你想要删除的目录的序号： " index
            if [[ "$index" =~ ^[0-9]+$ ]] && [ "$index" -gt 0 ] && [ "$index" -le "${#dirs[@]}" ]; then
                echo "正在删除 ${dirs[$((index-1))]}..."
                rm -rf /root/${dirs[$((index-1))]}
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
