#!/bin/bash
set -e

# 配置变量
USER_NAME="root"
USER_HOME="/root"
BIN_DIR="${USER_HOME}/bin"
CONFIG_DIR="${USER_HOME}/.config/syncthing"
DATA_DIR="${USER_HOME}/Sync"
SERVICE_NAME="syncthing-root"
SERVICE_PATH="/etc/systemd/system/${SERVICE_NAME}.service"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

echo "🚀 Syncthing 自动安装脚本 - Root 用户专版"
echo "=================================================="

# 1. 完整清理所有可能存在的 Syncthing 相关内容
log_info "开始完整清理..."

# 停止所有可能的服务
SERVICES=("syncthing" "syncthing@root" "syncthing-root" "syncthing@$USER_NAME")
for service in "${SERVICES[@]}"; do
    if systemctl is-active --quiet "$service" 2>/dev/null; then
        log_warning "停止服务: $service"
        systemctl stop "$service" 2>/dev/null || true
    fi
    if systemctl is-enabled --quiet "$service" 2>/dev/null; then
        log_warning "禁用服务: $service"
        systemctl disable "$service" 2>/dev/null || true
    fi
done

# 删除所有可能的服务文件
SERVICE_FILES=(
    "/etc/systemd/system/syncthing.service"
    "/etc/systemd/system/syncthing@.service"
    "/etc/systemd/system/syncthing@root.service"
    "/etc/systemd/system/syncthing-root.service"
    "/lib/systemd/system/syncthing.service"
    "/lib/systemd/system/syncthing@.service"
)

for file in "${SERVICE_FILES[@]}"; do
    if [[ -f "$file" ]]; then
        log_warning "删除服务文件: $file"
        rm -f "$file"
    fi
done

# 清理程序文件
PROGRAM_LOCATIONS=(
    "/usr/local/bin/syncthing"
    "/usr/bin/syncthing"
    "/bin/syncthing"
    "${BIN_DIR}/syncthing"
    "/opt/syncthing/syncthing"
)

for prog in "${PROGRAM_LOCATIONS[@]}"; do
    if [[ -f "$prog" ]]; then
        log_warning "删除程序文件: $prog"
        rm -f "$prog"
    fi
done

# 清理配置（保留数据目录）
if [[ -d "$CONFIG_DIR" ]]; then
    log_warning "删除配置目录: $CONFIG_DIR"
    rm -rf "$CONFIG_DIR"
fi

# 清理临时文件
rm -rf /tmp/syncthing-linux-arm64*

# 重新加载 systemd
systemctl daemon-reload
log_success "完整清理完成"

# 2. 检测系统架构
log_info "检测系统架构..."
ARCH=$(uname -m)
case $ARCH in
    x86_64)
        SYNCTHING_ARCH="amd64"
        ;;
    aarch64|arm64)
        SYNCTHING_ARCH="arm64"
        ;;
    armv7l)
        SYNCTHING_ARCH="arm"
        ;;
    *)
        log_error "不支持的系统架构: $ARCH"
        exit 1
        ;;
esac
log_success "检测到架构: $ARCH -> syncthing-$SYNCTHING_ARCH"

# 3. 创建目录结构
log_info "创建目录结构..."
mkdir -p "$BIN_DIR"
mkdir -p "$CONFIG_DIR"
mkdir -p "$DATA_DIR"
log_success "目录创建完成"

# 4. 下载最新版本
log_info "获取最新版本信息..."
cd /tmp

