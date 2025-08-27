#!/bin/bash
# TeleBox 安装脚本（只清理 TeleBox 自身配置）
# 适用于 Debian / Ubuntu

set -euo pipefail

# 定义变量
readonly APP_DIR="$HOME/telebox"
readonly NODE_VERSION="20"
readonly GITHUB_REPO="https://github.com/TeleBoxDev/TeleBox.git"

# 颜色输出
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# 错误处理函数
handle_error() {
    echo -e "${RED}错误发生在第 $1 行${NC}"
    exit 1
}

trap 'handle_error $LINENO' ERR

# 清理函数（仅清理 TeleBox，不影响 PM2 其他应用）
cleanup_telebox() {
    echo -e "${YELLOW}==== 开始清理 TeleBox 相关配置和文件 ====${NC}"
    
    # 1. 停止并删除 PM2 中的 TeleBox 服务
    echo -e "${BLUE}清理 PM2 服务...${NC}"
    if command -v pm2 >/dev/null 2>&1; then
        pm2 delete telebox 2>/dev/null || true
    fi
    
    # 2. 强制终止 TeleBox 相关进程
    echo -e "${BLUE}终止 TeleBox 相关进程...${NC}"
    pkill -f "telebox" 2>/dev/null || true
    pkill -f "npm.*start.*telebox" 2>/dev/null || true
    pkill -f "node.*telebox" 2>/dev/null || true
    
    sleep 2
    
    # 3. 删除 TeleBox 应用目录
    echo -e "${BLUE}删除应用目录...${NC}"
    if [ -d "$APP_DIR" ]; then
        rm -rf "$APP_DIR"
        echo "已删除: $APP_DIR"
    fi
    
    # 4. 清理 TeleBox 相关的缓存和配置文件
    echo -e "${BLUE}清理缓存和配置文件...${NC}"
    rm -rf "/tmp/telebox"* "$HOME/.telebox"* "$HOME/telebox"* 2>/dev/null || true
    
    echo -e "${GREEN}清理完成！${NC}"
    sleep 1
}

# 安装系统依赖
install_dependencies() {
    echo -e "${BLUE}==== 更新系统并安装基础工具 ====${NC}"
    sudo apt-get update
    sudo apt-get install -y curl git build-essential
    
    echo -e "${BLUE}==== 安装 Node.js ${NODE_VERSION}.x ====${NC}"
    curl -fsSL "https://deb.nodesource.com/setup_${NODE_VERSION}.x" | sudo -E bash -
    sudo apt-get install -y nodejs
}

# 设置 TeleBox 应用
setup_application() {
    echo -e "${BLUE}==== 创建目录并克隆 TeleBox ====${NC}"
    mkdir -p "$APP_DIR"
    cd "$APP_DIR"
    git clone "$GITHUB_REPO" .
    
    echo -e "${BLUE}==== 安装依赖 ====${NC}"
    npm ci --prefer-offline --no-audit
}

# 首次登录配置
configure_login() {
    echo -e "${BLUE}==== 启动 TeleBox（首次登录）====${NC}"
    echo -e "${YELLOW}>>> 现在将启动 TeleBox 进行首次登录配置 <<<${NC}"
    echo -e "${YELLOW}>>> 请按照提示输入您的 Telegram 账户信息 <<<${NC}"
    echo -e "${YELLOW}>>> 登录完成并看到 'You should now be connected.' 后按 CTRL+C <<<${NC}"
    echo -e "${RED}>>> 重要：请等待登录完全成功后再按 CTRL+C！ <<<${NC}"
    echo -e "${BLUE}====================================================${NC}"
    echo -e "${GREEN}按回车键开始登录过程...${NC}"
    read -r
    
    # 临时禁用严格错误处理
    set +e
    trap - ERR
    
    # 设置中断处理
    handle_interrupt() {
        echo -e "\n${YELLOW}检测到中断信号，准备继续安装...${NC}"
    }
    trap handle_interrupt SIGINT
    
    # 启动登录过程
    npm start || true
    
    # 恢复信号处理
    trap - SIGINT
    trap 'handle_error $LINENO' ERR
    set -e
    
    echo -e "${GREEN}登录过程完成，继续安装 PM2...${NC}"
    sleep 2
}

# 配置 PM2
setup_pm2() {
    echo -e "${BLUE}==== 安装并配置 PM2 ====${NC}"
    if ! command -v pm2 >/dev/null 2>&1; then
        sudo npm install -g pm2
    fi
    
    # 创建日志目录
    mkdir -p "$APP_DIR/logs"
    
    # 创建 ecosystem 配置
    cat > "$APP_DIR/ecosystem.config.js" <<'EOF'
module.exports = {
  apps: [
    {
      name: "telebox",
      script: "npm",
      args: "start",
      cwd: __dirname,
      error_file: "./logs/error.log",
      out_file: "./logs/out.log",
      merge_logs: true,
      time: true,
      autorestart: true,
      max_restarts: 10,
      min_uptime: "10s",
      restart_delay: 4000,
      env: {
        NODE_ENV: "production"
      }
    }
  ]
}
EOF
    
    echo -e "${BLUE}==== 使用 PM2 启动 TeleBox ====${NC}"
    cd "$APP_DIR"
    pm2 start ecosystem.config.js
    pm2 save
    
    echo -e "${BLUE}==== 配置开机自启 ====${NC}"
    pm2 startup systemd -u "$USER" --hp "$HOME" | grep "sudo" | bash || {
        echo -e "${YELLOW}自动配置开机自启失败，请手动执行：pm2 startup${NC}"
    }
}

# 显示完成信息
show_completion_info() {
    echo -e "${GREEN}==== 安装完成 ====${NC}"
    echo -e "${GREEN}TeleBox 已成功安装并通过 PM2 托管运行！${NC}"
    echo
    echo -e "${BLUE}常用管理命令：${NC}"
    echo "查看日志: pm2 logs telebox"
    echo "实时日志: pm2 logs telebox --lines 50"
    echo "重启服务: pm2 restart telebox"
    echo "停止服务: pm2 stop telebox"
    echo "查看状态: pm2 status telebox"
    echo "删除服务: pm2 delete telebox"
    echo
    echo -e "${GREEN}当前状态：${NC}"
    pm2 status telebox || echo -e "${YELLOW}PM2 状态查询失败，请手动检查${NC}"
    echo
    echo -e "${BLUE}正在检查服务状态（3秒后自动退出）...${NC}"
    timeout 3 pm2 logs telebox --lines 20 || true
    echo
    echo -e "${GREEN}==== 安装配置完成！====${NC}"
    echo -e "${GREEN}TeleBox 正在后台运行，使用上述命令进行管理。${NC}"
}

# 主安装函数
install_telebox() {
    echo -e "${GREEN}==== 开始全新安装 TeleBox ====${NC}"
    install_dependencies
    setup_application
    configure_login
    setup_pm2
    show_completion_info
}

# 主函数
main() {
    echo -e "${GREEN}TeleBox 自动安装脚本${NC}"
    echo -e "${YELLOW}此脚本将清理 TeleBox 配置并重新安装，不影响 PM2 其他服务${NC}"
    echo
    
    read -p "是否继续？这将删除所有 TeleBox 配置和文件 (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}安装已取消${NC}"
        exit 0
    fi
    
    cleanup_telebox
    install_telebox
}

# 执行
main "$@"
