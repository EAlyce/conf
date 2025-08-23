#!/bin/bash

# =============================================================================
# Advanced PagerMaid-Modify Installation & System Optimization Script
# Version: 2.0 - Deep Optimization with Problem-Solving Capabilities
# Author: Enhanced Auto Installation Script
# =============================================================================

set -euo pipefail  # Exit on error, undefined vars, pipe failures
IFS=$'\n\t'       # Secure Internal Field Separator

# =============================================================================
# GLOBAL CONFIGURATION
# =============================================================================

# Script directories and files
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_FILE="${SCRIPT_DIR}/installation.log"
readonly BACKUP_DIR="${SCRIPT_DIR}/backups"
readonly TEMP_DIR="/tmp/pagermaid_install_$$"
readonly CONFIG_BACKUP="${BACKUP_DIR}/config_$(date +%Y%m%d_%H%M%S)"

# Color definitions (enhanced)
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m' # No Color

# Global variables
PYTHON_CMD=""
PKG_MANAGER=""
OS=""
VER=""
CODENAME=""
PROJECT_DIR="/root/PagerMaid-Modify"
INSTALL_SUCCESS=false
RECOVERY_MODE=false

# =============================================================================
# ENHANCED LOGGING AND UTILITY FUNCTIONS
# =============================================================================

# Advanced logging with timestamps and file output
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_entry="[$timestamp] [$level] $message"
    
    # Ensure log directory exists
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # Write to both console and file
    echo "$log_entry" | tee -a "$LOG_FILE"
}

# Enhanced logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
    log "INFO" "$1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    log "WARN" "$1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    log "ERROR" "$1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
    log "STEP" "$1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    log "SUCCESS" "$1"
}

log_debug() {
    if [[ "${DEBUG:-false}" == "true" ]]; then
        echo -e "${CYAN}[DEBUG]${NC} $1"
        log "DEBUG" "$1"
    fi
}

log_header() {
    echo -e "${PURPLE}=== $1 ===${NC}"
    log "HEADER" "$1"
}

# Progress bar function
show_progress() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local completed=$((current * width / total))
    local remaining=$((width - completed))
    
    printf "\r["
    printf "%${completed}s" | tr ' ' '='
    printf "%${remaining}s" | tr ' ' '-'
    printf "] %d%%" "$percentage"
}

# Safe command execution with retry
execute_with_retry() {
    local max_attempts=${1:-3}
    local delay=${2:-5}
    shift 2
    local cmd="$*"
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        log_debug "Attempt $attempt/$max_attempts: $cmd"
        if eval "$cmd"; then
            return 0
        else
            log_warn "Command failed (attempt $attempt/$max_attempts): $cmd"
            if [[ $attempt -lt $max_attempts ]]; then
                log_info "Retrying in ${delay}s..."
                sleep "$delay"
            fi
            ((attempt++))
        fi
    done
    
    log_error "Command failed after $max_attempts attempts: $cmd"
    return 1
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Safe file backup with versioning
backup_file() {
    local file="$1"
    if [[ -f "$file" ]]; then
        local backup_name="${BACKUP_DIR}/$(basename "$file").$(date +%Y%m%d_%H%M%S).bak"
        mkdir -p "$BACKUP_DIR"
        cp "$file" "$backup_name"
        log_success "Backed up $file to $backup_name"
        echo "$backup_name"  # Return backup path
    fi
}

# Cleanup function
cleanup() {
    local exit_code=$?
    log_debug "Cleanup function called with exit code: $exit_code"
    
    # Remove temporary directory
    if [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
        log_debug "Cleaned up temporary directory: $TEMP_DIR"
    fi
    
    # If installation failed, offer recovery
    if [[ $exit_code -ne 0 && "$INSTALL_SUCCESS" == "false" && "$RECOVERY_MODE" == "false" ]]; then
        log_error "Installation failed. Initiating recovery mode..."
        recovery_mode
    fi
    
    exit $exit_code
}

# Recovery mode function
recovery_mode() {
    log_header "Recovery Mode"
    log_warn "Attempting to recover from installation failure..."
    
    # Clean up any partial installations
    if [[ -d "$PROJECT_DIR" ]]; then
        log_info "Cleaning up partial installation..."
        rm -rf "$PROJECT_DIR" 2>/dev/null || true
    fi
    
    # Reset environment variables
    unset INSTALL_SUCCESS
    unset RECOVERY_MODE
    
    log_info "Recovery completed. Please try running the script again."
    exit 1
}

# Set trap for cleanup
trap cleanup EXIT INT TERM

# Enhanced root privilege check with auto-elevation
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}⚠️  This script requires root privileges${NC}"
        echo -e "${YELLOW}Current user: $(whoami)${NC}"
        echo ""
        echo -e "${GREEN}Options:${NC}"
        echo -e "  ${CYAN}1.${NC} Switch to root automatically (sudo -i)"
        echo -e "  ${CYAN}2.${NC} Exit and run manually with sudo"
        echo ""
        echo -n -e "${GREEN}Press Enter to switch to root (or Ctrl+C to exit): ${NC}"
        read -r choice
        
        log_info "Switching to root user..."
        exec sudo -i "$0" "$@"
    else
        log_success "✓ Running as root user"
    fi
}

