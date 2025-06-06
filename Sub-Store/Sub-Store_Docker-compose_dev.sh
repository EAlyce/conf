#!/usr/bin/env bash
set -euo pipefail
IFS=$\'\n\t\'

# Configuration Variables
readonly DATA_DIR="/root/sub-store-data"
readonly LOG_FILE="/var/log/sub-store-setup.log"
readonly SCRIPT_NAME="$(basename "$0")"
readonly SUB_STORE_PORT="3001" # Port for Sub-Store service
readonly APT_UPDATE_STAMP_FILE="/var/lib/apt/periodic/update-success-stamp"
readonly APT_UPDATE_MAX_AGE_SECONDS=$((24 * 60 * 60)) # 1 day

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [$SCRIPT_NAME] $*" | tee -a "$LOG_FILE"
}

error() {
    log "错误: $*" >&2
    exit 1
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "此脚本需要 root 权限运行"
    fi
}

install_dependencies() {
    log "检查并安装依赖..."
    local missing_deps=()
    
    for cmd in curl cron docker docker-compose; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log "发现缺失的依赖: ${missing_deps[*]}"
        
        if [[ -f "$APT_UPDATE_STAMP_FILE" ]]; then
            local last_update_time
            last_update_time=$(stat -c %Y "$APT_UPDATE_STAMP_FILE")
            local current_time
            current_time=$(date +%s)
            if (( current_time - last_update_time < APT_UPDATE_MAX_AGE_SECONDS )); then
                log "软件包列表在过去24小时内已更新，跳过 apt-get update。"
            else
                log "软件包列表陈旧，执行 apt-get update..."
                apt-get update -qq || error "更新软件包列表失败"
            fi
        else
            log "首次运行或无法确定上次更新时间，执行 apt-get update..."
            apt-get update -qq || error "更新软件包列表失败"
        fi
        
        for dep in "${missing_deps[@]}"; do
            case "$dep" in
                docker|docker-compose)
                    log "重要提示: $dep 未找到。请参照官方文档手动安装 Docker 和 Docker Compose。"
                    log "Docker 安装文档: https://docs.docker.com/engine/install/"
                    log "Docker Compose 安装文档: https://docs.docker.com/compose/install/"
                    error "$dep 需要手动安装。脚本将终止。"
                    ;;
                *)
                    log "正在安装 $dep..."
                    apt-get install -y "$dep" || error "安装 $dep 失败"
                    log "$dep 安装完成。"
                    ;;
            esac
        done
    else
        log "所有必要的依赖已安装"
    fi
    
    log "确保 cron 和 docker 服务正在运行..."
    if ! systemctl is-active --quiet cron; then
        log "启动 cron 服务..."
        systemctl start cron || error "启动 cron 服务失败"
    fi
    if ! systemctl is-active --quiet docker; then
        log "启动 docker 服务..."
        systemctl start docker || error "启动 docker 服务失败"
    fi
    log "cron 和 docker 服务已激活。"
}

download_file() {
    local dest="$1"
    local primary_url="$2"
    local backup_url="$3"
    local max_retries=3
    local retry=0
    local curl_output
    
    log "尝试下载文件到 $dest ..."
    while [[ $retry -lt $max_retries ]]; do
        log "尝试从主源下载: $primary_url (尝试 $((retry + 1))/$max_retries)"
        if curl_output=$(curl -sSL --connect-timeout 10 --retry 3 -o "$dest" -w '%{http_code}' "$primary_url") && [[ "$curl_output" == "200" ]]; then
            log "从主源下载成功: $dest"
            return 0
        fi        
        log "从主源下载失败 (HTTP code: $curl_output)。尝试备用源: $backup_url"
        if curl_output=$(curl -sSL --connect-timeout 10 --retry 3 -o "$dest" -w '%{http_code}' "$backup_url") && [[ "$curl_output" == "200" ]]; then
            log "从备用源下载成功: $dest"
            return 0
        fi
        log "从备用源下载失败 (HTTP code: $curl_output)。"
        ((retry++))
        if [[ $retry -lt $max_retries ]]; then
            log "等待2秒后重试..."
            sleep 2
        fi
    done
    error "下载文件失败: $dest (curl 错误代码: $curl_output)"
}

