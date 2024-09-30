#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

# 常量定义
readonly SNELL_CONFIG="/snell/snell.conf"
readonly SNELL_SERVER="/snell/snell-server"
readonly DEFAULT_PORT_RANGE=(10000 60000)
readonly DEFAULT_PSK_LENGTH=12
readonly IPV4_APIS=(
    "https://api.ipify.org"
    "https://ifconfig.me"
    "https://icanhazip.com"
)

# 日志函数
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >&2
}

# 错误处理函数
error_exit() {
    log "错误: $1" >&2
    exit "${2:-1}"
}

# 生成指定长度的随机密码
generate_random_password() {
    local length="${1:-$DEFAULT_PSK_LENGTH}"
    if ! openssl rand -base64 48 2>/dev/null | tr -dc 'a-zA-Z0-9' | head -c "$length"; then
        error_exit "无法生成随机密码。请检查 OpenSSL 是否正确安装。"
    fi
}

# 获取公网 IPv4 地址
get_public_ipv4() {
    local ip
    for api in "${IPV4_APIS[@]}"; do
        if ip=$(curl -s -4 -m 5 "$api"); then
            if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                echo "$ip"
                return 0
            fi
        fi
    done
    log "警告: 无法获取公网 IPv4 地址"
    return 1
}

# 检查端口是否可用
is_port_available() {
    local port="$1"
    if ! command -v nc &> /dev/null; then
        log "警告: 'nc' 命令不可用，跳过端口检查。"
        return 0
    fi
    if ! nc -z localhost "$port" &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# 获取可用端口
get_available_port() {
    local port tries=0 max_tries=50
    while ((tries < max_tries)); do
        port=$(shuf -i "${DEFAULT_PORT_RANGE[0]}"-"${DEFAULT_PORT_RANGE[1]}" -n 1)
        if is_port_available "$port"; then
            echo "$port"
            return 0
        fi
        ((tries++))
    done
    error_exit "无法找到可用端口。请检查系统端口使用情况。"
}

# 生成 Snell 服务器配置
generate_config() {
    local port psk ipv6
    
    if [[ -n "${PORT:-}" ]]; then
        if ! is_port_available "$PORT"; then
            error_exit "指定的端口 $PORT 不可用。请选择其他端口或留空以自动选择。"
        fi
        port="$PORT"
    else
        port=$(get_available_port)
    fi
    
    psk="${PSK:-$(generate_random_password)}"
    ipv6="${IPV6:-false}"
    
    cat > "$SNELL_CONFIG" <<EOF || error_exit "无法写入配置文件 $SNELL_CONFIG"
[snell-server]
listen = 0.0.0.0:$port
psk = $psk
ipv6 = $ipv6
EOF
    
    log "Snell 服务器配置生成完成。"
    log "端口: $port"
    log "PSK: $psk"
    log "IPv6: $ipv6"
}

# 检查 Snell 服务器可执行文件
check_snell_server() {
    if [[ ! -f "$SNELL_SERVER" ]]; then
        error_exit "Snell 服务器可执行文件不存在: $SNELL_SERVER"
    fi
    if [[ ! -x "$SNELL_SERVER" ]]; then
        error_exit "Snell 服务器可执行文件没有执行权限: $SNELL_SERVER"
    fi
}

# 主函数
main() {
    log "开始配置 Snell 服务器..."
    check_snell_server
    generate_config
    
    local public_ip
    if public_ip=$(get_public_ipv4); then
        log "公网 IPv4 地址: $public_ip"
    fi
    
    log "启动 Snell 服务器..."
    exec "$SNELL_SERVER" -c "$SNELL_CONFIG"
}

# 执行主函数
main "$@"
