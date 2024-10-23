#!/usr/bin/env bash

# 清理防火墙规则
clean_rules() {
    echo "清理现有防火墙规则..."
    iptables -F
    iptables -t nat -F
    iptables -t mangle -F
    iptables -X
}

# 默认允许策略
allow_all() {
    echo "配置默认允许策略..."
    for chain in INPUT FORWARD OUTPUT; do
        iptables -P $chain ACCEPT
    done
    # Docker NAT
    iptables -t nat -A POSTROUTING -s 172.17.0.0/16 ! -o docker0 -j MASQUERADE
}

# 默认拒绝策略
secure_rules() {
    echo "配置默认拒绝策略..."
    # 设置默认策略
    for chain in INPUT FORWARD OUTPUT; do
        iptables -P $chain DROP
    done
    
    # Docker 规则
    echo "配置 Docker 规则..."
    iptables -A INPUT -i docker0 -j ACCEPT
    iptables -A FORWARD -i docker0 -o docker0 -j ACCEPT
    iptables -A FORWARD -i docker0 ! -o docker0 -j ACCEPT
    iptables -A FORWARD -o docker0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
    iptables -t nat -A POSTROUTING -s 172.17.0.0/16 ! -o docker0 -j MASQUERADE
    
    # 基础规则
    echo "配置基础规则..."
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A OUTPUT -o lo -j ACCEPT
    iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
    
    # 配置端口
    read -p "请输入需要开放的TCP端口（用空格分隔，直接回车使用默认端口: 22 80 443 53 21）: " ports
    ports=${ports:-"22 80 443 53 21"}
    echo "开放端口: $ports"
    for port in $ports; do
        iptables -A INPUT -p tcp --dport $port -j ACCEPT
    done
    
    # DNS UDP
    echo "配置 DNS UDP..."
    iptables -A INPUT -p udp --dport 53 -j ACCEPT
    
    # ICMP
    echo "配置 ICMP..."
    iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
    
    # 允许所有出站
    iptables -A OUTPUT -j ACCEPT
}

# 启用IP转发
enable_ip_forward() {
    echo "启用 IP 转发..."
    sysctl -w net.ipv4.ip_forward=1
}

# 保存规则
save_rules() {
    echo "保存防火墙规则..."
    if [ -f /etc/debian_version ]; then
        apt-get install -y iptables-persistent
        mkdir -p /etc/iptables/
        iptables-save > /etc/iptables/rules.v4
    elif [ -f /etc/redhat-release ]; then
        service iptables save
    fi
}

# 重启Docker服务
restart_docker() {
    echo "重启 Docker 服务..."
    systemctl restart docker.service && docker network prune -f
}

# 主菜单
main_menu() {
    clear
    echo "=== iptables 配置工具 ==="
    echo "1. 默认允许(开发环境)"
    echo "2. 默认拒绝(生产环境)"
    echo "3. 清理所有规则"
    echo "4. 退出"
    echo "===================="
    read -p "请选择配置类型 [1-4]: " choice
    
    case $choice in
        1)
            clean_rules
            allow_all
            enable_ip_forward
            save_rules
            restart_docker
            echo "完成: 已配置默认允许策略"
            ;;
        2)
            clean_rules
            secure_rules
            enable_ip_forward
            save_rules
            restart_docker
            echo "完成: 已配置安全策略"
            ;;
        3)
            clean_rules
            echo "完成: 已清理所有规则"
            ;;
        4)
            echo "退出程序"
            exit 0
            ;;
        *)
            echo "无效选择"
            ;;
    esac
}

# 检查root权限
check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo "错误: 必须使用 root 权限运行此脚本"
        exit 1
    fi
}

# 启动程序
check_root
while true; do
    main_menu
    read -p "是否继续？[y/N] " continue_choice
    case $continue_choice in
        [yY])
            continue
            ;;
        *)
            echo "程序结束"
            exit 0
            ;;
    esac
done