get_public_ip() {
    log "正在获取公共 IP 地址..."
    local ip_services=("https://ifconfig.me/ip" "https://ipinfo.io/ip" "https://api.ipify.org")
    local timeout=5
    local public_ip_val
    
    for service in "${ip_services[@]}"; do
        log "尝试使用服务 $service 获取 IP..."
        if public_ip_val=$(curl -sSf --connect-timeout "$timeout" "$service"); then
            if [[ $public_ip_val =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
                log "获取到公共 IP 地址: $public_ip_val"
                echo "$public_ip_val"
                return 0
            else
                log "从 $service 获取到的内容不是有效的 IP 地址: $public_ip_val"
            fi
        else
            log "从 $service 获取 IP 失败 (curl exit code: $?)."
        fi
        sleep 1
    done
    
    log "警告: 经过所有服务尝试后，未能获取公共 IP 地址。"
    # Not calling error here, let print_success_info handle it as a warning and placeholder IP
    echo ""
    return 1 # Indicate failure to get IP, but don't exit script from here
}

setup_docker() {
    log "配置 Docker 服务..."
    
    local secret_key
    secret_key=$(openssl rand -hex 32)
    log "已生成新的 SUB_STORE_FRONTEND_BACKEND_PATH 密钥。"
    
    mkdir -p "$DATA_DIR" || error "无法创建数据目录 $DATA_DIR"
    log "确保数据目录 $DATA_DIR 已创建。"
    
    local script_dir_for_compose
    local compose_file_path

    if [[ "${BASH_SOURCE[0]}" == /dev/fd/* || "${BASH_SOURCE[0]}" == /proc/self/fd/* ]]; then
        log "脚本通过进程替换执行。Docker Compose 文件将使用 $DATA_DIR 目录。"
        script_dir_for_compose="$DATA_DIR"
    else
        script_dir_for_compose="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
    fi
    compose_file_path="$script_dir_for_compose/docker-compose-sub-store.yml"
    log "Docker Compose 文件路径设置为: $compose_file_path"

    log "停止并移除现有的 sub-store Docker 容器和网络 (如果存在)..."
    docker rm -f sub-store >/dev/null 2>&1 || true
    if [[ -f "$compose_file_path" ]]; then
      docker compose -f "$compose_file_path" -p sub-store down --remove-orphans >/dev/null 2>&1 || true
    elif [[ -f "docker-compose.yml" ]]; then
      log "在 $compose_file_path 未找到 docker-compose 文件，尝试在当前目录使用 docker-compose.yml"
      docker compose -p sub-store down --remove-orphans >/dev/null 2>&1 || true
    fi
    
    log "创建 docker-compose 文件于 $compose_file_path ..."
    mkdir -p "$(dirname "$compose_file_path")" || error "无法创建目录 $(dirname "$compose_file_path") 用于 docker-compose 文件"
    cat > "$compose_file_path" <<EOF
name: sub-store
services:
  sub-store:
    image: xream/sub-store:http-meta
    container_name: sub-store
    restart: always
    environment:
      SUB_STORE_BACKEND_UPLOAD_CRON: "55 23 * * *"
      SUB_STORE_FRONTEND_BACKEND_PATH: "/$secret_key"
    ports:
      - "${SUB_STORE_PORT}:${SUB_STORE_PORT}"
    volumes:
      - ${DATA_DIR}:/opt/app/data
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:${SUB_STORE_PORT}"]
      interval: 30s
      timeout: 10s
      retries: 3
EOF
    log "Docker Compose 文件已创建: $compose_file_path"
    
    log "拉取最新的 Docker 镜像 (sub-store)..."
    docker compose -f "$compose_file_path" -p sub-store pull || error "拉取 Docker 镜像失败"
    
    log "启动 Docker 服务 (sub-store)..."
    docker compose -f "$compose_file_path" -p sub-store up -d || error "启动 Docker 服务失败"

    log "检查 sub-store 容器状态..."
    if docker ps --filter "name=sub-store" --filter "status=running" | grep -q "sub-store"; then
        log "sub-store 容器正在运行。"
    else
        log "警告: sub-store 容器似乎没有正确启动。请检查 Docker 日志。"
        docker logs sub-store --tail 50 || log "无法获取 sub-store 日志 (可能容器未成功创建)。"
    fi
    
    local update_cmd="0 3 * * * cd \"$script_dir_for_compose\" && docker compose -f \"$compose_file_path\" -p sub-store pull && docker compose -f \"$compose_file_path\" -p sub-store up -d"
    log "设置 crontab 定时更新任务..."
    (crontab -l 2>/dev/null | grep -v "sub-store"; echo "$update_cmd") | sort -u | crontab -
    log "Crontab 更新任务已设置。"
    
    log "进入服务等待循环 (最长等待30秒)..."
    local max_wait=30
    local count=0
    local service_is_up=false
    while [[ $count -lt $max_wait ]]; do
        log "等待循环: 尝试 $((count + 1)) of $max_wait. 当前时间: $(date +'%T')"
        if curl -s --fail --connect-timeout 2 "http://127.0.0.1:${SUB_STORE_PORT}" >/dev/null 2>&1; then
            log "服务已在 http://127.0.0.1:${SUB_STORE_PORT} 上成功响应。"
            service_is_up=true
            break
        else
            log "服务在 http://127.0.0.1:${SUB_STORE_PORT} 上未响应或响应错误 (curl exit code: $?)."
        fi
        ((count++))
        if [[ $count -lt $max_wait ]]; then
            log "休眠1秒后重试..."
            sleep 1
        fi
    done
    log "服务等待循环结束。"

    if $service_is_up; then
        log "服务已确认启动。"
    else
        log "警告: 服务在端口 $SUB_STORE_PORT 上启动超时 (等待了 ${count} 秒)。可能仍在后台进行中。"
    fi
    
    log "准备调用 print_success_info 函数..."
    print_success_info "$secret_key"
    log "print_success_info 函数调用完成。"
}

print_success_info() {
    log "进入 print_success_info 函数。"
    local secret_key="$1"
    local public_ip_addr

    log "在 print_success_info 中: 调用 get_public_ip..."
    public_ip_addr=$(get_public_ip) # Assigns the output of get_public_ip
    local get_ip_exit_status=$?     # Capture exit status of get_public_ip
    log "在 print_success_info 中: get_public_ip 调用完成. Public IP: '${public_ip_addr}', Exit Status: $get_ip_exit_status"

    if [[ $get_ip_exit_status -ne 0 ]] || [[ -z "$public_ip_addr" ]]; then
        log "警告: 未能获取公共 IP 地址或获取时出错。成功信息中的 URL 可能不完整或不正确。"
        public_ip_addr="<无法获取IP>"
    fi

    log "在 print_success_info 中: 准备打印部署信息..."
    # Using printf for more reliable output, especially with -e interpretation
    printf "\n部署完成！您的 Sub-Store 信息如下：\n"
    printf "\nSub-Store 面板：http://%s:%s\n" "${public_ip_addr}" "${SUB_STORE_PORT}"
    printf "后端地址：http://%s:%s/%s\n\n" "${public_ip_addr}" "${SUB_STORE_PORT}" "${secret_key}"
    printf "请保存好以上信息！\n"
    printf "如果无法访问，请检查防火墙设置是否允许端口 %s 的入站连接。\n\n" "${SUB_STORE_PORT}"
    log "在 print_success_info 中: 部署信息打印完毕。"
    log "退出 print_success_info 函数。"
}

main() {
    mkdir -p "$(dirname "$LOG_FILE")" || error "无法创建日志目录 $(dirname "$LOG_FILE")"
    touch "$LOG_FILE" || error "无法写入日志文件 $LOG_FILE"

    log "脚本开始执行..."
    check_root
    install_dependencies
    setup_docker
    log "脚本执行完毕。"
}

trap '{
    ret=$?
    log "错误: 脚本在行号 $LINENO 处因命令 '$BASH_COMMAND' (退出码: $ret) 执行失败。"
    log "脚本路径: ${BASH_SOURCE[0]} (实际路径: $(realpath "${BASH_SOURCE[0]}" 2>/dev/null || echo "无法解析"))"
    exit $ret
}' ERR

main

