#!/usr/bin/env bash
set -euo pipefail

# 常量定义
readonly IPV4_API_ENDPOINTS=(
    "https://api.ipify.org"
    "https://ifconfig.me"
    "https://icanhazip.com"
)

# 函数：生成随机端口
random_port() {
    shuf -i 1024-65535 -n 1
}

# 函数：生成随机 PSK
random_psk() {
    tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 20
}

# 函数：获取公网 IPv4 地址
get_public_ipv4() {
    local ipv4=""
    
    for endpoint in "${IPV4_API_ENDPOINTS[@]}"; do
        if ipv4=$(curl -s -4 -m 5 "$endpoint"); then
            if [[ -n "$ipv4" && "$ipv4" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                echo "$ipv4"
                return 0
            fi
        fi
    done
    
    echo "错误: 无法获取公网 IPv4 地址" >&2
    return 1
}

# 函数：生成配置文件
generate_config() {
    local port="${PORT:-$(random_port)}"
    local psk="${PSK:-$(random_psk)}"
    local ipv6="${IPV6:-false}"
    local config_file="/snell/snell.conf"

    cat > "$config_file" <<EOF
[snell-server]
listen=0.0.0.0:$port
psk=$psk
ipv6=$ipv6
EOF

    echo "配置文件已生成: $config_file"
    echo "PORT=$port"
    echo "PSK=$psk"
    return 0
}

# 函数：打印代理配置
print_proxy() {
    local ipv4=$1
    local port="${PORT:-$(grep -oP 'listen=0.0.0.0:\K\d+' /snell/snell.conf)}"
    local psk="${PSK:-$(grep -oP 'psk=\K.*' /snell/snell.conf)}"

    echo "Proxy = snell, $ipv4, $port, psk=$psk, version=5, tfo=false"
}

# 主函数
main() {
    # 生成配置文件
    generate_config

    # 获取公网 IP
    local ipv4
    if ! ipv4=$(get_public_ipv4); then
        exit 1
    fi

    # 打印代理配置
    print_proxy "$ipv4"

    # 启动服务器
    exec /snell/snell-server -c /snell/snell.conf
}

# 执行主函数
main

