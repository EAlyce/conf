#!/usr/bin/env bash
set -euo pipefail

# 定义可用的 IPv4 API
readonly IPV4_API_ENDPOINTS=(
    "https://api.ipify.org"
    "https://ifconfig.me"
    "https://icanhazip.com"
)

# 随机端口生成器
random_port() {
    shuf -i 1024-65535 -n 1
}

# 随机 PSK 生成器
random_psk() {
    tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 20
}

# 获取公网 IPv4 地址
get_public_ipv4() {
    local ipv4=""
    for endpoint in "${IPV4_API_ENDPOINTS[@]}"; do
        if ipv4=$(curl -s -4 -m 5 "$endpoint"); then
            if [[ "$ipv4" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                echo "$ipv4"
                return 0
            fi
        fi
    done
    echo "错误: 无法获取公网 IPv4 地址" >&2
    return 1
}

# 生成 snell 配置文件
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
}

# 打印 snell 代理配置信息
print_proxy() {
    local ipv4=$1
    local port="${PORT:-$(grep -oP 'listen=0.0.0.0:\K\d+' /snell/snell.conf)}"
    local psk="${PSK:-$(grep -oP 'psk=\K.*' /snell/snell.conf)}"

    echo "Proxy = snell, $ipv4, $port, psk=$psk, version=5, tfo=false"
}

# 主逻辑入口
main() {
    generate_config

    local ipv4
    if ! ipv4=$(get_public_ipv4); then
        exit 1
    fi

    print_proxy "$ipv4"

    if [[ ! -x /snell/snell-server ]]; then
        echo "错误: /snell/snell-server 不存在或不可执行"
        exit 2
    fi

    exec /snell/snell-server -c /snell/snell.conf
}

main
