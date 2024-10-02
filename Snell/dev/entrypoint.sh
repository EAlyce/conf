#!/bin/bash
set -e

random_port() {
    shuf -i 1024-65535 -n 1
}

random_psk() {
    cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 20 | head -n 1
}

get_public_ipv4() {
    IPV4=$(curl -s -4 https://api.ipify.org)

    if [ -z "$IPV4" ]; then
        IPV4=$(curl -s -4 https://ifconfig.me)
    fi

    if [ -z "$IPV4" ]; then
        IPV4=$(curl -s -4 https://icanhazip.com)
    fi

    if [ -z "$IPV4" ]; then
        echo "无法获取公网 IPv4 地址"
        exit 1
    fi
}

generate_config() {
    PORT=${PORT:-$(random_port)}
    PSK=${PSK:-$(random_psk)}
    IPV6=${IPV6:-false}

    cat >/snell/snell.conf <<EOF
[snell-server]
listen=0.0.0.0:$PORT
psk=$PSK
ipv6=$IPV6
EOF

    echo "Snell 服务器配置生成完成。"
    echo "端口: $PORT"
    echo "PSK: $PSK"
    echo "IPv6: $IPV6"
}

generate_config
get_public_ipv4

echo "公网 IPv4 地址: $IPV4"

exec /snell/snell-server -c /snell/snell.conf