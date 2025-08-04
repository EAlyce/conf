#!/bin/bash

set -e

# 配置变量
SERVICE_NAME="syncthing-root"
SERVICE_PATH="/etc/systemd/system/${SERVICE_NAME}.service"
USER_HOME="/root"
BIN_DIR="${USER_HOME}/bin"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

echo "🔧 修复 Syncthing 服务配置"
echo "=========================="

# 1. 停止现有服务
log_info "停止现有服务..."
systemctl stop $SERVICE_NAME 2>/dev/null || true
systemctl disable $SERVICE_NAME 2>/dev/null || true

# 2. 杀死可能残留的进程
log_info "清理残留进程..."
pkill -f syncthing || true
sleep 2

# 3. 检查程序文件
log_info "检查程序文件..."
if [[ ! -f "$BIN_DIR/syncthing" ]]; then
    log_error "Syncthing 程序文件不存在: $BIN_DIR/syncthing"
    exit 1
fi

# 4. 手动测试程序
log_info "测试程序运行..."
if ! timeout 5s "$BIN_DIR/syncthing" --version >/dev/null 2>&1; then
    log_error "程序无法正常运行"
    exit 1
fi
log_success "程序测试通过"

# 5. 创建修复后的服务文件
log_info "创建修复后的服务文件..."
cat > "$SERVICE_PATH" << 'EOF'
[Unit]
Description=Syncthing - Open Source Continuous File Synchronization (Root)
Documentation=man:syncthing(1)
After=network.target
Wants=network.target
StartLimitIntervalSec=60
StartLimitBurst=4

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=/root
ExecStart=/root/bin/syncthing serve --no-browser --no-restart --logflags=0
Restart=on-failure
RestartSec=5
KillMode=mixed
SuccessExitStatus=3 4
RestartForceExitStatus=3 4
TimeoutStartSec=60
TimeoutStopSec=20

# 环境变量
Environment=HOME=/root
Environment=USER=root
Environment=STNORESTART=1
Environment=STNOUPGRADE=1

# 安全设置
PrivateTmp=true
ProtectKernelTunables=false
ProtectControlGroups=false
RestrictRealtime=false
NoNewPrivileges=false

[Install]
WantedBy=multi-user.target
EOF

chmod 644 "$SERVICE_PATH"
log_success "服务文件已更新"

# 6. 重新加载 systemd
log_info "重新加载 systemd 配置..."
systemctl daemon-reload

# 7. 启用并启动服务
log_info "启用服务..."
systemctl enable $SERVICE_NAME.service

log_info "启动服务..."
if systemctl start $SERVICE_NAME.service; then
    log_success "服务启动成功"
else
    log_error "服务启动失败，查看详细状态："
    systemctl status $SERVICE_NAME.service --no-pager -l
    echo ""
    log_info "查看日志："
    journalctl -u $SERVICE_NAME --no-pager -n 20
    echo ""
    log_info "尝试手动启动进行诊断："
    echo "$BIN_DIR/syncthing serve --no-browser --no-restart --logflags=0"
    exit 1
fi

# 8. 等待服务启动
log_info "等待服务完全启动..."
sleep 5

# 9. 验证服务状态
log_info "验证服务状态..."
if systemctl is-active --quiet $SERVICE_NAME.service; then
    log_success "✅ 服务运行正常"
else
    log_error "❌ 服务未正常运行"
    systemctl status $SERVICE_NAME.service --no-pager -l
    exit 1
fi

# 10. 检查端口监听
log_info "检查端口监听..."
for i in {1..10}; do
    if netstat -tlnp 2>/dev/null | grep -q ":8384"; then
        log_success "✅ 端口 8384 已监听"
        break
    else
        if [[ $i -eq 10 ]]; then
            log_warning "⚠️  端口 8384 未监听，可能还在启动中"
        else
            sleep 1
        fi
    fi
done

# 11. 测试 Web UI 访问
log_info "测试 Web UI 访问..."
for i in {1..10}; do
    if curl -s --connect-timeout 3 http://localhost:8384 >/dev/null 2>&1; then
        log_success "✅ Web UI 可访问"
        break
    else
        if [[ $i -eq 10 ]]; then
            log_warning "⚠️  Web UI 暂时无法访问，可能还在启动中"
        else
            sleep 1
        fi
    fi
done

# 12. 显示完成信息
echo ""
echo "🎉 Syncthing 服务修复完成！"
echo "=========================="
echo ""
echo "📊 服务状态："
systemctl status $SERVICE_NAME --no-pager -l
echo ""
echo "🌐 Web UI 访问："
SERVER_IP=$(hostname -I | awk '{print $1}' | head -1)
echo "   本地: http://localhost:8384"
echo "   远程: http://$SERVER_IP:8384"
echo ""
echo "🔧 常用命令："
echo "   查看状态: systemctl status $SERVICE_NAME"
echo "   查看日志: journalctl -u $SERVICE_NAME -f"
echo "   重启服务: systemctl restart $SERVICE_NAME"
echo "   停止服务: systemctl stop $SERVICE_NAME"
echo ""
echo "📝 注意："
echo "   如果 Web UI 无法访问，请稍等片刻或查看日志"
echo "   首次访问需要设置管理员用户名和密码"
