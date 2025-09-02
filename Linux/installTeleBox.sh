#!/bin/bash
# TeleBox 极致优化安装脚本 - 全面兼容所有 Debian 系发行版
# 支持: Debian, Ubuntu, Kali, Raspbian, Deepin, UOS, Mint, Pop!_OS, Elementary, MX Linux 等
# 版本: v2.0 优化版

set -euo pipefail

# ==================== 核心配置 ====================
readonly SCRIPT_VERSION="2.0"
readonly NODE_VERSION="20"
readonly GITHUB_REPO="https://github.com/TeleBoxDev/TeleBox.git"
readonly LOG_FILE="/tmp/telebox_install_$(date +%Y%m%d_%H%M%S).log"
readonly MIN_DISK_SPACE_MB=1024
readonly MIN_RAM_MB=512

# 动态目录配置（根据用户权限调整）
if [ "$EUID" -eq 0 ]; then
    APP_DIR="/root/telebox"
else
    APP_DIR="$HOME/telebox"
fi

# 镜像源配置
readonly -a NODE_MIRRORS=(
    "https://deb.nodesource.com/setup_${NODE_VERSION}.x"
    "https://mirrors.tuna.tsinghua.edu.cn/nodesource/deb/setup_${NODE_VERSION}.x"
    "https://mirrors.ustc.edu.cn/nodesource/deb/setup_${NODE_VERSION}.x"
)

readonly -a GIT_MIRRORS=(
    "https://github.com/TeleBoxDev/TeleBox.git"
    "https://gitee.com/TeleBoxDev/TeleBox.git"
    "https://gitlab.com/TeleBoxDev/TeleBox.git"
)

# 颜色和样式定义
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# 全局状态变量
DISTRO_INFO=""
PACKAGE_MANAGER=""
SUDO_CMD=""
INSTALL_LOG=""

# ==================== 核心工具函数 ====================

# 日志记录函数
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE" >/dev/null
}

# 进度显示函数
show_progress() {
    local current="$1"
    local total="$2"
    local desc="$3"
    local percent=$((current * 100 / total))
    local filled=$((percent / 2))
    local empty=$((50 - filled))
    
    printf "\r${BLUE}[%s%s] %d%% %s${NC}" \
        "$(printf '%*s' "$filled" '' | tr ' ' '█')" \
        "$(printf '%*s' "$empty" '' | tr ' ' '░')" \
        "$percent" "$desc"
    
    if [ "$current" -eq "$total" ]; then
        echo
    fi
}

# 增强错误处理
handle_error() {
    local exit_code=$?
    local line_no=$1
    echo -e "\n${RED}${BOLD}❌ 安装失败！${NC}"
    echo -e "${RED}错误位置: 第 $line_no 行${NC}"
    echo -e "${RED}退出代码: $exit_code${NC}"
    echo -e "${YELLOW}详细日志: $LOG_FILE${NC}"
    
    # 尝试提供解决建议
    case $exit_code in
        1) echo -e "${YELLOW}💡 建议: 检查网络连接或权限问题${NC}" ;;
        2) echo -e "${YELLOW}💡 建议: 检查系统依赖或磁盘空间${NC}" ;;
        126) echo -e "${YELLOW}💡 建议: 检查文件权限${NC}" ;;
        127) echo -e "${YELLOW}💡 建议: 检查命令是否存在${NC}" ;;
        *) echo -e "${YELLOW}💡 建议: 查看日志文件获取详细信息${NC}" ;;
    esac
    
    log "ERROR" "安装失败，行号: $line_no, 退出代码: $exit_code"
    cleanup_on_failure
    exit $exit_code
}

# 失败时清理
cleanup_on_failure() {
    echo -e "${YELLOW}正在清理安装失败的残留文件...${NC}"
    [ -d "$APP_DIR" ] && rm -rf "$APP_DIR" 2>/dev/null || true
    pkill -f "telebox" 2>/dev/null || true
}