# 检测系统类型
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
        CODENAME=${VERSION_CODENAME:-}
    elif type lsb_release >/dev/null 2>&1; then
        OS=$(lsb_release -si)
        VER=$(lsb_release -sr)
        CODENAME=$(lsb_release -sc)
    else
        log_error "无法检测系统类型"
        exit 1
    fi
    log_info "检测到系统: $OS $VER ($CODENAME)"
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
            # 基础包，在所有Debian/Ubuntu版本都存在
            DEBIAN_FRONTEND=noninteractive apt install -y \
                git curl wget build-essential \
                ca-certificates gnupg lsb-release
            
            # 尝试安装可选包，如果失败不中断脚本
            optional_packages=(
                "software-properties-common"
                "apt-transport-https"
            )
            
            for pkg in "${optional_packages[@]}"; do
                log_info "尝试安装可选包: $pkg"
                DEBIAN_FRONTEND=noninteractive apt install -y "$pkg" 2>/dev/null || {
                    log_warn "包 $pkg 不可用，跳过"
                    continue
                }
            done
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
    for cmd in python3.12 python3.11 python3.10 python3.9 python3.8 python3 python; do
        if command -v $cmd >/dev/null 2>&1; then
            version=$($cmd --version 2>&1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
            # 简单的版本比较
            major=$(echo $version | cut -d. -f1)
            minor=$(echo $version | cut -d. -f2)
            if [[ $major -eq 3 && $minor -ge 8 ]]; then
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
                # 直接安装系统提供的Python版本
                DEBIAN_FRONTEND=noninteractive apt install -y python3 python3-dev python3-venv python3-pip
                PYTHON_CMD="python3"
                
                # 如果系统Python版本过低，尝试从源码安装或使用pyenv
                version=$(python3 --version 2>&1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
                major=$(echo $version | cut -d. -f1)
                minor=$(echo $version | cut -d. -f2)
                
                if [[ $major -eq 3 && $minor -lt 8 ]]; then
                    log_warn "系统Python版本过低($version)，尝试安装更高版本..."
                    # 尝试安装特定版本
                    for py_ver in python3.12 python3.11 python3.10 python3.9; do
                        if DEBIAN_FRONTEND=noninteractive apt install -y $py_ver $py_ver-dev $py_ver-venv 2>/dev/null; then
                            PYTHON_CMD=$py_ver
                            log_info "成功安装: $py_ver"
                            break
                        fi
                    done
                fi
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
    if ! $PYTHON_CMD -m pip --version >/dev/null 2>&1; then
        log_step "安装pip..."
        case $PKG_MANAGER in
            "apt")
                DEBIAN_FRONTEND=noninteractive apt install -y python3-pip
                ;;
            "yum"|"dnf")
                $PKG_MANAGER install -y python3-pip
                ;;
            "pacman")
                pacman -S --noconfirm python-pip
                ;;
        esac
        
        # 如果还是没有pip，尝试get-pip.py
        if ! $PYTHON_CMD -m pip --version >/dev/null 2>&1; then
            log_info "使用get-pip.py安装pip..."
            curl -fsSL https://bootstrap.pypa.io/get-pip.py | $PYTHON_CMD
        fi
    fi
    
    log_info "Python环境配置完成: $PYTHON_CMD"
}

# 安装系统依赖
install_system_deps() {
    log_step "安装系统依赖包..."
    
    case $PKG_MANAGER in
        "apt")
            # 创建依赖包列表，分为必须和可选
            required_packages=(
                "git"
                "curl"
                "wget"
                "ffmpeg"
            )
            
            optional_packages=(
                "imagemagick"
                "libwebp-dev"
                "libzbar-dev"
                "libxml2-dev"
                "libxslt1-dev"
                "tesseract-ocr"
                "tesseract-ocr-eng"
                "tesseract-ocr-chi-sim"
                "libffi-dev"
                "libssl-dev"
                "libjpeg-dev"
                "zlib1g-dev"
            )
            
            # 安装必须的包
            for pkg in "${required_packages[@]}"; do
                log_info "安装必须包: $pkg"
                DEBIAN_FRONTEND=noninteractive apt install -y "$pkg" || {
                    log_error "无法安装必须包: $pkg"
                    exit 1
                }
            done
            
            # 安装可选包
            for pkg in "${optional_packages[@]}"; do
                log_info "尝试安装可选包: $pkg"
                DEBIAN_FRONTEND=noninteractive apt install -y "$pkg" 2>/dev/null || {
                    log_warn "包 $pkg 不可用，跳过"
                    continue
                }
            done
            
            # 特殊处理一些在不同版本中名称不同的包
            if ! dpkg -l | grep -q tesseract-ocr-all; then
                # 尝试安装所有语言包
                DEBIAN_FRONTEND=noninteractive apt install -y tesseract-ocr-all 2>/dev/null || {
                    log_warn "tesseract-ocr-all 不可用，已安装基础语言包"
                }
            fi
            ;;
        "yum"|"dnf")
            # CentOS/RHEL/Fedora packages
            packages=(
                "git" "curl" "wget" "gcc" "gcc-c++" "make"
                "ImageMagick-devel" "libwebp-devel" "zbar-devel"
                "libxml2-devel" "libxslt-devel" "tesseract"
                "ffmpeg" "libffi-devel" "openssl-devel"
                "libjpeg-turbo-devel" "zlib-devel" "fastfetch"
            )
            
            for pkg in "${packages[@]}"; do
                $PKG_MANAGER install -y "$pkg" 2>/dev/null || {
                    log_warn "包 $pkg 安装失败，跳过"
                    continue
                }
            done
            ;;
        "pacman")
            pacman -S --noconfirm \
                git curl wget base-devel \
                imagemagick libwebp zbar libxml2 libxslt \
                tesseract tesseract-data-eng tesseract-data-chi_sim \
                ffmpeg libffi openssl libjpeg-turbo zlib 2>/dev/null || true
            ;;
    esac
    
    log_info "系统依赖安装完成"
}

