#!/bin/bash

set -e

USER_NAME="root"
USER_HOME="/root"
BIN_DIR="/usr/local/bin"
CONFIG_DIR="${USER_HOME}/.config/syncthing"
SERVICE_PATH="/etc/systemd/system/syncthing@.service"

echo "🧹 停止并禁用旧服务..."
systemctl stop syncthing@"$USER_NAME".service 2>/dev/null || true
systemctl disable syncthing@"$USER_NAME".service 2>/dev/null || true

echo "🗑 删除旧的程序与配置（保留数据目录）..."
rm -f "${BIN_DIR}/syncthing"
rm -rf "${CONFIG_DIR}"

echo "⬇️ 下载最新 Syncthing（arm64）..."
cd /tmp
curl -LO https://github.com/syncthing/syncthing/releases/latest/download/syncthing-linux-arm64-v1.30.0.tar.gz
tar -xzf syncthing-linux-arm64-v1.30.0.tar.gz
cp syncthing-linux-arm64*/syncthing "${BIN_DIR}/"
chmod +x "${BIN_DIR}/syncthing"

echo "⚙️ 生成配置文件..."
sudo -u "$USER_NAME" "${BIN_DIR}/syncthing" --generate "${CONFIG_DIR}"

echo "🌐 修改 Web UI 监听地址为 0.0.0.0:8384..."
sed -i 's|<address>127.0.0.1:8384</address>|<address>0.0.0.0:8384</address>|' "${CONFIG_DIR}/config.xml"

echo "🛠️ 写入 systemd 服务文件..."
cat <<EOF > "$SERVICE_PATH"
[Unit]
Description=Syncthing - Open Source Continuous File Synchronization for %%i
Documentation=man:syncthing(1)
After=network.target

[Service]
User=%%i
ExecStart=${BIN_DIR}/syncthing -no-browser -no-restart -logflags=0 -home=${USER_HOME}/.config/syncthing
Restart=on-failure
SuccessExitStatus=3 4
RestartForceExitStatus=3 4
ProtectSystem=full
ProtectHome=true
PrivateTmp=true
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF

echo "✅ 重新加载 systemd，启动 Syncthing..."
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable syncthing@"$USER_NAME".service
systemctl start syncthing@"$USER_NAME".service
sleep 2
systemctl status syncthing@"$USER_NAME".service --no-pager

echo ""
echo "🎉 Syncthing 已安装并运行！你可以通过以下地址访问 Web UI："
echo "👉 http://<服务器IP>:8384"
