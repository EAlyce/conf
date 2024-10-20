#!/usr/bin/env bash

set -e  # 出现错误时立即退出

# 检查并安装依赖
check_dependencies() {
    local dependencies=("curl" "wget" "openssl" "iptables" "netfilter-persistent")
    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            echo "$dep 未安装，正在安装..."
            apt-get update && apt -y install "$dep" || { echo "安装 $dep 失败"; exit 1; }
        fi
    done
}

# 获取公共 IP 和位置
get_public_ip() {
    local ip_services=("ifconfig.me" "ipinfo.io/ip" "icanhazip.com" "ipecho.net/plain" "ident.me")
    for service in "${ip_services[@]}"; do
        public_ip=$(curl -s --max-time 3 "$service" || { echo "获取公共 IP 失败"; return 1; })
        if [[ "$public_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "公共 IP: $public_ip"
            # 尝试获取位置
            location=$(curl -s --max-time 3 "ipinfo.io/$public_ip" | jq -r '.city + ", " + .region + ", " + .country' || echo "无法获取位置")
            echo "主机位置: ${location:-'未知'}"
            return 0
        fi
    done
    echo "无法获取公共 IP."
    return 1
}


# 生成 SSL 证书和密钥
generate_cert() {
    local cert_path="$1"
    local key_path="$2"
    openssl ecparam -genkey -name prime256v1 -out "$key_path"
    openssl req -new -x509 -days 36500 -key "$key_path" -out "$cert_path" -subj "/CN=$3"
    chmod 600 "$cert_path" "$key_path"
    echo "证书已生成: $cert_path"
    echo "密钥已生成: $key_path"
}

# 随机选择一个未被占用的端口
get_random_port() {
    local port
    while true; do
        port=$(shuf -i 40000-50000 -n 1)
        if ! ss -tunlp | grep -w udp | grep -q ":$port"; then
            echo "$port"
            return
        fi
    done
}

# 配置端口跳转
setup_port_forwarding() {
    local firstport=40000
    local endport=50000
    local target_port="$1"

    echo "配置端口跳转从 $firstport 到 $endport，目标端口 $target_port"

    # 清空现有规则
    bash <(curl -fsSL https://github.com/EAlyce/conf/raw/refs/heads/main/Linux/iptables.sh)

    # 添加新的 DNAT 规则
    iptables -t nat -A PREROUTING -p udp --dport "$firstport:$endport" -j DNAT --to-destination :"$target_port"
    ip6tables -t nat -A PREROUTING -p udp --dport "$firstport:$endport" -j DNAT --to-destination :"$target_port"

    # 检查是否添加成功
    if iptables -t nat -L -n | grep -q "DNAT.*$target_port"; then
        echo "端口跳转配置成功。"
    else
        echo "配置端口跳转失败。"
        return 1
    fi

    # 保存规则
    netfilter-persistent save >/dev/null 2>&1
}

# 生成随机密码
generate_random_password() {
    openssl rand -hex 8
}

# 显示配置
show_configuration() {
    local location="$1"
    local port="$2"
    local public_ip="$3"
    local password="$4"
    local proxy_site="$5"

    echo "$location $port = hysteria2, $public_ip, $port, password=$password, ecn=true, skip-cert-verify=true, sni=$proxy_site, port-hopping=40000-50000, port-hopping-interval=30"
}

# Hysteria 安装
install_hysteria() {
    wget -N https://raw.githubusercontent.com/Misaka-blog/hysteria-install/main/hy2/install_server.sh
    bash install_server.sh

    # 检查安装是否成功
    if [[ -f "/usr/local/bin/hysteria" ]]; then
        echo "Hysteria 2 安装成功！"
    else
        echo "Hysteria 2 安装失败！"
        exit 1
    fi

    mkdir -p /etc/hysteria

    cat << EOF > /etc/hysteria/config.yaml
listen: :$1

tls:
  cert: /etc/hysteria/cert.crt
  key: /etc/hysteria/private.key

quic:
  initStreamReceiveWindow: 16777216
  maxStreamReceiveWindow: 16777216
  initConnReceiveWindow: 33554432
  maxConnReceiveWindow: 33554432

auth:
  type: password
  password: $2

masquerade:
  type: proxy
  proxy:
    url: https://$3
    rewriteHost: true
EOF

    # 启动服务
    systemctl daemon-reload
    systemctl enable hysteria-server
    systemctl start hysteria-server
}

# 卸载 Hysteria 服务
uninstall_hysteria() {
    systemctl stop hysteria-server.service >/dev/null 2>&1
    systemctl disable hysteria-server.service >/dev/null 2>&1
    rm -f /lib/systemd/system/hysteria-server.service /lib/systemd/system/hysteria-server@.service
    rm -rf /usr/local/bin/hysteria /etc/hysteria /root/hy /root/hysteria.sh
    iptables -t nat -F PREROUTING >/dev/null 2>&1
    netfilter-persistent save >/dev/null 2>&1

    echo "Hysteria 2 已彻底卸载完成！"
}

# 更新 Hysteria 内核
update_core() {
    wget -N https://raw.githubusercontent.com/Misaka-blog/hysteria-install/main/hy2/install_server.sh
    bash install_server.sh
    rm -f install_server.sh
}

# 菜单交互
menu() {
    local first_run=true  # 添加标志来跟踪是否是第一次运行
    while true; do
        clear
        echo "Hysteria 2 管理脚本"
        echo "--------------------"
        echo "1. 安装 Hysteria 2"
        echo "2. 卸载 Hysteria 2"
        echo "3. 显示 Hysteria 2 配置文件"
        echo "4. 更新 Hysteria 2 内核"
        echo "0. 退出脚本"
        echo "--------------------"

        if $first_run; then
            read -rp "请输入选项 [0-4]: " menuInput
            first_run=false  # 第一次输入后将标志设为 false
        else
            read -rp "请输入选项 [0-4]: " menuInput
        fi

        # 处理用户输入
        case "$menuInput" in
            1 )
                local port
                port=$(get_random_port)
                get_public_ip
                local password
                password=$(generate_random_password)
                generate_cert "/etc/hysteria/cert.crt" "/etc/hysteria/private.key" "www.bing.com"
                setup_port_forwarding "$port"
                install_hysteria "$port" "$password" "www.bing.com"
                show_configuration "$LOCATION" "$port" "$public_ip" "$password" "www.bing.com"
                break ;;  # 安装后自动退出
            2 )
                uninstall_hysteria
                read -p "按回车键返回...";;  # 卸载后返回菜单
            3 )
                show_configuration "$LOCATION" "$port" "$public_ip" "$PASSWORD" "www.bing.com"
                read -p "按回车键继续...";;  # 显示配置文件
            4 )
                update_core
                read -p "按回车键返回...";;  # 更新后返回菜单
            0 )
                exit 0 ;;
            * )
                echo "无效选项，请重新输入。"
                sleep 2 ;;
        esac
    done
}

check_dependencies
get_public_ip  # 在菜单之前获取公共 IP
menu