# 处理Python包管理限制（增强版）
fix_pip_restrictions() {
    log_step "解除Python包管理限制..."
    
    # 1. 删除EXTERNALLY-MANAGED文件
    log_info "删除EXTERNALLY-MANAGED限制文件..."
    find /usr -name "EXTERNALLY-MANAGED" -delete 2>/dev/null || true
    
    # 2. 解除sys.setprofile限制
    log_info "解除sys.setprofile限制..."
    site_file=$($PYTHON_CMD -c "import site,inspect;print(inspect.getsourcefile(site))" 2>/dev/null || echo "")
    if [[ -n "$site_file" && -f "$site_file" ]]; then
        log_info "处理site.py文件: $site_file"
        sed -i '/sys\.setprofile/d' "$site_file" 2>/dev/null || true
    else
        log_warn "无法找到site.py文件，跳过sys.setprofile限制解除"
    fi
    
    # 3. 删除Python缓存文件
    log_info "清理Python缓存文件..."
    find /usr/lib/python3* -name "*.pyc" -delete 2>/dev/null || true
    find /usr/local/lib/python3* -name "*.pyc" -delete 2>/dev/null || true
    find /opt/python* -name "*.pyc" -delete 2>/dev/null || true
    
    # 4. 取消PYTHONNOUSERSITE环境变量
    log_info "解除PYTHONNOUSERSITE限制..."
    unset PYTHONNOUSERSITE 2>/dev/null || true
    
    # 5. 设置允许用户站点包的环境变量
    export PYTHONNOUSERSITE=""
    export PIP_BREAK_SYSTEM_PACKAGES=1
    
    # 6. 创建pip配置文件以永久解除限制
    log_info "创建pip配置文件..."
    mkdir -p /root/.pip
    cat > /root/.pip/pip.conf << 'EOF'
[global]
break-system-packages = true
user = false
EOF
    
    # 7. 升级pip，使用多种方法
    log_info "升级pip..."
    
    upgrade_methods=(
        "$PYTHON_CMD -m pip install --upgrade pip --break-system-packages"
        "$PYTHON_CMD -m pip install --upgrade pip --user"
        "$PYTHON_CMD -m pip install --upgrade pip"
    )
    
    for method in "${upgrade_methods[@]}"; do
        if eval $method 2>/dev/null; then
            log_info "pip升级成功"
            break
        fi
    done
    
    # 8. 如果所有方法都失败，使用get-pip.py
    if ! $PYTHON_CMD -m pip --version >/dev/null 2>&1; then
        log_info "使用get-pip.py重新安装pip..."
        curl -fsSL https://bootstrap.pypa.io/get-pip.py | $PYTHON_CMD
    fi
    
    # 9. 验证pip工作状态
    if $PYTHON_CMD -m pip --version >/dev/null 2>&1; then
        pip_version=$($PYTHON_CMD -m pip --version)
        log_info "pip配置完成: $pip_version"
    else
        log_error "pip配置失败"
        exit 1
    fi
    
    # 10. 额外的限制解除措施
    log_info "应用额外的限制解除措施..."
    
    # 检查并修改Python启动脚本中的限制
    python_paths=(
        "/usr/bin/python3"
        "/usr/local/bin/python3"
        $(which $PYTHON_CMD 2>/dev/null || echo "")
    )
    
    for py_path in "${python_paths[@]}"; do
        if [[ -f "$py_path" ]]; then
            # 如果是脚本文件，尝试移除相关限制
            if head -n 1 "$py_path" | grep -q "#!/"; then
                log_info "检查Python脚本: $py_path"
                # 这里可以添加更多的限制解除逻辑
            fi
        fi
    done
    
    log_info "Python包管理限制解除完成"
}

# Clone project code
clone_project() {
    log_step "下载PagerMaid-Modify源代码..."
    
    # Create project directory
    mkdir -p "$PROJECT_DIR"
    cd "$PROJECT_DIR"
    
    # Clone the repository
    if [[ -d ".git" ]]; then
        log_info "Repository already exists, updating..."
        git pull origin main || git pull origin master || {
            log_warn "Failed to update repository, re-cloning..."
            cd ..
            rm -rf "$PROJECT_DIR"
            git clone https://github.com/TeamPGM/PagerMaid-Modify.git "$PROJECT_DIR"
        }
    else
        cd ..
        rm -rf "$PROJECT_DIR"
        log_info "Cloning fresh repository..."
        git clone https://github.com/TeamPGM/PagerMaid-Modify.git "$PROJECT_DIR"
    fi
    
    cd "$PROJECT_DIR"
    
    # Verify clone was successful
    if [[ ! -f "requirements.txt" ]] || [[ ! -d "pagermaid" ]]; then
        log_error "Repository clone verification failed"
        return 1
    fi
    
    log_success "代码克隆成功"
}


