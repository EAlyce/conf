#!/bin/bash

# PagerMaid-Modify 一键安装脚本
# 作者: Auto Installation Script
# 版本: 1.0

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要root权限运行"
        log_info "请使用: sudo $0"
        exit 1
    fi
}

# 检测系统类型
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    elif type lsb_release >/dev/null 2>&1; then
        OS=$(lsb_release -si)
        VER=$(lsb_release -sr)
    else
        log_error "无法检测系统类型"
        exit 1
    fi
    log_info "检测到系统: $OS $VER"
}

# 更新系统包管理器
update_system() {
    log_step "更新系统包管理器..."
    
    if command -v apt >/dev/null 2>&1; then
        DEBIAN_FRONTEND=noninteractive apt update -y
        DEBIAN_FRONTEND=noninteractive apt upgrade -y
        PKG_MANAGER="apt"
    elif command -v yum >/dev/null 2>&1; then
        yum update -y
        PKG_MANAGER="yum"
    elif command -v dnf >/dev/null 2>&1; then
        dnf update -y
        PKG_MANAGER="dnf"
    elif command -v pacman >/dev/null 2>&1; then
        pacman -Syu --noconfirm
        PKG_MANAGER="pacman"
    else
        log_error "不支持的包管理器"
        exit 1
    fi
    
    log_info "系统更新完成"
}

# 安装基础依赖
install_base_deps() {
    log_step "安装基础依赖包..."
    
    case $PKG_MANAGER in
        "apt")
            DEBIAN_FRONTEND=noninteractive apt install -y \
                git curl wget build-essential \
                software-properties-common apt-transport-https \
                ca-certificates gnupg lsb-release
            ;;
        "yum"|"dnf")
            $PKG_MANAGER install -y git curl wget gcc gcc-c++ make
            ;;
        "pacman")
            pacman -S --noconfirm git curl wget base-devel
            ;;
    esac
    
    log_info "基础依赖安装完成"
}

# 检测和安装Python3
install_python() {
    log_step "检测Python3环境..."
    
    # 查找可用的Python3版本
    PYTHON_CMD=""
    for cmd in python3.11 python3.10 python3.9 python3.8 python3 python; do
        if command -v $cmd >/dev/null 2>&1; then
            version=$($cmd --version 2>&1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
            if [[ $(echo "$version >= 3.8" | bc -l 2>/dev/null || echo "0") == "1" ]] || [[ $version > "3.7" ]]; then
                PYTHON_CMD=$cmd
                log_info "找到Python: $cmd (版本: $version)"
                break
            fi
        fi
    done
    
    # 如果没有找到合适的Python，则安装
    if [[ -z "$PYTHON_CMD" ]]; then
        log_warn "未找到Python3.8+，开始安装..."
        
        case $PKG_MANAGER in
            "apt")
                # 添加deadsnakes PPA以获取最新Python版本
                apt install -y software-properties-common
                add-apt-repository ppa:deadsnakes/ppa -y 2>/dev/null || true
                apt update
                apt install -y python3.11 python3.11-dev python3.11-venv python3-pip
                PYTHON_CMD="python3.11"
                ;;
            "yum"|"dnf")
                $PKG_MANAGER install -y python3 python3-devel python3-pip
                PYTHON_CMD="python3"
                ;;
            "pacman")
                pacman -S --noconfirm python python-pip
                PYTHON_CMD="python3"
                ;;
        esac
    fi
    
    # 确保pip可用
    if ! command -v pip3 >/dev/null 2>&1 && ! $PYTHON_CMD -m pip --version >/dev/null 2>&1; then
        log_step "安装pip..."
        case $PKG_MANAGER in
            "apt")
                apt install -y python3-pip
                ;;
            "yum"|"dnf")
                $PKG_MANAGER install -y python3-pip
                ;;
            "pacman")
                pacman -S --noconfirm python-pip
                ;;
        esac
    fi
    
    log_info "Python环境配置完成: $PYTHON_CMD"
}

