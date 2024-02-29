#!/bin/bash

# 检查用户是否为超级用户
if [ "$(id -u)" != "0" ]; then
   echo "此脚本必须以超级用户权限运行" 1>&2
   exit 1
fi

# 设置时区为UTC-8
ln -sf /usr/share/zoneinfo/America/Los_Angeles /etc/localtime

# 确保硬件时钟与系统时钟同步
hwclock --systohc

# 输出设置成功消息
echo "时区设置为UTC-8成功！"
