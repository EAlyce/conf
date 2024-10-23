#!/usr/bin/env bash

iptables -F
iptables -t nat -F
iptables -t mangle -F
iptables -X

# 设置默认策略，保持网络通畅
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT

# 允许所有流量进出
iptables -A INPUT -s 0.0.0.0/0 -j ACCEPT
iptables -A FORWARD -s 0.0.0.0/0 -j ACCEPT
iptables -A OUTPUT -s 0.0.0.0/0 -j ACCEPT

# 允许 Docker 网络流量
iptables -A INPUT -i docker0 -j ACCEPT
iptables -A FORWARD -i docker0 -o docker0 -j ACCEPT
iptables -A FORWARD -i docker0 ! -o docker0 -j ACCEPT
iptables -A FORWARD -o docker0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# NAT 转发，确保容器可以访问外网
iptables -t nat -A POSTROUTING -s 172.17.0.0/16 ! -o docker0 -j MASQUERADE

# 允许本地环回接口通信
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# 允许已经建立和相关的连接
iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# 允许 SSH (22)
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# 允许 HTTP (80) 和 HTTPS (443)
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT

# 允许 DNS (53) 流量 (TCP 和 UDP)
iptables -A INPUT -p udp --dport 53 -j ACCEPT
iptables -A INPUT -p tcp --dport 53 -j ACCEPT

# 允许 PING (ICMP)
iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
iptables -A OUTPUT -p icmp --icmp-type echo-reply -j ACCEPT

# 允许 FTP (21)
iptables -A INPUT -p tcp --dport 21 -j ACCEPT

# 启用 IP 转发功能
echo 1 > /proc/sys/net/ipv4/ip_forward
sysctl -w net.ipv4.ip_forward=1

# 持久化规则
if [ -f /etc/debian_version ]; then
    iptables-save > /etc/iptables/rules.v4
    apt-get install -y iptables-persistent
elif [ -f /etc/redhat-release ]; then
    service iptables save
fi

echo "iptables 配置已完成，常用服务和链保持畅通。"
