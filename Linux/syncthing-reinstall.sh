#!/bin/bash

set -e

echo "停止并禁用旧的 syncthing 服务..."
sudo systemctl stop syncthing@root.service || true
sudo systemctl disable syncthing@root.service || true

echo "删除旧的 syncthing 程序和配置..."
sudo rm -f /usr/local/bin/syncthing
rm -rf /root/.config/syncthing

echo "下载最新 syncthing (arm64)..."
curl -LO https://github.com/syncthing/syncthing/releases/latest/download/syncthing-linux-arm64-v1.30.0.tar.gz

echo "解压并安装..."
tar -xzf syncthing-linux-arm64-v1.30.0.tar.gz
sudo mv syncthing-linux-arm64-v1.30.0/syncthing /usr/local/bin/
sudo chmod +x /usr/local/bin/syncthing
rm -rf syncthing-linux-arm64-v1.30.0*
 
echo "生成配置文件..."
sudo -u root /usr/local/bin/syncthing -home="/root/.config/syncthing" -generate

echo "修改配置，允许所有地址访问Web界面..."
sed -i 's|<address>127.0.0.1:8384</address>|<address>0.0.0.0:8384</address>|' /root/.config/syncthing/config.xml

echo "写入 systemd 服务文件..."
sudo tee /etc/systemd/system/syncthing@.service > /dev/null <<EOF
[Unit]
Description=Syncthing - Open Source Continuous File Synchronization for %i
Documentation=man:syncthing(1)
After=network.target

[Service]
User=%i
ExecStart=/usr/local/bin/syncthing --no-browser --no-restart --logflags=0 -home=/root/.config/syncthing
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

echo "重新加载 systemd 配置，启用并启动服务..."
sudo systemctl daemon-reload
sudo systemctl enable syncthing@root.service
sudo systemctl start syncthing@root.service

echo "状态如下："
sudo systemctl status syncthing@root.service --no-pager

echo "完成！"