trap 'handle_error $LINENO' ERR

# ==================== 系统检测和兼容性 ====================

# 检测发行版信息
detect_distro() {
    log "INFO" "检测系统发行版信息"
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO_INFO="$NAME $VERSION_ID"
    elif [ -f /etc/debian_version ]; then
        DISTRO_INFO="Debian $(cat /etc/debian_version)"
    else
        DISTRO_INFO="Unknown Debian-based"
    fi
    
    # 检测包管理器
    if command -v apt-get >/dev/null 2>&1; then
        PACKAGE_MANAGER="apt-get"
    elif command -v apt >/dev/null 2>&1; then
        PACKAGE_MANAGER="apt"
    else
        echo -e "${RED}❌ 未检测到支持的包管理器${NC}"
        exit 1
    fi
    
    # 检测权限提升命令
    if command -v sudo >/dev/null 2>&1; then
        SUDO_CMD="sudo"
    elif command -v doas >/dev/null 2>&1; then
        SUDO_CMD="doas"
    else
        echo -e "${YELLOW}⚠️  未检测到 sudo/doas，将尝试直接执行${NC}"
        SUDO_CMD=""
    fi
    
    echo -e "${GREEN}✅ 系统信息: $DISTRO_INFO${NC}"
    echo -e "${GREEN}✅ 包管理器: $PACKAGE_MANAGER${NC}"
    echo -e "${GREEN}✅ 权限命令: ${SUDO_CMD:-直接执行}${NC}"
    log "INFO" "系统检测完成: $DISTRO_INFO, 包管理器: $PACKAGE_MANAGER"
}

# 系统资源检查
check_system_requirements() {
    echo -e "${BLUE}🔍 检查系统资源...${NC}"
    
    # 检查磁盘空间
    local available_space=$(df "$HOME" | awk 'NR==2 {print $4}')
    local available_mb=$((available_space / 1024))
    
    if [ "$available_mb" -lt "$MIN_DISK_SPACE_MB" ]; then
        echo -e "${RED}❌ 磁盘空间不足！需要至少 ${MIN_DISK_SPACE_MB}MB，当前可用 ${available_mb}MB${NC}"
        exit 1
    fi
    
    # 检查内存
    local total_ram=$(free -m | awk 'NR==2{print $2}')
    if [ "$total_ram" -lt "$MIN_RAM_MB" ]; then
        echo -e "${YELLOW}⚠️  内存较低: ${total_ram}MB (建议至少 ${MIN_RAM_MB}MB)${NC}"
    fi
    
    # 检查网络连接
    if ! ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  网络连接异常，将使用镜像源${NC}"
    fi
    
    echo -e "${GREEN}✅ 系统资源检查通过${NC}"
    log "INFO" "系统资源检查完成: 磁盘 ${available_mb}MB, 内存 ${total_ram}MB"
}

# 智能清理函数（仅清理 TeleBox，保护其他服务）
cleanup_telebox() {
    echo -e "${YELLOW}${BOLD}🧹 开始智能清理 TeleBox 相关配置和文件${NC}"
    show_progress 1 6 "初始化清理"
    
    # 1. 停止并删除 PM2 中的 TeleBox 服务
    show_progress 2 6 "清理 PM2 服务"
    if command -v pm2 >/dev/null 2>&1; then
        pm2 delete telebox 2>/dev/null || true
        pm2 save 2>/dev/null || true
        log "INFO" "PM2 TeleBox 服务已清理"
    fi
    
    # 2. 智能终止 TeleBox 相关进程
    show_progress 3 6 "终止相关进程"
    local pids=$(pgrep -f "telebox" 2>/dev/null || true)
    if [ -n "$pids" ]; then
        echo "$pids" | xargs -r kill -TERM 2>/dev/null || true
        sleep 3
        echo "$pids" | xargs -r kill -KILL 2>/dev/null || true
    fi
    
    # 3. 清理应用目录和相关文件
    show_progress 4 6 "删除应用目录"
    [ -d "$APP_DIR" ] && rm -rf "$APP_DIR" && log "INFO" "应用目录已删除: $APP_DIR"
    
    # 4. 清理缓存、日志和临时文件
    show_progress 5 6 "清理缓存文件"
    rm -rf "/tmp/telebox"* "$HOME/.telebox"* "$HOME/.npm/_cacache/telebox"* 2>/dev/null || true
    
    # 5. 清理 systemd 服务（如果存在）
    show_progress 6 6 "清理系统服务"
    if [ -f "/etc/systemd/system/telebox.service" ]; then
        $SUDO_CMD systemctl stop telebox 2>/dev/null || true
        $SUDO_CMD systemctl disable telebox 2>/dev/null || true
        $SUDO_CMD rm -f "/etc/systemd/system/telebox.service"
        $SUDO_CMD systemctl daemon-reload
    fi
    
    echo -e "\n${GREEN}✅ 清理完成！${NC}"
    log "INFO" "TeleBox 清理完成"
    sleep 1
}