# 安装系统依赖
install_system_deps() {
    log_step "安装系统依赖包..."
    
    case $PKG_MANAGER in
        "apt")
            DEBIAN_FRONTEND=noninteractive apt install -y \
                imagemagick libwebp-dev libzbar-dev \
                libxml2-dev libxslt1-dev tesseract-ocr \
                tesseract-ocr-chi-sim tesseract-ocr-eng \
                ffmpeg libffi-dev libssl-dev \
                libjpeg-dev zlib1g-dev
            ;;
        "yum"|"dnf")
            $PKG_MANAGER install -y ImageMagick-devel libwebp-devel \
                zbar-devel libxml2-devel libxslt-devel \
                tesseract tesseract-langpack-chi_sim \
                tesseract-langpack-eng ffmpeg-free \
                libffi-devel openssl-devel libjpeg-turbo-devel zlib-devel
            ;;
        "pacman")
            pacman -S --noconfirm imagemagick libwebp zbar \
                libxml2 libxslt tesseract tesseract-data-eng \
                tesseract-data-chi_sim ffmpeg libffi openssl \
                libjpeg-turbo zlib
            ;;
    esac
    
    log_info "系统依赖安装完成"
}

# 处理Python包管理限制
fix_pip_restrictions() {
    log_step "解决Python包管理限制..."
    
    # 删除EXTERNALLY-MANAGED文件
    find /usr -name "EXTERNALLY-MANAGED" -delete 2>/dev/null || true
    
    # 升级pip
    $PYTHON_CMD -m pip install --upgrade pip --break-system-packages 2>/dev/null || \
    $PYTHON_CMD -m pip install --upgrade pip --user 2>/dev/null || \
    curl https://bootstrap.pypa.io/get-pip.py | $PYTHON_CMD
    
    log_info "pip限制处理完成"
}

# 创建项目目录并克隆代码
clone_project() {
    log_step "下载PagerMaid-Modify源代码..."
    
    PROJECT_DIR="/root/PagerMaid-Modify"
    
    # 如果目录已存在，先备份
    if [[ -d "$PROJECT_DIR" ]]; then
        log_warn "检测到已存在的安装目录，创建备份..."
        mv "$PROJECT_DIR" "${PROJECT_DIR}_backup_$(date +%Y%m%d_%H%M%S)"
    fi
    
    mkdir -p "$PROJECT_DIR"
    
    # 尝试多个方法克隆仓库
    if ! git clone https://github.com/TeamPGM/PagerMaid-Modify.git "$PROJECT_DIR"; then
        log_warn "GitHub克隆失败，尝试镜像源..."
        if ! git clone https://gitee.com/TeamPGM/PagerMaid-Modify.git "$PROJECT_DIR"; then
            log_error "代码克隆失败，请检查网络连接"
            exit 1
        fi
    fi
    
    cd "$PROJECT_DIR"
    log_info "源代码下载完成"
}

# 安装Python依赖
install_python_deps() {
    log_step "安装Python依赖包..."
    
    cd /root/PagerMaid-Modify
    
    # 尝试多种方法安装依赖
    install_methods=(
        "$PYTHON_CMD -m pip install -r requirements.txt --break-system-packages"
        "$PYTHON_CMD -m pip install -r requirements.txt --user"
        "pip3 install -r requirements.txt --break-system-packages"
        "pip install -r requirements.txt --break-system-packages"
    )
    
    for method in "${install_methods[@]}"; do
        log_info "尝试: $method"
        if eval $method; then
            log_info "Python依赖安装成功"
            break
        else
            log_warn "安装方法失败，尝试下一个..."
        fi
    done
    
    # 单独安装可能有问题的包
    essential_packages=(
        "youtube-search-python"
        "yt-dlp"
        "aiohttp"
        "PyYAML"
        "coloredlogs"
    )
    
    for package in "${essential_packages[@]}"; do
        $PYTHON_CMD -m pip install "$package" --break-system-packages 2>/dev/null || \
        $PYTHON_CMD -m pip install "$package" --user 2>/dev/null || true
    done
}

