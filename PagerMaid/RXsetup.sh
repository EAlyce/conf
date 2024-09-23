#!/bin/bash

# 日志函数
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

system_setup() {
    echo "开始设置系统环境..."
    
    # 动画函数
    animate() {
        local spin='-\|/'
        local i=0
        while true; do
            i=$(( (i+1) % 4 ))
            printf "\r[%c] 正在设置..." "${spin:$i:1}"
            sleep 0.1
        done
    }

    # 开始动画
    animate &
    ANIMATE_PID=$!

    # 执行实际的设置命令并捕获输出
    OUTPUT=$(bash -c "$(curl -fsSL https://raw.githubusercontent.com/EAlyce/conf/refs/heads/main/Linux/Linux.sh)" 2>&1)
    EXIT_CODE=$?

    # 停止动画
    kill $ANIMATE_PID
    wait $ANIMATE_PID 2>/dev/null

    # 清除动画行
    echo -e "\r\033[K"

    if [ $EXIT_CODE -ne 0 ]; then
        echo "错误：系统环境设置失败"
        echo "错误信息："
        echo "$OUTPUT"
        return 1
    else
        echo "系统环境设置成功"
    fi
}

# 函数：安装 PagerMaid
install_pagermaid() {
    local install_type="$1"
    local installer_url
    local original_dir=$(pwd)

    case "$install_type" in
        "Linuxpgp") installer_url="https://raw.githubusercontent.com/EAlyce/conf/main/PagerMaid/pgp.sh" ;;
        "Linux") installer_url="https://raw.githubusercontent.com/EAlyce/conf/main/PagerMaid/Pagermaid.sh" ;;
        "Docker") installer_url="https://raw.githubusercontent.com/EAlyce/conf/main/PagerMaid/DockerPagermaid.sh" ;;
        *) log "错误：无效的安装类型 '$install_type'"; return 1 ;;
    esac

    log "开始安装 PagerMaid ($install_type)..."

    # 切换到目标目录
    if ! cd /var/lib; then
        log "错误：无法切换到 /var/lib 目录"
        return 1
    fi

    # 删除旧的安装文件
    log "清理旧的安装文件..."
    find /var/lib/ -type f -name "Pagermaid.sh*" -delete

    # 下载并执行 Installer
    log "下载 Installer..."
    if ! curl -O "$installer_url"; then
        log "错误：下载失败"
        cd "$original_dir"
        return 1
    fi

    log "设置执行权限并运行 Installer..."
    chmod +x "$(basename "$installer_url")"
    if ! "./$(basename "$installer_url")"; then
        log "错误：执行失败"
        cd "$original_dir"
        return 1
    fi

    log "PagerMaid ($install_type) 安装完成"
    cd "$original_dir"
}

# 检查 root 权限
if [[ $EUID -ne 0 ]]; then
    log "错误：本脚本需要 root 权限执行。"
    exit 1
fi

log "确认以 root 权限运行."

# 调用系统设置函数
if ! system_setup; then
    log "错误：系统设置失败，退出安装。"
    exit 1
fi

# 主循环菜单
while true; do
    clear
    echo "----------------------------"
    echo "      PagerMaid安装选项"
    echo "----------------------------"
    echo "[1] Linux多用户"
    echo "[2] 官方Linux单用户"
    echo "[3] Docker多用户(推荐)"
    echo "[4] 卸载 PagerMaid"
    echo "[0] 退出"
    echo "----------------------------"
    read -p "输入选项 [ 0 - 4 ]：" choice
    
    case $choice in
        1) install_pagermaid "Linuxpgp" ;;
        2) install_pagermaid "Linux" ;;
        3) install_pagermaid "Docker" ;;
        4) 
            log "卸载功能尚未实现。请手动卸载或参考 PagerMaid 文档。"
            read -p "按 Enter 键继续..."
            ;;
        0) 
            log "退出安装程序"
            exit 0 
            ;;
        *) 
            log "错误：无效的选项 '$choice'"
            read -p "按 Enter 键继续..."
            ;;
    esac

    if [[ $choice =~ ^[123]$ ]]; then
        read -p "安装已完成。按 Enter 键返回主菜单，或输入 'q' 退出：" exit_choice
        if [[ $exit_choice == "q" ]]; then
            log "用户选择退出"
            exit 0
        fi
    fi
done
