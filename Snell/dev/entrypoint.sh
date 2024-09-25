#!/bin/bash
set -euo pipefail

SNELL_CONFIG="/snell/snell.conf"
SNELL_SERVER="/snell/snell-server"

generate_random_string() {
    tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w "$1" | head -n 1
}

get_public_ipv4() {
    local ipv4_apis=(
        "https://api.ipify.org"
        "https://ifconfig.me"
        "https://icanhazip.com"
    )
    
    for api in "${ipv4_apis[@]}"; do
        if IPV4=$(curl -s -4 "$api"); then
            echo "$IPV4"
            return 0
        fi
    done
    
    echo "无法获取公网 IPv4 地址" >&2
    return 1
}

generate_config() {
    local port="${PORT:-$(shuf -i 1024-65535 -n 1)}"
    local psk="${PSK:-$(generate_random_string 20)}"
    local ipv6="${IPV6:-false}"
    
    cat > "$SNELL_CONFIG" <<EOF
[snell-server]
listen = 0.0.0.0:$port
psk = $psk
ipv6 = $ipv6
EOF
    
    echo "Snell 服务器配置生成完成。"
    echo "端口: $port"
    echo "PSK: $psk"
    echo "IPv6: $ipv6"
}

main() {
    generate_config
    
    if public_ip=$(get_public_ipv4); then
        echo "公网 IPv4 地址: $public_ip"
    fi
    
    exec "$SNELL_SERVER" -c "$SNELL_CONFIG"
}

main "$@"