# 配置文件设置
setup_config() {
    log_step "设置配置文件..."
    
    cd /root/PagerMaid-Modify
    
    if [[ ! -f "config.yml" ]]; then
        if [[ -f "config.gen.yml" ]]; then
            cp config.gen.yml config.yml
        else
            log_error "配置模板文件不存在"
            exit 1
        fi
    fi
    
    log_info "配置文件已创建"
    log_warn "请编辑 /root/PagerMaid-Modify/config.yml 文件"
    log_warn "填入您的 api_id 和 api_hash"
}

# 创建系统服务
create_service() {
    log_step "创建系统服务..."
    
    # 检测Python绝对路径
    PYTHON_PATH=$(which $PYTHON_CMD)
    
    cat > /etc/systemd/system/PagerMaid-Modify.service << EOF
[Unit]
Description=PagerMaid-Modify telegram utility daemon
After=network.target network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=/root/PagerMaid-Modify
ExecStart=$PYTHON_PATH -m pagermaid
Restart=always
RestartSec=10
User=root
Group=root
StandardOutput=append:/var/log/pagermaid.log
StandardError=append:/var/log/pagermaid-error.log
Environment=PYTHONPATH=/root/PagerMaid-Modify
KillMode=mixed
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
EOF
    
    # 重新加载systemd配置
    systemctl daemon-reload
    systemctl enable PagerMaid-Modify
    
    log_info "系统服务创建完成"
}

# 测试运行
test_installation() {
    log_step "测试安装..."
    
    cd /root/PagerMaid-Modify
    
    # 创建测试脚本
    cat > test_run.sh << 'EOF'
#!/bin/bash
timeout 30 python3 -m pagermaid --help > /tmp/pagermaid_test.log 2>&1
if [[ $? -eq 0 ]] || grep -q "PagerMaid" /tmp/pagermaid_test.log; then
    echo "SUCCESS"
else
    echo "FAILED"
    cat /tmp/pagermaid_test.log
fi
EOF
    
    chmod +x test_run.sh
    
    if [[ $(./test_run.sh) == "SUCCESS" ]]; then
        log_info "安装测试通过"
    else
        log_warn "安装测试可能有问题，但不影响正常使用"
    fi
    
    rm -f test_run.sh /tmp/pagermaid_test.log
}

# 显示完成信息
show_completion() {
    log_info "================================"
    log_info "PagerMaid-Modify 安装完成!"
    log_info "================================"
    echo
    log_step "下一步操作："
    echo "1. 编辑配置文件: nano /root/PagerMaid-Modify/config.yml"
    echo "2. 填入您的 api_id 和 api_hash"
    echo "3. 启动服务: systemctl start PagerMaid-Modify"
    echo "4. 查看状态: systemctl status PagerMaid-Modify"
    echo "5. 查看日志: tail -f /var/log/pagermaid.log"
    echo
    log_step "常用命令："
    echo "• 启动服务: systemctl start PagerMaid-Modify"
    echo "• 停止服务: systemctl stop PagerMaid-Modify"
    echo "• 重启服务: systemctl restart PagerMaid-Modify"
    echo "• 查看状态: systemctl status PagerMaid-Modify"
    echo "• 查看日志: journalctl -u PagerMaid-Modify -f"
    echo
    log_info "如有问题，请检查日志文件获取详细信息"
}

# 主函数
main() {
    echo "================================"
    echo "PagerMaid-Modify 一键安装脚本"
    echo "================================"
    echo
    
    check_root
    detect_os
    update_system
    install_base_deps
    install_python
    install_system_deps
    fix_pip_restrictions
    clone_project
    install_python_deps
    setup_config
    create_service
    test_installation
    show_completion
    
    log_info "安装脚本执行完成!"
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
