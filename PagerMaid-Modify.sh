#!/bin/bash
# ============================================================================
# PagerMaid-Modify 简化安装脚本 - Debian专用
# 功能：使用官方配置模板，只替换API信息
# ============================================================================

set -euo pipefail

# 基础配置
PROJECT_DIR="/opt/PagerMaid-Modify"
SERVICE_NAME="pagermaid-modify"
REPO_URL="https://github.com/TeamPGM/PagerMaid-Modify.git"

# 颜色
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info() { echo -e "${GREEN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# 检查权限
[[ $EUID -eq 0 ]] || error "需要root权限运行"

# 检查系统
command -v apt >/dev/null 2>&1 || error "仅支持Debian/Ubuntu系统"

# 更新系统
info "更新系统并安装依赖..."
export DEBIAN_FRONTEND=noninteractive
apt update -y && apt upgrade -y

# 安装依赖
apt install -y git curl wget python3 python3-pip python3-venv \
               build-essential libffi-dev libssl-dev \
               ffmpeg imagemagick tesseract-ocr || true

# 清理并创建目录
info "准备项目目录..."
rm -rf "$PROJECT_DIR"
mkdir -p "$PROJECT_DIR"

# 克隆仓库
info "获取源码..."
git clone "$REPO_URL" "$PROJECT_DIR" || error "克隆仓库失败"
cd "$PROJECT_DIR"

# 设置Python环境
info "设置Python环境..."
if python3 -c "import sys; sys.exit(0 if sys.version_info >= (3,11) else 1)" 2>/dev/null; then
    # 使用虚拟环境
    python3 -m venv venv
    source venv/bin/activate
    pip install --upgrade pip
    pip install -r requirements.txt
    PYTHON_CMD="$PROJECT_DIR/venv/bin/python"
else
    # 系统Python
    pip3 install --break-system-packages --upgrade pip
    pip3 install --break-system-packages -r requirements.txt
    PYTHON_CMD="python3"
fi

# 获取用户输入
info "请输入Telegram API信息..."
read -rp "API ID: " api_id
read -rp "API Hash: " api_hash

# 验证输入
[[ "$api_id" =~ ^[0-9]+$ ]] || error "API ID必须是数字"
[[ -n "$api_hash" ]] || error "API Hash不能为空"

# 创建必要目录
mkdir -p data/plugins data/cache logs

# 使用官方配置模板，只替换API信息
info "生成配置文件..."
cat > config.yml <<'EOF'
# ===================================================================
# __________                                _____         .__    .___
# \______   \_____     ____   ___________  /     \ _____  |__| __| _|
# |     ___/\__  \   / ___\_/ __ \_  ** \/  \ /  \\**  \ |  |/ __ |
# |    |     / __ \_/ /_/  >  ___/|  | \/    Y    \/ __ \|  / /_/ |
# |____|    (____  /\___  / \___  >__|  \____|__  (____  /__\____ |
#                \//_____/      \/              \/     \/        \/
# ===================================================================
# API Credentials of your telegram application created at https://my.telegram.org/apps
api_id: "ID_PLACEHOLDER"
api_hash: "HASH_PLACEHOLDER"
qrcode_login: "False"
web_login: "False"
# Either debug logging is enabled or not
debug: "False"
error_report: "True"
# Admin interface related
web_interface:
  enable: "False"
  secret_key: "RANDOM_STRING_HERE"
  host: "127.0.0.1"
  port: "3333"
  origins: ["*"]
# Locale settings
application_language: "zh-cn"
application_region: "China"
application_tts: "zh-CN"
timezone: "Asia/Shanghai"
# In-Chat logging settings, default settings logs directly into Kat, strongly advised to change
log: "False"
# chat id of the log group, such as -1001234567890, also can use username, such as "telegram"
log_chatid: "me"
# Disabled Built-in Commands
disabled_cmd:
  - example1
  - example2
# Google search preferences
result_length: "5"
# TopCloud image output preferences
width: "1920"
height: "1080"
background: "#101010"
margin: "20"
# socks5 or http or MTProto
proxy_addr: ""
proxy_port: ""
http_addr: ""
http_port: ""
mtp_addr: ""
mtp_port: ""
mtp_secret: ""
# Apt Git source
git_source: "https://v1.xtaolabs.com/"
git_ssh: "https://github.com/TeamPGM/PagerMaid-Modify.git"
# Update Notice
update_check: "True"
update_time: "86400"
update_username: "PagerMaid_Modify_bot"
update_delete: "True"
# ipv6
ipv6: "False"
# Analytics
allow_analytic: "True"
sentry_api: ""
mixpanel_api: ""
# Speed_test cli path
speed_test_path: ""
# Time format https://www.runoob.com/python/att-time-strftime.html
# 24 default
time_form: "%H:%M"
date_form: "%A %y/%m/%d"
# only support %m %d %H %M %S
start_form: "%m/%d %H:%M"
# Silent to reduce editing times
silent: "True"
# Eval use pb or not
use_pb: "True"
EOF

# 替换API信息
sed -i "s/ID_PLACEHOLDER/$api_id/g" config.yml
sed -i "s/HASH_PLACEHOLDER/$api_hash/g" config.yml

# 生成随机密钥
RANDOM_KEY=$(openssl rand -hex 16 2>/dev/null || echo "pagermaid_$(date +%s)")
sed -i "s/RANDOM_STRING_HERE/$RANDOM_KEY/g" config.yml

info "配置文件已生成"

# 安装服务
info "安装systemd服务..."
cat > "/etc/systemd/system/$SERVICE_NAME.service" <<EOF
[Unit]
Description=PagerMaid-Modify
After=network.target

[Service]
Type=simple
WorkingDirectory=$PROJECT_DIR
ExecStart=$PYTHON_CMD -m pagermaid
Restart=always
RestartSec=10
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable "$SERVICE_NAME"

# 直接登录
info "开始登录Telegram..."
if ls pagermaid*.session* >/dev/null 2>&1; then
    info "检测到会话文件，启动服务..."
    systemctl start "$SERVICE_NAME"
else
    info "首次登录，请按提示操作..."
    $PYTHON_CMD -m pagermaid
    echo -e "\n${GREEN}登录完成！启动后台服务...${NC}"
    systemctl start "$SERVICE_NAME"
fi

# 显示结果
echo -e "\n${GREEN}=== 安装完成 ===${NC}"
echo "项目目录: $PROJECT_DIR"
echo "配置文件: $PROJECT_DIR/config.yml"
echo "服务控制: systemctl start/stop/restart $SERVICE_NAME"
echo "查看日志: journalctl -u $SERVICE_NAME -f"

info "安装成功完成！"
