#!/usr/bin/env bash
set -euo pipefail

# ==== 配置参数 ====
YTPROXY_USER="ytproxy"
RT_TABLE_NAME="warp"
RT_TABLE_ID=200
MARK=0x1
SETUP_SCRIPT="/usr/local/bin/yt-warp-setup.sh"
SERVICE_FILE="/etc/systemd/system/yt-warp-routing.service"

# ==== 创建 ytproxy 用户（如果不存在） ====
if ! id -u "$YTPROXY_USER" >/dev/null 2>&1; then
    useradd -m -s /bin/bash "$YTPROXY_USER"
    echo "用户 $YTPROXY_USER 已创建 (home: /home/$YTPROXY_USER)"
else
    echo "用户 $YTPROXY_USER 已存在"
fi
YTPROXY_UID=$(id -u "$YTPROXY_USER")

# ==== 自动检测 WARP/WireGuard 接口 ====
warp_iface=$(ip -o link show type wireguard 2>/dev/null | awk -F': ' '{print $2}' | head -n1 || true)
if [ -z "$warp_iface" ]; then
    warp_iface=$(ip -o link show | awk -F': ' '/wg|warp/ {print $2; exit}' || true)
fi
if [ -z "$warp_iface" ]; then
    echo "⚠️ 无法自动检测到 WARP/WireGuard 接口，请手动指定 warp_iface"
    exit 1
fi
echo "检测到 WARP 接口: $warp_iface"

# ==== 创建 rt_tables 文件（如果不存在） ====
mkdir -p /etc/iproute2
if [ ! -s /etc/iproute2/rt_tables ]; then
    cat > /etc/iproute2/rt_tables <<'EOF'
#
# reserved values
#
255     local
254     main
253     default
0       unspec
EOF
fi
grep -qE "^\s*${RT_TABLE_ID}\s+${RT_TABLE_NAME}\s*$" /etc/iproute2/rt_tables || echo "${RT_TABLE_ID} ${RT_TABLE_NAME}" >> /etc/iproute2/rt_tables

# ==== 创建 yt-warp-setup.sh ====
cat > "$SETUP_SCRIPT" <<EOF
#!/usr/bin/env bash
set -euo pipefail

YTPROXY_UID=$YTPROXY_UID
RT_TABLE_NAME=$RT_TABLE_NAME
WARP_IFACE=$warp_iface
MARK=$MARK
RT_TABLE_ID=$RT_TABLE_ID

# 路由表
grep -qE "^\\s*\${RT_TABLE_ID}\\s+\${RT_TABLE_NAME}\\s*\$" /etc/iproute2/rt_tables || echo "\${RT_TABLE_ID} \${RT_TABLE_NAME}" >> /etc/iproute2/rt_tables

# 默认路由到 WARP
ip route replace default dev "\$WARP_IFACE" table "\$RT_TABLE_NAME"

# 强制 SSH 22端口直连
ip rule add sport 22 lookup main pref 50 2>/dev/null || true
ip rule add dport 22 lookup main pref 51 2>/dev/null || true

# fwmark 流量走 WARP
ip rule add fwmark \$MARK table "\$RT_TABLE_NAME" pref 100 2>/dev/null || true

# iptables 标记
iptables -t mangle -C OUTPUT -m owner --uid-owner "\$YTPROXY_UID" -j MARK --set-mark \$MARK 2>/dev/null || \
iptables -t mangle -A OUTPUT -m owner --uid-owner "\$YTPROXY_UID" -j MARK --set-mark \$MARK

# 关闭 rp_filter 避免反向路由问题
sysctl -w net.ipv4.conf.all.rp_filter=0 >/dev/null || true
sysctl -w net.ipv4.conf.default.rp_filter=0 >/dev/null || true
EOF

chmod +x "$SETUP_SCRIPT"

# ==== 创建 systemd service ====
cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=yt-dlp WARP routing setup
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=$SETUP_SCRIPT
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# ==== 启用服务 ====
systemctl daemon-reload
systemctl enable --now yt-warp-routing.service

echo
echo "✅ 完成：ytproxy 用户流量走 WARP，SSH 22 端口直连保持正常"
echo "测试 ytproxy 用户 IP： sudo -u ytproxy -H curl -s ifconfig.me"
echo "运行 yt-dlp： sudo -u ytproxy -H yt-dlp <URL>"