# 智能依赖安装（支持多种包管理器和镜像源）
install_dependencies() {
    echo -e "${BLUE}${BOLD}📦 智能安装系统依赖${NC}"
    
    # 更新包索引
    show_progress 1 8 "更新包索引"
    log "INFO" "开始更新系统包索引"
    
    # 尝试多次更新，处理镜像源问题
    local update_success=false
    for attempt in {1..3}; do
        if $SUDO_CMD $PACKAGE_MANAGER update -qq 2>/dev/null; then
            update_success=true
            break
        fi
        echo -e "${YELLOW}⚠️  更新尝试 $attempt 失败，重试中...${NC}"
        sleep 2
    done
    
    if [ "$update_success" = false ]; then
        echo -e "${RED}❌ 包索引更新失败，请检查网络连接${NC}"
        exit 1
    fi
    
    # 安装基础依赖
    show_progress 2 8 "安装基础工具"
    local base_packages=("curl" "wget" "git" "build-essential" "ca-certificates" "gnupg" "lsb-release")
    
    for pkg in "${base_packages[@]}"; do
        if ! dpkg -l | grep -q "^ii.*$pkg"; then
            $SUDO_CMD $PACKAGE_MANAGER install -y "$pkg" || {
                echo -e "${YELLOW}⚠️  $pkg 安装失败，尝试替代方案${NC}"
                case "$pkg" in
                    "build-essential") $SUDO_CMD $PACKAGE_MANAGER install -y gcc g++ make || true ;;
                    "ca-certificates") $SUDO_CMD $PACKAGE_MANAGER install -y openssl || true ;;
                esac
            }
        fi
    done
    
    log "INFO" "基础依赖安装完成"
    
    # 智能安装 Node.js
    install_nodejs
}