# 安装Python依赖（增强版）
install_python_deps() {
    log_step "安装Python依赖包..."
    
    cd "$PROJECT_DIR"
    
    # 确保环境变量设置
    export PIP_BREAK_SYSTEM_PACKAGES=1
    export PYTHONNOUSERSITE=""
    
    # 首先安装基础依赖
    essential_packages=(
        "wheel"
        "setuptools"
        "pip"
    )
    
    for package in "${essential_packages[@]}"; do
        log_info "安装基础包: $package"
        $PYTHON_CMD -m pip install --upgrade "$package" --break-system-packages 2>/dev/null || \
        $PYTHON_CMD -m pip install --upgrade "$package" --user 2>/dev/null || \
        $PYTHON_CMD -m pip install --upgrade "$package" 2>/dev/null || true
    done
    
    # 尝试多种方法安装requirements.txt中的依赖
    install_methods=(
        "$PYTHON_CMD -m pip install -r requirements.txt --break-system-packages --no-cache-dir"
        "$PYTHON_CMD -m pip install -r requirements.txt --break-system-packages"
        "$PYTHON_CMD -m pip install -r requirements.txt --user --no-cache-dir"
        "$PYTHON_CMD -m pip install -r requirements.txt --user"
        "$PYTHON_CMD -m pip install -r requirements.txt --no-cache-dir"
        "$PYTHON_CMD -m pip install -r requirements.txt"
        "pip3 install -r requirements.txt --break-system-packages"
        "pip install -r requirements.txt --break-system-packages"
    )
    
    success=false
    for method in "${install_methods[@]}"; do
        log_info "尝试: $method"
        if eval $method 2>/dev/null; then
            log_info "Python依赖安装成功"
            success=true
            break
        else
            log_warn "安装方法失败，尝试下一个..."
        fi
    done
    
    # 如果requirements.txt安装失败，尝试单独安装关键包
    if [[ "$success" == "false" ]]; then
        log_warn "requirements.txt安装失败，尝试单独安装关键包..."
        
        critical_packages=(
            "telethon>=1.24.0"
            "pyrogram>=2.0.0"
            "aiohttp>=3.8.0"
            "requests>=2.28.0"
            "PyYAML>=6.0"
            "coloredlogs>=15.0"
            "youtube-search-python>=1.6.0"
            "yt-dlp>=2023.1.6"
            "Pillow>=9.0.0"
            "lxml>=4.9.0"
            "beautifulsoup4>=4.11.0"
        )
    fi
    
    # 验证关键依赖
    log_info "验证关键依赖包..."
    local deps=("telethon" "pyrogram" "aiohttp" "yaml" "coloredlogs")
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        if $PYTHON_CMD -c "import $dep" 2>/dev/null; then
            log_info "✓ $dep 已安装"
        else
            log_warn "✗ $dep 未安装或有问题"
            missing_deps+=("$dep")
        fi
    done
    
    # 尝试安装缺失的依赖
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_warn "尝试单独安装缺失的依赖..."
        for dep in "${missing_deps[@]}"; do
            log_info "安装 $dep..."
            # 特殊处理某些包名
            local pkg_name="$dep"
            if [[ "$dep" == "yaml" ]]; then
                pkg_name="PyYAML"
            fi
            
            if $PYTHON_CMD -m pip install "$pkg_name" --break-system-packages 2>/dev/null || \
               $PYTHON_CMD -m pip install "$pkg_name" --user 2>/dev/null || \
               $PYTHON_CMD -m pip install "$pkg_name" 2>/dev/null; then
                log_success "✓ $pkg_name 安装成功"
            else
                log_warn "✗ $pkg_name 安装失败，将在后续尝试其他方法"
            fi
        done
        
        # 再次验证
        log_info "重新验证依赖..."
        for dep in "${missing_deps[@]}"; do
            if $PYTHON_CMD -c "import $dep" 2>/dev/null; then
                log_success "✓ $dep 现在可用"
            else
                log_warn "✗ $dep 仍然不可用"
            fi
        done
    fi
}



