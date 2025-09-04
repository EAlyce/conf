#!/bin/bash

# SSH紧急修复脚本 - VNC专用
# 一键修复SSH配置，允许密码和密钥登录

echo "🔧 紧急修复SSH配置..."

# 备份原配置
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.emergency.bak

# 修复SSH配置
sed -i 's/#*Port.*/Port 22/' /etc/ssh/sshd_config
sed -i 's/#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/#*MaxAuthTries.*/MaxAuthTries 0/' /etc/ssh/sshd_config
sed -i 's/#*MaxSessions.*/MaxSessions 0/' /etc/ssh/sshd_config
sed -i 's/#*MaxStartups.*/MaxStartups 1000/' /etc/ssh/sshd_config

# 验证并重启SSH
if sshd -t; then
    systemctl restart sshd
    echo "✅ SSH修复完成"
    echo "端口: 22"
    echo "Root登录: 已启用"
    echo "密码认证: 已启用"
    echo "密钥认证: 已启用"
    echo "现在可以用密码或密钥登录了"
else
    echo "❌ 配置验证失败，恢复备份"
    cp /etc/ssh/sshd_config.emergency.bak /etc/ssh/sshd_config
    systemctl restart sshd
fi