# 智能 Node.js 安装（多源支持）
install_nodejs() {
    show_progress 3 8 "检测 Node.js"
    
    # 检查是否已安装合适版本
    if command -v node >/dev/null 2>&1; then
        local current_version=$(node --version | sed 's/v//' | cut -d. -f1)
        if [ "$current_version" -ge "$NODE_VERSION" ]; then
            echo -e "${GREEN}✅ Node.js v$current_version 已安装${NC}"
            log "INFO" "Node.js 已存在，版本: v$current_version"
            return 0
        fi
    fi
    
    echo -e "${BLUE}📥 安装 Node.js ${NODE_VERSION}.x${NC}"
    
    # 方法1: NodeSource 官方源（支持多镜像）
    show_progress 4 8 "尝试 NodeSource 源"
    for mirror in "${NODE_MIRRORS[@]}"; do
        echo -e "${CYAN}🔄 尝试镜像: $mirror${NC}"
        if curl -fsSL "$mirror" | $SUDO_CMD -E bash - 2>/dev/null; then
            if $SUDO_CMD $PACKAGE_MANAGER install -y nodejs; then
                log "INFO" "Node.js 通过 NodeSource 安装成功"
                show_progress 5 8 "Node.js 安装完成"
                return 0
            fi
        fi
        echo -e "${YELLOW}⚠️  镜像 $mirror 失败，尝试下一个${NC}"
    done
    
    # 方法2: 系统默认源
    show_progress 6 8 "尝试系统默认源"
    if $SUDO_CMD $PACKAGE_MANAGER install -y nodejs npm; then
        local version=$(node --version | sed 's/v//' | cut -d. -f1)
        if [ "$version" -ge 16 ]; then
            log "INFO" "Node.js 通过系统源安装成功，版本: v$version"
            show_progress 7 8 "Node.js 安装完成"
            return 0
        fi
    fi
    
    # 方法3: Snap 包管理器（如果可用）
    show_progress 7 8 "尝试 Snap 安装"
    if command -v snap >/dev/null 2>&1; then
        if $SUDO_CMD snap install node --classic; then
            log "INFO" "Node.js 通过 Snap 安装成功"
            show_progress 8 8 "Node.js 安装完成"
            return 0
        fi
    fi
    
    # 方法4: 手动二进制安装（最后手段）
    echo -e "${YELLOW}⚠️  所有包管理器方式失败，尝试手动安装${NC}"
    install_nodejs_manual
}