# 获取最新版本号
LATEST_VERSION=$(curl -s https://api.github.com/repos/syncthing/syncthing/releases/latest | grep -o '"tag_name": "[^"]*' | cut -d'"' -f4)

if [[ -z "$LATEST_VERSION" ]]; then
    log_error "无法获取最新版本信息"
    exit 1
fi

log_success "最新版本: $LATEST_VERSION"

# 下载并解压
DOWNLOAD_URL="https://github.com/syncthing/syncthing/releases/latest/download/syncthing-linux-${SYNCTHING_ARCH}-${LATEST_VERSION}.tar.gz"
log_info "下载: $DOWNLOAD_URL"

if ! curl -LO "$DOWNLOAD_URL"; then
    log_error "下载失败"
    exit 1
fi

if ! tar -xzf "syncthing-linux-${SYNCTHING_ARCH}-${LATEST_VERSION}.tar.gz"; then
    log_error "解压失败"
    exit 1
fi

# 5. 安装程序
log_info "安装 Syncthing..."
cp syncthing-linux-${SYNCTHING_ARCH}*/syncthing "$BIN_DIR/"
chmod +x "$BIN_DIR/syncthing"

# 验证安装
if ! "$BIN_DIR/syncthing" --version >/dev/null 2>&1; then
    log_error "程序安装验证失败"
    exit 1
fi

VERSION_INFO=$("$BIN_DIR/syncthing" --version | head -1)
log_success "程序安装成功: $VERSION_INFO"

# 6. 配置 PATH
log_info "配置环境变量..."
if ! grep -q "export PATH=\"$BIN_DIR:\$PATH\"" "$USER_HOME/.bashrc" 2>/dev/null; then
    echo "# Syncthing PATH" >> "$USER_HOME/.bashrc"
    echo "export PATH=\"$BIN_DIR:\$PATH\"" >> "$USER_HOME/.bashrc"
    log_success "已添加到 PATH"
else
    log_info "PATH 已存在，跳过"
fi

# 7. 生成初始配置
log_info "生成初始配置..."
"$BIN_DIR/syncthing" --generate "$CONFIG_DIR"

# 修改 Web UI 监听地址
log_info "配置 Web UI 监听地址..."
sed -i 's|<address>127.0.0.1:8384</address>|<address>0.0.0.0:8384</address>|' "$CONFIG_DIR/config.xml"

# 添加默认同步目录
log_info "配置默认同步目录..."
sed -i "s|<folder id=\"default\" label=\"Default Folder\" path=\"[^\"]*\"|<folder id=\"default\" label=\"Default Folder\" path=\"$DATA_DIR\"|" "$CONFIG_DIR/config.xml"

log_success "配置完成"

# 8. 创建 systemd 服务
log_info "创建系统服务..."
cat <<EOF > "$SERVICE_PATH"
[Unit]
Description=Syncthing - Open Source Continuous File Synchronization (Root)
Documentation=man:syncthing(1)
After=network.target
StartLimitIntervalSec=60
StartLimitBurst=4

[Service]
Type=notify
User=root
Group=root
WorkingDirectory=$USER_HOME
ExecStart=$BIN_DIR/syncthing -no-browser -no-restart -logflags=0
Restart=on-failure
RestartSec=10
SuccessExitStatus=3 4
RestartForceExitStatus=3 4

# 环境变量
Environment=HOME=$USER_HOME
Environment=USER=root
Environment=STNORESTART=1

# 安全设置（适用于 root）
PrivateTmp=true
ProtectKernelTunables=true
ProtectControlGroups=true
RestrictRealtime=true

[Install]
WantedBy=multi-user.target
EOF

chmod 644 "$SERVICE_PATH"
log_success "服务文件创建完成"

# 9. 启动服务
log_info "启动 Syncthing 服务..."
systemctl daemon-reload
systemctl enable "$SERVICE_NAME.service"

if systemctl start "$SERVICE_NAME.service"; then
    log_success "服务启动成功"
else
    log_error "服务启动失败"
    systemctl status "$SERVICE_NAME.service" --no-pager -l
    exit 1
fi

# 10. 等待服务完全启动
log_info "等待服务完全启动..."
for i in {1..30}; do
    if systemctl is-active --quiet "$SERVICE_NAME.service" && curl -s http://localhost:8384 >/dev/null 2>&1; then
        break
    fi
    sleep 1
    echo -n "."
done
echo ""

# 11. 验证安装
log_info "验证安装..."
if systemctl is-active --quiet "$SERVICE_NAME.service"; then
    log_success "✅ 服务运行正常"
else
    log_error "❌ 服务未正常运行"
    systemctl status "$SERVICE_NAME.service" --no-pager -l
    exit 1
fi

if curl -s http://localhost:8384 >/dev/null 2>&1; then
    log_success "✅ Web UI 可访问"
else
    log_warning "⚠️  Web UI 可能还在启动中"
fi

# 12. 清理临时文件
log_info "清理临时文件..."
rm -rf /tmp/syncthing-linux-${SYNCTHING_ARCH}*
log_success "清理完成"

# 13. 显示安装信息
echo ""
echo "🎉 Syncthing 安装完成！"
echo "=================================================="
echo ""
echo "📍 安装信息："
echo "   版本: $LATEST_VERSION"
echo "   架构: $SYNCTHING_ARCH"
echo "   程序: $BIN_DIR/syncthing"
echo "   配置: $CONFIG_DIR"
echo "   数据: $DATA_DIR"
echo "   服务: $SERVICE_NAME.service"
echo ""
echo "🌐 Web UI 访问："
SERVER_IP=$(hostname -I | awk '{print $1}' | head -1)
echo "   本地: http://localhost:8384"
echo "   远程: http://$SERVER_IP:8384"
echo ""
echo "🔧 常用命令："
echo "   启动: systemctl start $SERVICE_NAME"
echo "   停止: systemctl stop $SERVICE_NAME"
echo "   重启: systemctl restart $SERVICE_NAME"
echo "   状态: systemctl status $SERVICE_NAME"
echo "   日志: journalctl -u $SERVICE_NAME -f"
echo "   直接运行: $BIN_DIR/syncthing"
echo ""
echo "📝 注意事项："
echo "   1. 重新登录终端或执行 'source ~/.bashrc' 以使用 syncthing 命令"
echo "   2. 首次访问 Web UI 需要设置管理员密码"
echo "   3. 默认同步目录: $DATA_DIR"
echo "   4. 可以安全地多次运行此脚本进行重新安装"
echo ""
echo "🚀 安装完成，开始使用 Syncthing 吧！"