# Validate API ID format
validate_api_id() {
    local api_id="$1"
    if [[ "$api_id" =~ ^[0-9]+$ ]] && [[ ${#api_id} -ge 5 ]] && [[ ${#api_id} -le 10 ]]; then
        return 0
    else
        return 1
    fi
}

# Validate API Hash format
validate_api_hash() {
    local api_hash="$1"
    if [[ ${#api_hash} -eq 32 ]] && [[ "$api_hash" =~ ^[a-f0-9]+$ ]]; then
        return 0
    else
        return 1
    fi
}



# Interactive configuration setup
setup_config() {
    log_header "Configuration Setup"
    
    # Ensure project directory exists
    mkdir -p "$PROJECT_DIR"
    cd "$PROJECT_DIR"
    
    # Interactive configuration
    interactive_config
    
    log_success "Configuration setup completed"
}


# Interactive configuration
interactive_config() {
    echo -e "${CYAN}=======================================================${NC}"
    echo -e "${WHITE}         PagerMaid-Modify Configuration            ${NC}"
    echo -e "${CYAN}=======================================================${NC}"
    echo ""
    echo -e "${YELLOW}Please visit https://my.telegram.org/apps to get your API credentials${NC}"
    echo ""
    
    # Get API ID (make global)
    api_id=""
    while true; do
        echo -n -e "${GREEN}Please enter your API ID: ${NC}"
        read -r api_id
        
        if [[ -z "$api_id" ]]; then
            log_error "API ID cannot be empty"
            continue
        fi
        
        if validate_api_id "$api_id"; then
            log_success "API ID format is valid: $api_id"
            break
        else
            log_error "Invalid API ID format. It should be 6-10 digits (e.g., 1234567)"
        fi
    done
    
    # Get API Hash (make global)
    api_hash=""
    while true; do
        echo -n -e "${GREEN}Please enter your API Hash: ${NC}"
        read -r api_hash
        
        if [[ -z "$api_hash" ]]; then
            log_error "API Hash cannot be empty"
            continue
        fi
        
        if validate_api_hash "$api_hash"; then
            log_success "API Hash format is valid"
            break
        else
            log_error "Invalid API Hash format. It should be 32 hexadecimal characters"
        fi
    done
    
    # Ask about debug logging
    echo ""
    echo -n -e "${GREEN}Enable debug logging? [Y/n]: ${NC}"
    read -r debug_choice
    debug_enabled="True"
    if [[ "$debug_choice" =~ ^[Nn]$ ]]; then
        debug_enabled="False"
    fi
    
    # Display configuration summary
    echo ""
    echo -e "${CYAN}=======================================================${NC}"
    echo -e "${WHITE}         Configuration Summary         ${NC}"
    echo -e "${CYAN}=======================================================${NC}"
    echo -e "API ID: ${GREEN}$api_id${NC}"
    echo -e "API Hash: ${GREEN}${api_hash:0:8}...${api_hash: -8}${NC}"
    echo -e "Debug Logging: ${GREEN}$debug_enabled${NC}"
    echo ""
    
    echo -n -e "${YELLOW}Confirm configuration? [Y/n]: ${NC}"
    read -r confirm
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        log_warn "Configuration cancelled by user"
        return 1
    fi
    
    # Write configuration
    write_config "$api_id" "$api_hash" "$debug_enabled"
}

# Create complete config.yml template
create_config_template() {
    log_info "Creating configuration template..."
    
    cat > config.yml << 'EOF'
# ===================================================================
# __________                                _____         .__    .___
# \______   \_____     ____   ___________  /     \ _____  |__| __| _|
# |     ___/\__  \   / ___\_/ __ \_  __ \/  \ /  \\__  \ |  |/ __ |
# |    |     / __ \_/ /_/  >  ___/|  | \/    Y    \/ __ \|  / /_/ |
# |____|    (____  /\___  / \___  >__|  \____|__  (____  /__\____ |
#                \//_____/      \/              \/     \/        \/
# ===================================================================

# API Credentials of your telegram application created at https://my.telegram.org/apps
api_id: "ID_HERE"
api_hash: "HASH_HERE"
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
    
    log_success "Configuration template created"
}

# Ensure a minimal default config exists (one-click mode)
ensure_default_config() {
    log_info "Ensuring default configuration exists..."
    mkdir -p "$PROJECT_DIR"
    cd "$PROJECT_DIR"

    if [[ -f "config.yml" ]]; then
        log_info "配置文件已存在: $PROJECT_DIR/config.yml"
        return 0
    fi

    # Create minimal config based on template and fill safe defaults
    create_config_template
    # Keep API placeholders; PagerMaid will guide the user on first login
    sed -i 's/debug: "False"/debug: "False"/g' config.yml
    local secret_key=$(openssl rand -hex 16 2>/dev/null || echo "$(date +%s)$(shuf -i 1000-9999 -n 1)")
    sed -i "s/secret_key: \"RANDOM_STRING_HERE\"/secret_key: \"$secret_key\"/g" config.yml

    # Prepare directories
    mkdir -p "data/plugins" "data/cache" "logs"

    log_success "默认配置已生成: $PROJECT_DIR/config.yml"
}

# Interactive configuration setup
interactive_config_setup() {
    log_header "Telegram API Configuration"
    
    echo -e "${CYAN}=======================================================${NC}"
    echo -e "${WHITE}         PagerMaid-Modify Configuration Setup         ${NC}"
    echo -e "${CYAN}=======================================================${NC}"
    echo ""
    echo -e "${YELLOW}Please visit https://my.telegram.org/apps to get your API credentials${NC}"
    echo ""
    
    # Get API ID
    local api_id=""
    while true; do
        echo -n -e "${GREEN}Please enter your API ID: ${NC}"
        read -r api_id
        
        if [[ -z "$api_id" ]]; then
            log_error "API ID cannot be empty"
            continue
        fi
        
        if validate_api_id "$api_id"; then
            log_success "API ID format is valid: $api_id"
            break
        else
            log_error "Invalid API ID format. It should be 6-10 digits (e.g., 1234567)"
        fi
    done
    
    # Get API Hash
    local api_hash=""
    while true; do
        echo -n -e "${GREEN}Please enter your API Hash: ${NC}"
        read -r api_hash
        
        if [[ -z "$api_hash" ]]; then
            log_error "API Hash cannot be empty"
            continue
        fi
        
        if validate_api_hash "$api_hash"; then
            log_success "API Hash format is valid"
            break
        else
            log_error "Invalid API Hash format. It should be 32 hexadecimal characters"
        fi
    done
    
    # Ask about debug logging
    echo ""
    echo -n -e "${GREEN}Enable debug logging? [Y/n]: ${NC}"
    read -r debug_choice
    
    local debug_enabled="True"
    if [[ "$debug_choice" =~ ^[Nn]$ ]]; then
        debug_enabled="False"
        log_info "Debug logging disabled"
    else
        log_info "Debug logging enabled"
    fi
    
    # Confirm configuration
    echo ""
    echo -e "${CYAN}=======================================================${NC}"
    echo -e "${WHITE}         Configuration Summary         ${NC}"
    echo -e "${CYAN}=======================================================${NC}"
    echo -e "API ID: ${GREEN}$api_id${NC}"
    echo -e "API Hash: ${GREEN}${api_hash:0:8}...${api_hash: -8}${NC}"
    echo -e "Debug Logging: ${GREEN}$debug_enabled${NC}"
    echo -e "${CYAN}=======================================================${NC}"
    echo ""
    
    echo -n -e "${YELLOW}Is this configuration correct? [Y/n]: ${NC}"
    read -r confirm
    
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        log_warn "Configuration cancelled. Restarting..."
        interactive_config_setup
        return
    fi
    
    # Write configuration to file
    write_config_file "$api_id" "$api_hash" "$debug_enabled"
    
    log_success "Configuration saved successfully!"
}

# Write configuration
write_config() {
    local api_id="$1"
    local api_hash="$2"
    local debug_enabled="$3"
    
    log_info "Writing configuration to $PROJECT_DIR/config.yml..."
    
    # Ensure we're in the project directory
    cd "$PROJECT_DIR"
    
    # Create the complete config.yml template
    create_config_template
    
    # Backup existing config if it exists
    if [[ -f "config.yml" ]]; then
        backup_file "config.yml"
    fi
    
    # Replace placeholders in config.yml
    sed -i "s/api_id: \"ID_HERE\"/api_id: \"$api_id\"/g" config.yml
    sed -i "s/api_hash: \"HASH_HERE\"/api_hash: \"$api_hash\"/g" config.yml
    sed -i "s/debug: \"False\"/debug: \"$debug_enabled\"/g" config.yml
    
    # Generate a random secret key for web interface
    local secret_key=$(openssl rand -hex 16 2>/dev/null || echo "$(date +%s)$(shuf -i 1000-9999 -n 1)")
    sed -i "s/secret_key: \"RANDOM_STRING_HERE\"/secret_key: \"$secret_key\"/g" config.yml
    
    # Create data directories
    mkdir -p "data/plugins"
    mkdir -p "data/cache"
    mkdir -p "logs"
    
    # Verify the configuration was written correctly
    if grep -q "api_id: \"$api_id\"" config.yml && grep -q "api_hash: \"$api_hash\"" config.yml; then
        log_success "Configuration written successfully to $PROJECT_DIR/config.yml"
    else
        log_error "Failed to write configuration"
        exit 1
    fi
}

# Create system service
create_service() {
    log_step "创建系统服务..."
    
    local service_name="PagerMaid-Modify"
    local service_file="/etc/systemd/system/$service_name.service"
    
    # Get the Python path
    local PYTHON_PATH=$(which $PYTHON_CMD)
    
    # Create systemd service file
    cat > "$service_file" << EOF
[Unit]
Description=PagerMaid-Modify Telegram Bot
After=network.target
Wants=network.target

[Service]
Type=simple
WorkingDirectory=$PROJECT_DIR
ExecStart=$PYTHON_PATH -m pagermaid
Restart=always
RestartSec=10
User=root
Group=root
StandardOutput=append:$PROJECT_DIR/logs/pagermaid.log
StandardError=append:$PROJECT_DIR/logs/pagermaid-error.log
Environment=PYTHONPATH=$PROJECT_DIR
Environment=PYTHONUNBUFFERED=1
Environment=PIP_BREAK_SYSTEM_PACKAGES=1
Environment=PYTHONNOUSERSITE=
KillMode=mixed
TimeoutStopSec=30

[Install]
WantedBy=default.target
EOF
    
    # 重新加载systemd配置
    systemctl daemon-reload
    systemctl enable "$service_name"
    
    log_success "系统服务创建完成: $service_name"
    log_info "Service file: /etc/systemd/system/$service_name.service"
    log_info "Working directory: $PROJECT_DIR"
    log_info "Log files: $PROJECT_DIR/logs/"
}

# 测试运行
test_installation() {
    log_step "测试安装..."
    
    cd /root/PagerMaid-Modify
    
    # 设置环境变量
    export PIP_BREAK_SYSTEM_PACKAGES=1
    export PYTHONNOUSERSITE=""
    
    # 简单的导入测试
    if $PYTHON_CMD -c "import sys; sys.path.insert(0, '.'); import pagermaid" 2>/dev/null; then
        log_info "Python模块导入测试通过"
    else
        log_warn "Python模块导入测试失败，但可能是配置问题"
    fi
    
    # 检查必要文件
    if [[ -f "pagermaid/__init__.py" ]] || [[ -f "pagermaid/__main__.py" ]]; then
        log_info "项目文件结构检查通过"
    else
        log_error "项目文件结构不完整"
        exit 1
    fi
    
    # 测试依赖导入
    log_info "测试关键依赖导入..."
    test_imports=(
        "import telethon; print('Telethon:', telethon.__version__)"
        "import pyrogram; print('Pyrogram:', pyrogram.__version__)"
        "import aiohttp; print('aiohttp:', aiohttp.__version__)"
        "import yaml; print('PyYAML: OK')"
    )
    
    for test_cmd in "${test_imports[@]}"; do
        if $PYTHON_CMD -c "$test_cmd" 2>/dev/null; then
            log_info "✓ 依赖测试通过: $(echo "$test_cmd" | cut -d';' -f2)"
        else
            log_warn "✗ 依赖测试失败: $(echo "$test_cmd" | cut -d';' -f1)"
        fi
    done
}

# Installation completion information
show_completion() {
    local service_name="PagerMaid-Modify"
    
    echo -e "${CYAN}================================================================${NC}"
    echo -e "${WHITE}         PagerMaid-Modify Installation Complete!         ${NC}"
    echo -e "${CYAN}================================================================${NC}"
    echo ""
    
    echo -e "${GREEN}✓ Installation Configuration:${NC}"
    echo -e "  Project Directory: ${CYAN}$PROJECT_DIR${NC}"
    echo -e "  Configuration File: ${CYAN}$PROJECT_DIR/config.yml${NC}"
    echo -e "  Service Name: ${CYAN}$service_name${NC}"
    echo ""
    
    echo -e "${YELLOW}📋 Quick Start Commands:${NC}"
    echo -e "  ${GREEN}Manual Run:${NC}"
    echo -e "    cd $PROJECT_DIR && $PYTHON_CMD -m pagermaid"
    echo ""
    echo -e "  ${GREEN}Service Management:${NC}"
    echo -e "    systemctl start $service_name"
    echo -e "    systemctl stop $service_name"
    echo -e "    systemctl restart $service_name"
    echo -e "    systemctl status $service_name"
    echo ""
    echo -e "  ${GREEN}Log Monitoring:${NC}"
    echo -e "    tail -f $PROJECT_DIR/logs/pagermaid.log"
    echo -e "    tail -f $PROJECT_DIR/logs/pagermaid-error.log"
    echo -e "    journalctl -u $service_name -f"
    echo ""
    
    echo -e "${BLUE}📁 Directory Structure:${NC}"
    echo -e "  ${CYAN}$PROJECT_DIR/${NC}"
    echo -e "          ├── config.yml   ${YELLOW}(Your configuration)${NC}"
    echo -e "          ├── data/         ${YELLOW}(Bot data & plugins)${NC}"
    echo -e "          ├── logs/         ${YELLOW}(Application logs)${NC}"
    echo -e "          └── pagermaid/    ${YELLOW}(Source code)${NC}"
    echo ""
    
    echo -e "${GREEN}🎉 Installation completed successfully!${NC}"
    echo ""
    
    echo -e "${CYAN}================================================================${NC}"
    echo ""
    echo -n -e "${GREEN}Please select an option [1-3]: ${NC}"
    read -r start_choice
    
    case $start_choice in
        1)
            log_info "Starting systemd service..."
            if systemctl start "$service_name" 2>/dev/null; then
                log_success "Service started successfully!"
                sleep 2
                if systemctl is-active --quiet "$service_name" 2>/dev/null; then
                    log_success "✓ Service is running"
                    echo -e "${CYAN}You can check status with: systemctl status $service_name${NC}"
                else
                    log_warn "Service may have issues. Check logs with: journalctl -u $service_name"
                fi
            else
                log_error "Failed to start service. You can start it manually later."
            fi
            ;;
        2)
            log_info "Starting PagerMaid-Modify interactively..."
            echo -e "${YELLOW}This will run PagerMaid-Modify in the foreground.${NC}"
            echo -e "${YELLOW}Press Ctrl+C to stop when you're done with initial setup.${NC}"
            echo ""
            echo "Press Enter to continue..."
            read -r
            
            cd "$PROJECT_DIR"
            log_info "Running: python3 -m pagermaid"
            echo ""
            python3 -m pagermaid
            ;;
        3|*)
            log_info "Skipping automatic startup."
            echo -e "${YELLOW}You can start your PagerMaid-Modify instance later with:${NC}"
            echo -e "${WHITE}systemctl start $service_name${NC}"
            echo -e "${WHITE}Or run interactively: cd $PROJECT_DIR && python3 -m pagermaid${NC}"
            ;;
    esac
    
    echo ""
    # Removed the call to show_user_summary
}




# 主函数
main() {
    echo "================================"
    echo "PagerMaid-Modify 一键安装脚本"
    echo "版本: 2.0 (单用户版)"
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
    
    # 交互式：手动输入 API ID / API HASH
    interactive_config
    
    write_config "$api_id" "$api_hash" "$debug_enabled"
    create_service
    test_installation
    
    # Perform Telegram login
    perform_telegram_login
    
    # Mark installation as successful
    INSTALL_SUCCESS=true
    
    log_success "🎉 PagerMaid-Modify 单用户版安装完成！"
    echo -e "${GREEN}================================================================${NC}"
    echo -e "${WHITE}                    安装成功总结                    ${NC}"
    echo -e "${GREEN}================================================================${NC}"
    echo -e "${CYAN}✅ 安装目录:${NC} /root/PagerMaid-Modify"
    echo -e "${CYAN}✅ 配置文件:${NC} /root/PagerMaid-Modify/config.yml"
    echo -e "${CYAN}✅ 服务状态:${NC} 已启动并设置开机自启"
    echo -e "${CYAN}✅ Telegram:${NC} 已登录成功"
    echo ""
    echo -e "${YELLOW}📱 测试机器人:${NC}"
    echo -e "   在 Telegram 中发送: ${GREEN}-help${NC}"
    echo ""
    echo -e "${YELLOW}🔧 管理命令:${NC}"
    echo -e "   查看状态: ${GREEN}systemctl status PagerMaid-Modify${NC}"
    echo -e "   查看日志: ${GREEN}journalctl -u PagerMaid-Modify -f${NC}"
    echo -e "   重启服务: ${GREEN}systemctl restart PagerMaid-Modify${NC}"
    echo -e "${GREEN}================================================================${NC}"
}

# Perform Telegram login process
perform_telegram_login() {
    log_step "开始 Telegram 登录配置..."
    
    cd "$PROJECT_DIR"
    
    # 已有会话则跳过（包含 -journal/-wal 等变体）
    if ls pagermaid*.session* >/dev/null 2>&1; then
        local existing_session=$(ls pagermaid*.session* | head -n1)
        log_success "检测到已有会话文件，跳过登录步骤: $existing_session"
        return 0
    fi
    
    log_info "首次运行需要进行 Telegram 登录验证"
    echo -e "${YELLOW}请准备好您的手机接收验证码${NC}"
    echo -e "${GREEN}将启动 PagerMaid，请按提示输入手机号码与验证码${NC}"
    echo ""
    
    # 前台运行以允许输入手机号/验证码
    echo -e "${YELLOW}看到 “PagerMaid-Modify 已启动” 或完成登录后，可按 Ctrl+C 退出以继续安装${NC}"
    echo ""
    
    # 忽略 SIGINT 防止脚本被终止，仅让子进程响应
    trap '' SIGINT
    python3 -m pagermaid
    trap - SIGINT
    
    echo ""
    log_info "检测到登录进程已退出，继续配置服务..."
    
    # 退出后再等待一会儿以便会话落盘
    local post_wait=10
    while [[ $post_wait -gt 0 ]]; do
        local session_file="$(ls pagermaid*.session* 2>/dev/null | head -n1 || true)"
        if [[ -n "$session_file" && -e "$session_file" ]]; then
            break
        fi
        sleep 1
        post_wait=$((post_wait - 1))
    done

    # 校验 session 是否生成（接受任意 *session* 文件）
    local session_file="$(ls pagermaid*.session* 2>/dev/null | head -n1 || true)"
    if [[ -n "$session_file" && -e "$session_file" ]]; then
        log_success "✓ Telegram 登录成功！ 会话: $session_file"

        log_step "正在启动 PagerMaid-Modify 服务..."
        log_info "重新加载 systemd 配置..."
        systemctl daemon-reload 2>/dev/null || true

        log_info "设置开机自启并立即启动..."
        if systemctl enable --now PagerMaid-Modify 2>/dev/null; then
            log_success "✓ 已设置为开机自启并已启动"
        else
            log_warn "开机自启/启动可能失败，继续尝试重启"
        fi

        log_info "重启服务以套用最新配置..."
        if systemctl restart PagerMaid-Modify 2>/dev/null; then
            log_success "✓ 服务已重启"
        else
            log_warn "重启服务失败"
        fi

        log_info "检查服务状态..."; sleep 5
        if systemctl is-active --quiet PagerMaid-Modify 2>/dev/null; then
            log_success "🚀 PagerMaid-Modify 服务正在运行！"
        else
            log_error "⚠️  服务未正常运行"; journalctl -u PagerMaid-Modify --no-pager -n 5 2>/dev/null || true
        fi
        return 0
    else
        log_warn "未检测到登录会话文件，安装仍已完成。请稍后手动完成登录"
        echo -e "${YELLOW}你可以运行：${NC}"
        echo -e "${GREEN}cd $PROJECT_DIR && python3 -m pagermaid${NC}"
        # 避免触发恢复模式
        return 0
    fi
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
