#!/usr/bin/env bash

# 清空所有现有规则和链
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X

# 创建 DOCKER 链（如果不存在）
iptables -t nat -N DOCKER 2>/dev/null || true
iptables -t nat -A DOCKER -j RETURN

# 允许所有流量的默认策略
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT

# 允许本地回环接口流量
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# 允许已建立和相关的连接流量
iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# 清理其他常见链（如果需要）
# 注释掉这些链的清理，如果不需要
iptables -t nat -F  # 清空 NAT 链
iptables -t mangle -F  # 清空 MANGLE 链
iptables -X  # 清空所有用户自定义链

# 打印当前规则
iptables -L -n -v

# 打印规则总结
echo "iptables 规则已成功重置并更新。"
