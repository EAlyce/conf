#!/usr/bin/env bash

set -euo pipefail

declare -r RED='\033[0;31m'
declare -r GREEN='\033[0;32m'
declare -r YELLOW='\033[1;33m'
declare -r NC='\033[0m'

declare -A container_map
declare -A container_names
declare -r MAX_RETRIES=3
declare -r TIMEOUT=10

trap 'echo -e "${RED}错误: 脚本执行失败在第 $LINENO 行${NC}" >&2' ERR

log_info() { echo -e "${GREEN}[INFO] $1${NC}"; }
log_warn() { echo -e "${YELLOW}[WARN] $1${NC}"; }
log_error() { echo -e "${RED}[ERROR] $1${NC}" >&2; }

check_command() {
    echo "$1"
    command -v "$1" >/dev/null 2>&1 || { log_error "需要 $1 但未安装"; exit 1; }
}

retry_command() {
    local -r cmd="$1"
    local -r description="$2"
    local retries=0
    
    while [ $retries -lt $MAX_RETRIES ]; do
        if eval "$cmd"; then
            return 0
        fi
        retries=$((retries + 1))
        log_warn "$description 失败，正在重试 ($retries/$MAX_RETRIES)"
        sleep 1
    done
    
    log_error "$description 在 $MAX_RETRIES 次尝试后失败"
    return 1
}

safe_remove_dir() {
    local dir="$1"
    if [ -d "$dir" ]; then
        if [ -n "$(ls -A "$dir")" ]; then
            log_warn "删除非空目录: $dir"
        fi
        retry_command "rm -rf \"$dir\"" "删除目录 $dir"
    fi
}

deep_clean_container() {
    local -r container_id="$1"
    local -r container_name="${container_names[$container_id]}"
    
    log_info "开始清理容器 $container_id ($container_name)..."

    local mounts volumes image

    mounts=$(docker inspect --format '{{range .Mounts}}{{println .Source}}{{end}}' "$container_id") || true
    
    volumes=$(docker inspect --format '{{range .Mounts}}{{if eq .Type "volume"}}{{println .Name}}{{end}}{{end}}' "$container_id") || true

    image=$(docker inspect --format '{{.Config.Image}}' "$container_id") || true

    log_info "停止容器..."
    retry_command "docker stop --time=$TIMEOUT $container_id" "停止容器"
    
    log_info "删除容器..."
    retry_command "docker rm -f $container_id" "删除容器"
    
    if [ -n "$mounts" ]; then
        log_info "清理挂载点..."
        echo "$mounts" | while IFS= read -r mount; do
            [ -n "$mount" ] && safe_remove_dir "$mount"
        done
    fi

    log_info "清理相关目录..."
    for search_path in "/root/$container_name" $(find /root -maxdepth 3 -type d -name "$container_name" 2>/dev/null); do
        safe_remove_dir "$search_path"
    done
    
    if [ -n "$volumes" ]; then
        log_info "删除数据卷..."
        echo "$volumes" | while IFS= read -r volume; do
            [ -n "$volume" ] && retry_command "docker volume rm $volume" "删除数据卷 $volume"
        done
    fi
    
    if [ -n "$image" ]; then
        log_info "删除镜像..."
        retry_command "docker rmi $image" "删除镜像 $image"
    fi
    
    log_info "清理系统资源..."
    docker system prune -af --volumes
    
    log_info "清理完成!"
}


list_running_containers() {

    local containers
    containers=$(docker ps --format "{{.ID}}:{{.Names}}:{{.Image}}:{{.Status}}")
    
    if [ -z "$containers" ]; then
        log_warn "没有正在运行的容器"
        exit 0
    fi
    
    log_info "正在运行的容器:"
    local index=1
    
    while IFS=: read -r id name image status; do
        echo -e "${GREEN}$index.${NC} $name ($id)"
        echo "   镜像: $image"
        echo "   状态: $status"
        container_map[$index]=$id
        container_names[$id]=$name
        ((index++))
    done <<< "$containers"
    
    echo "0. 退出脚本"
}
docker image prune -f
main() {

    check_command docker
    

    if ! docker info &>/dev/null; then
        log_error "Docker 服务未运行"
        exit 1
    fi
    

    list_running_containers
    
    echo "等待用户输入..."
    read -rp "请选择要删除的容器 (0 退出): " choice
    
    case $choice in
        0) log_info "退出脚本"; exit 0 ;;
        *) 
            if [ -n "${container_map[$choice]:-}" ]; then
                deep_clean_container "${container_map[$choice]}"
            else
                log_error "无效的选择"
                exit 1
            fi
        ;;
    esac
}
main "$@"
