#!/usr/bin/env bash

# 清理现有规则
iptables -F
iptables -t nat -F
iptables -t mangle -F
iptables -X

# 设置默认策略
for chain in INPUT FORWARD OUTPUT; do
    iptables -P $chain ACCEPT
done

# Docker 相关规则
iptables -A INPUT -i docker0 -j ACCEPT
iptables -A FORWARD -i docker0 -o docker0 -j ACCEPT
iptables -A FORWARD -i docker0 ! -o docker0 -j ACCEPT
iptables -A FORWARD -o docker0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -t nat -A POSTROUTING -s 172.17.0.0/16 ! -o docker0 -j MASQUERADE

# 允许本地环回和已建立连接
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# 开放常用端口（TCP）
for port in 22 80 443 53 21; do
    iptables -A INPUT -p tcp --dport $port -j ACCEPT
    # 为服务添加出站规则
    iptables -A OUTPUT -p tcp --sport $port -j ACCEPT
done

# 开放 UDP 端口
iptables -A INPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p udp --sport 53 -j ACCEPT

# ICMP 规则
iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
iptables -A OUTPUT -p icmp --icmp-type echo-reply -j ACCEPT

# FTP 被动模式端口范围（如果需要）
iptables -A INPUT -p tcp --dport 21 -j ACCEPT
iptables -A INPUT -p tcp --dport 1024:65535 -j ACCEPT

# 启用 IP 转发
sysctl -w net.ipv4.ip_forward=1

# 保存规则（基于系统类型）
if [ -f /etc/debian_version ]; then
    apt-get install -y iptables-persistent
    mkdir -p /etc/iptables/
    iptables-save > /etc/iptables/rules.v4
elif [ -f /etc/redhat-release ]; then
    service iptables save
fi

# 重启 Docker 服务
systemctl restart docker.service && docker network prune -f

echo "iptables 配置已完成，常用服务和链保持畅通。"
