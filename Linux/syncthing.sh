#!/bin/bash
# install_syncthing.sh
# 一键安装、初始化 Syncthing，无密码 Web UI，可公网访问

set -e

echo "🧹 停止旧进程和服务..."
systemctl stop syncthing* >/dev/null 2>&1 || true
systemctl disable syncthing* >/dev/null 2>&1 || true
pkill -9 syncthing >/dev/null 2>&1 || true

echo "🧹 删除旧配置和同步目录..."
rm -rf /root/.local/state/syncthing
rm -rf /root/.config/syncthing
rm -rf /root/Sync
mkdir -p /root/.local/state/syncthing
mkdir -p /root/Sync

echo "🧹 卸载旧版本..."
apt remove --purge -y syncthing
apt autoremove -y

echo "🧹 安装最新 Syncthing..."
apt update -y
apt install -y syncthing

echo "🧹 生成默认配置 (GUI 无密码，监听公网)..."
cat > /root/.local/state/syncthing/config.xml <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<configuration version="37">
    <gui enabled="true" tls="false" debugging="false">
        <address>0.0.0.0:8384</address>
    </gui>
    <folders>
        <folder id="default" label="Default Folder" path="/root/Sync" type="sendreceive">
        </folder>
    </folders>
</configuration>
EOF

echo "🧹 放行防火墙端口 8384..."
iptables -C INPUT -p tcp --dport 8384 -j ACCEPT >/dev/null 2>&1 || iptables -I INPUT -p tcp --dport 8384 -j ACCEPT

echo "🧹 创建 systemd 服务..."
cat > /etc/systemd/system/syncthing-root.service <<EOF
[Unit]
Description=Syncthing - File Synchronization for root
After=network.target

[Service]
User=root
ExecStart=/usr/bin/syncthing -no-browser -no-restart
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable syncthing-root.service

echo "🧹 启动 Syncthing 服务..."
systemctl start syncthing-root.service

echo "⏳ 等待服务监听 8384 端口..."
while ! systemctl is-active --quiet syncthing-root.service || ! ss -tlnp | grep -q ":8384"; do
    sleep 1
    echo -n "."
done
echo ""
EXTERNAL_IP=$(curl -s ifconfig.me 2>/dev/null || echo "YOUR_IP")
echo "✅ 安装完成！"
echo "🌐 Web UI 地址: http://${EXTERNAL_IP}:8384 (无用户名密码)"
