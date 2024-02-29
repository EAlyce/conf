#!/bin/bash
echo "正在禁用 IPv6..."
echo "net.ipv6.conf.all.disable_ipv6 = 1" | sudo tee -a /etc/sysctl.conf
echo "net.ipv6.conf.default.disable_ipv6 = 1" | sudo tee -a /etc/sysctl.conf
echo "net.ipv6.conf.lo.disable_ipv6 = 1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

ipv6_status=$(cat /proc/sys/net/ipv6/conf/all/disable_ipv6)

if [ "$ipv6_status" -eq 1 ]; then
  echo "IPv6 已禁用"
else
  echo "IPv6 未禁用"
fi

ipv4_status=$(ip -4 addr show | grep inet)

if [ -z "$ipv4_status" ]; then
  echo "IPv4 未启用"
else
  echo "IPv4 已启用"
fi
