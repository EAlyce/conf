#!/bin/bash

# 输入新的SSH端口号
read -p "请输入新的SSH端口号: " new_port

# 验证输入的端口号是否有效
if [[ ! "$new_port" =~ ^[0-9]+$ ]] || [ "$new_port" -le 1023 ] || [ "$new_port" -ge 65535 ]; then
  echo "端口号必须是1024到65535之间的整数"
  exit 1
fi

# 备份当前的SSH配置文件
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

# 修改SSH配置文件以使用新的端口号
sed -i "s/^#Port 22/Port $new_port/" /etc/ssh/sshd_config

# 重启SSH服务以应用新的端口号
systemctl restart sshd

echo "SSH端口已更改为$new_port"
