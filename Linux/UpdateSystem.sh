#!/bin/bash

# 更新系统包列表
sudo apt-get update -y

# 升级所有包，如果碰到询问默认回车
sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"

# 清理apt缓存
sudo apt-get autoremove -y
sudo apt-get clean

# 清理旧的系统日志
sudo find /var/log -type f -name '*.log.*' -delete
sudo find /var/log -type f -name '*.gz' -delete

# 清理回收站
rm -rf ~/.local/share/Trash/files/*

# 其他清理操作可以在此添加

echo "清理和更新完成: $(date)" >> /var/log/clean-system.log