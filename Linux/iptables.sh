#!/usr/bin/env bash
#!/usr/bin/env bash

# 清理规则
iptables -F
iptables -t nat -F
iptables -t mangle -F
iptables -X

# 设置默认允许
for chain in INPUT FORWARD OUTPUT; do
    iptables -P $chain ACCEPT
done

# 仅需要的 Docker NAT 规则
iptables -t nat -A POSTROUTING -s 172.17.0.0/16 ! -o docker0 -j MASQUERADE

# 启用 IP 转发
sysctl -w net.ipv4.ip_forward=1

# 保存规则
if [ -f /etc/debian_version ]; then
    apt-get install -y iptables-persistent
    mkdir -p /etc/iptables/
    iptables-save > /etc/iptables/rules.v4
elif [ -f /etc/redhat-release ]; then
    service iptables save
fi

systemctl restart docker.service && docker network prune -f

echo "iptables 配置已完成 - 默认允许所有流量"