# 手动安装 Node.js
install_nodejs_manual() {
    local arch=$(uname -m)
    case "$arch" in
        x86_64) arch="x64" ;;
        aarch64) arch="arm64" ;;
        armv7l) arch="armv7l" ;;
        *) echo -e "${RED}❌ 不支持的架构: $arch${NC}"; exit 1 ;;
    esac
    
    local node_url="https://nodejs.org/dist/v${NODE_VERSION}.0.0/node-v${NODE_VERSION}.0.0-linux-${arch}.tar.xz"
    local temp_dir="/tmp/nodejs_install"
    
    mkdir -p "$temp_dir"
    cd "$temp_dir"
    
    if wget -q "$node_url" -O "nodejs.tar.xz"; then
        tar -xf "nodejs.tar.xz"
        $SUDO_CMD cp -r "node-v${NODE_VERSION}.0.0-linux-${arch}"/* /usr/local/
        rm -rf "$temp_dir"
        log "INFO" "Node.js 手动安装成功"
        show_progress 8 8 "Node.js 手动安装完成"
    else
        echo -e "${RED}❌ Node.js 手动安装失败${NC}"
        exit 1
    fi
}

# 智能应用设置（多源克隆和优化安装）
setup_application() {
    echo -e "${BLUE}${BOLD}⚙️  智能设置 TeleBox 应用${NC}"
    
    # 创建应用目录
    show_progress 1 6 "创建应用目录"
    mkdir -p "$APP_DIR"
    cd "$APP_DIR"
    log "INFO" "应用目录创建: $APP_DIR"
    
    # 智能克隆（多镜像源支持）
    show_progress 2 6 "克隆源代码"
    local clone_success=false
    
    for mirror in "${GIT_MIRRORS[@]}"; do
        echo -e "${CYAN}🔄 尝试克隆: $mirror${NC}"
        if timeout 60 git clone --depth 1 "$mirror" . 2>/dev/null; then
            clone_success=true
            log "INFO" "成功从 $mirror 克隆代码"
            break
        fi
        echo -e "${YELLOW}⚠️  镜像 $mirror 失败，尝试下一个${NC}"
        rm -rf .git 2>/dev/null || true
    done
    
    if [ "$clone_success" = false ]; then
        echo -e "${RED}❌ 所有镜像源克隆失败${NC}"
        exit 1
    fi
    
    # 优化 npm 配置
    show_progress 3 6 "配置 npm"
    npm config set registry https://registry.npmmirror.com/ 2>/dev/null || true
    npm config set fetch-timeout 300000
    npm config set fetch-retry-mintimeout 20000
    npm config set fetch-retry-maxtimeout 120000
    
    # 智能依赖安装
    show_progress 4 6 "安装项目依赖"
    local install_success=false
    
    # 尝试多种安装方式
    for method in "npm ci --prefer-offline --no-audit" "npm install --prefer-offline" "npm install"; do
        echo -e "${CYAN}🔄 尝试: $method${NC}"
        if timeout 600 $method 2>/dev/null; then
            install_success=true
            log "INFO" "依赖安装成功: $method"
            break
        fi
        echo -e "${YELLOW}⚠️  方法失败，尝试下一种${NC}"
    done
    
    if [ "$install_success" = false ]; then
        echo -e "${RED}❌ 依赖安装失败${NC}"
        exit 1
    fi
    
    # 构建项目（如果需要）
    show_progress 5 6 "构建项目"
    if [ -f "package.json" ] && grep -q '"build"' package.json; then
        npm run build 2>/dev/null || {
            echo -e "${YELLOW}⚠️  构建失败，跳过构建步骤${NC}"
        }
    fi
    
    show_progress 6 6 "应用设置完成"
    echo -e "\n${GREEN}✅ TeleBox 应用设置完成${NC}"
    log "INFO" "TeleBox 应用设置完成"
}

# 流畅登录配置
configure_login() {
    echo -e "${BLUE}🔐 启动 TeleBox 进行首次登录${NC}"
    
    # 检查会话文件
    if [ -f "$APP_DIR/my_session/session.session" ] || [ -f "$APP_DIR/session.session" ]; then
        echo -e "${GREEN}✅ 检测到现有会话，跳过登录${NC}"
        return 0
    fi
    
    echo -e "${YELLOW}请按照提示输入 Telegram 账户信息${NC}"
    echo -e "${YELLOW}登录成功后按 CTRL+C 继续安装${NC}"
    echo
    
    # 直接启动，不添加复杂逻辑
    set +e
    trap - ERR
    
    trap 'echo -e "\n${GREEN}登录完成，继续安装...${NC}"' SIGINT
    
    npm start || true
    
    trap 'handle_error $LINENO' ERR
    set -e
    
    echo -e "${GREEN}✅ 登录完成${NC}"
}

# 智能 PM2 配置（增强稳定性和监控）
setup_pm2() {
    echo -e "${BLUE}${BOLD}🔧 智能配置 PM2 进程管理${NC}"
    
    # 智能安装 PM2
    show_progress 1 6 "安装 PM2"
    if ! command -v pm2 >/dev/null 2>&1; then
        # 尝试多种安装方式
        if ! $SUDO_CMD npm install -g pm2; then
            echo -e "${YELLOW}⚠️  全局安装失败，尝试本地安装${NC}"
            npm install pm2
            export PATH="$APP_DIR/node_modules/.bin:$PATH"
        fi
    fi
    
    # 验证 PM2 安装
    if ! command -v pm2 >/dev/null 2>&1; then
        echo -e "${RED}❌ PM2 安装失败${NC}"
        exit 1
    fi
    
    # 创建优化的目录结构
    show_progress 2 6 "创建目录结构"
    mkdir -p "$APP_DIR"/{logs,backups,temp}
    cd "$APP_DIR"
    
    # 创建增强的 ecosystem 配置
    show_progress 3 6 "生成 PM2 配置"
    cat > "$APP_DIR/ecosystem.config.js" <<EOF
module.exports = {
  apps: [
    {
      name: "telebox",
      script: "npm",
      args: "start",
      cwd: "$APP_DIR",
      error_file: "./logs/error.log",
      out_file: "./logs/out.log",
      log_file: "./logs/combined.log",
      merge_logs: true,
      time: true,
      autorestart: true,
      max_restarts: 15,
      min_uptime: "30s",
      restart_delay: 5000,
      max_memory_restart: "500M",
      kill_timeout: 5000,
      listen_timeout: 8000,
      env: {
        NODE_ENV: "production",
        NODE_OPTIONS: "--max-old-space-size=512"
      },
      env_development: {
        NODE_ENV: "development"
      }
    }
  ]
}
EOF
    
    # 启动服务
    show_progress 4 6 "启动 TeleBox 服务"
    pm2 start ecosystem.config.js
    pm2 save
    log "INFO" "PM2 服务启动成功"
    
    # 配置开机自启（智能处理）
    show_progress 5 6 "配置开机自启"
    local startup_cmd=$(pm2 startup systemd -u "$USER" --hp "$HOME" 2>/dev/null | grep "sudo" || true)
    if [ -n "$startup_cmd" ]; then
        eval "$startup_cmd" 2>/dev/null || {
            echo -e "${YELLOW}⚠️  自动配置开机自启失败${NC}"
            echo -e "${CYAN}💡 手动执行: pm2 startup${NC}"
        }
    fi
    
    show_progress 6 6 "PM2 配置完成"
    echo -e "\n${GREEN}✅ PM2 配置完成${NC}"
    log "INFO" "PM2 配置和启动完成"
}

# 智能完成信息显示
show_completion_info() {
    echo -e "${GREEN}${BOLD}🎉 TeleBox 安装完成！${NC}"
    echo -e "${GREEN}✨ 已成功安装并通过 PM2 托管运行！${NC}"
    echo
    
    # 显示系统信息摘要
    echo -e "${PURPLE}${BOLD}📊 安装摘要${NC}"
    echo -e "${CYAN}├─ 系统版本: $DISTRO_INFO${NC}"
    echo -e "${CYAN}├─ Node.js: $(node --version 2>/dev/null || echo '未知')${NC}"
    echo -e "${CYAN}├─ 安装路径: $APP_DIR${NC}"
    echo -e "${CYAN}└─ 日志文件: $LOG_FILE${NC}"
    echo
    
    # 管理命令指南
    echo -e "${BLUE}${BOLD}🛠️  常用管理命令${NC}"
    echo -e "${CYAN}┌─ 服务管理 ────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC} pm2 status telebox      ${YELLOW}# 查看运行状态${NC}"
    echo -e "${CYAN}│${NC} pm2 logs telebox        ${YELLOW}# 查看实时日志${NC}"
    echo -e "${CYAN}│${NC} pm2 restart telebox     ${YELLOW}# 重启服务${NC}"
    echo -e "${CYAN}│${NC} pm2 stop telebox        ${YELLOW}# 停止服务${NC}"
    echo -e "${CYAN}│${NC} pm2 monit               ${YELLOW}# 实时监控${NC}"
    echo -e "${CYAN}└───────────────────────────────────────────────┘${NC}"
    echo
    
    # 实时状态检查
    echo -e "${BLUE}${BOLD}📈 当前服务状态${NC}"
    if pm2 status telebox >/dev/null 2>&1; then
        pm2 status telebox
        echo
        echo -e "${GREEN}✅ TeleBox 运行正常${NC}"
        
        # 显示最近日志
        echo -e "${BLUE}📋 最近日志 (最后10行):${NC}"
        timeout 5 pm2 logs telebox --lines 10 --nostream 2>/dev/null || {
            echo -e "${YELLOW}⚠️  日志获取超时${NC}"
        }
    else
        echo -e "${YELLOW}⚠️  PM2 状态查询失败，请手动检查${NC}"
    fi
    
    echo
    echo -e "${GREEN}${BOLD}🚀 安装配置完成！${NC}"
    echo -e "${GREEN}TeleBox 正在后台稳定运行，使用上述命令进行管理。${NC}"
    echo -e "${CYAN}💡 如需帮助，查看日志: pm2 logs telebox${NC}"
    
    log "INFO" "TeleBox 安装完成，版本: $SCRIPT_VERSION"
}

# 智能主安装流程
install_telebox() {
    echo -e "${GREEN}${BOLD}🚀 开始智能安装 TeleBox${NC}"
    log "INFO" "开始 TeleBox 安装流程，版本: $SCRIPT_VERSION"
    
    detect_distro
    check_system_requirements
    install_dependencies
    setup_application
    configure_login
    setup_pm2
    show_completion_info
}

# 增强主函数（支持多种运行模式）
main() {
    # 初始化日志
    echo "TeleBox 安装开始 - $(date)" > "$LOG_FILE"
    
    echo -e "${GREEN}${BOLD}🎯 TeleBox 极致优化安装脚本 v${SCRIPT_VERSION}${NC}"
    echo -e "${CYAN}🌟 全面兼容所有 Debian 系发行版${NC}"
    echo -e "${YELLOW}⚡ 此脚本将智能清理并重新安装 TeleBox，保护其他服务${NC}"
    echo
    
    # 检查运行参数
    case "${1:-}" in
        "--force"|"-f")
            echo -e "${YELLOW}🔥 强制模式：跳过确认直接安装${NC}"
            ;;
        "--clean-only"|"-c")
            echo -e "${BLUE}🧹 仅清理模式${NC}"
            detect_distro
            cleanup_telebox
            echo -e "${GREEN}✅ 清理完成${NC}"
            exit 0
            ;;
        "--help"|"-h")
            echo -e "${CYAN}使用方法:${NC}"
            echo -e "  $0           ${YELLOW}# 交互式安装${NC}"
            echo -e "  $0 --force   ${YELLOW}# 强制安装（跳过确认）${NC}"
            echo -e "  $0 --clean-only ${YELLOW}# 仅清理 TeleBox${NC}"
            echo -e "  $0 --help    ${YELLOW}# 显示帮助${NC}"
            exit 0
            ;;
        "")
            # 交互式确认
            echo -e "${CYAN}┌─ 安装确认 ────────────────────────────────────┐${NC}"
            echo -e "${CYAN}│  ⚠️  这将删除所有现有 TeleBox 配置和文件       │${NC}"
            echo -e "${CYAN}│  ✅ 不会影响 PM2 中的其他服务                │${NC}"
            echo -e "${CYAN}│  📦 将安装最新版本的 TeleBox                 │${NC}"
            echo -e "${CYAN}└───────────────────────────────────────────────┘${NC}"
            echo
            
            read -p "$(echo -e "${GREEN}是否继续安装？ (y/N): ${NC}")" -n 1 -r
            echo
            
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                echo -e "${YELLOW}❌ 安装已取消${NC}"
                log "INFO" "用户取消安装"
                exit 0
            fi
            ;;
        *)
            echo -e "${RED}❌ 未知参数: $1${NC}"
            echo -e "${CYAN}使用 $0 --help 查看帮助${NC}"
            exit 1
            ;;
    esac
    
    # 开始安装流程
    echo -e "${GREEN}${BOLD}🎬 开始安装流程...${NC}"
    log "INFO" "用户确认开始安装"
    
    cleanup_telebox
    install_telebox
    
    echo -e "${GREEN}${BOLD}🏁 所有安装步骤完成！${NC}"
    log "INFO" "TeleBox 安装流程全部完成"
}

# ==================== 脚本执行入口 ====================
# Root 用户支持和权限配置
if [ "$EUID" -eq 0 ]; then
    echo -e "${GREEN}✅ Root 用户模式启用${NC}"
    echo -e "${CYAN}📁 安装目录: /root/telebox${NC}"
    SUDO_CMD=""
    
    # 创建普通用户目录链接（如果通过 sudo 执行）
    if [ -n "${SUDO_USER:-}" ]; then
        local user_home=$(eval echo "~$SUDO_USER")
        echo -e "${BLUE}🔗 为用户 $SUDO_USER 创建便捷链接${NC}"
        mkdir -p "$(dirname "$user_home/telebox")" 2>/dev/null || true
        ln -sf "$APP_DIR" "$user_home/telebox" 2>/dev/null || true
    fi
fi

# 执行主函数
main "$@"
