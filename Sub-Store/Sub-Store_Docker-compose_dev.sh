#!/usr/bin/env bash

# Sub-Store Auto Deploy Script - Professional Version
# Author: System Administrator
# Version: 3.0
# Description: Automated Sub-Store deployment with enhanced features

set -euo pipefail

# 配置常量
readonly SCRIPT_NAME="Sub-Store Deploy"
readonly SCRIPT_VERSION="3.0"
readonly SERVICE_NAME="sub-store"
readonly SERVICE_PORT="3001"
readonly DATA_DIR="/opt/sub-store"
readonly CONFIG_DIR="/etc/sub-store"
readonly LOG_DIR="/var/log/sub-store"
readonly COMPOSE_FILE="docker-compose.yml"
readonly ENV_FILE=".env"

# 颜色定义
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m'

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_step() {
    echo -e "${PURPLE}[STEP]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_debug() {
    if [[ "${DEBUG:-0}" == "1" ]]; then
        echo -e "${CYAN}[DEBUG]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
    fi
}

# 显示横幅
show_banner() {
    clear
    echo -e "${GREEN}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║    ███████╗██╗   ██╗██████╗       ███████╗████████╗     ║
║    ██╔════╝██║   ██║██╔══██╗      ██╔════╝╚══██╔══╝     ║
║    ███████╗██║   ██║██████╔╝█████╗███████╗   ██║        ║
║    ╚════██║██║   ██║██╔══██╗╚════╝╚════██║   ██║        ║
║    ███████║╚██████╔╝██████╔╝      ███████║   ██║        ║
║    ╚══════╝ ╚═════╝ ╚═════╝       ╚══════╝   ╚═╝        ║
║                                                          ║
║              Professional Auto Deploy Tool               ║
║                       Version 3.0                       ║
╚══════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}\n"
}

# 检查操作系统
check_os() {
    log_step "检查操作系统兼容性"
    
    if [[ ! -f /etc/os-release ]]; then
        log_error "无法识别操作系统"
        exit 1
    fi
    
    source /etc/os-release
    
    case "$ID" in
        ubuntu|debian)
            log_success "检测到 $PRETTY_NAME，支持的操作系统"
            PACKAGE_MANAGER="apt"
            ;;
        centos|rhel|fedora|rocky|almalinux)
            log_success "检测到 $PRETTY_NAME，支持的操作系统" 
            PACKAGE_MANAGER="yum"
            if command -v dnf &>/dev/null; then
                PACKAGE_MANAGER="dnf"
            fi
            ;;
        *)
            log_warning "检测到 $PRETTY_NAME，未完全测试的操作系统，但将尝试继续"
            PACKAGE_MANAGER="apt"
            ;;
    esac
}

# 检查root权限
check_root() {
    log_step "检查运行权限"
    
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要root权限运行"
        log_info "请使用 sudo 执行: sudo $0"
        exit 1
    fi
    
    log_success "权限检查通过"
}

# 检查系统资源
check_system_resources() {
    log_step "检查系统资源"
    
    # 检查内存
    local mem_total
    mem_total=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
    
    if [[ $mem_total -lt 512 ]]; then
        log_warning "系统内存较低 (${mem_total}MB)，建议至少512MB"
    else
        log_success "内存检查通过 (${mem_total}MB)"
    fi
    
    # 检查磁盘空间
    local disk_avail
    disk_avail=$(df / | awk 'NR==2 {print int($4/1024)}')
    
    if [[ $disk_avail -lt 1024 ]]; then
        log_warning "可用磁盘空间较低 (${disk_avail}MB)，建议至少1GB"
    else
        log_success "磁盘空间检查通过 (${disk_avail}MB可用)"
    fi
    
    # 检查网络连接
    if ! ping -c 1 -W 5 8.8.8.8 &>/dev/null; then
        log_error "网络连接检查失败，请检查网络设置"
        exit 1
    fi
    log_success "网络连接检查通过"
}

# 创建必要目录
create_directories() {
    log_step "创建必要目录"
    
    local dirs=("$DATA_DIR" "$CONFIG_DIR" "$LOG_DIR")
    
    for dir in "${dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir"
            chmod 755 "$dir"
            log_info "已创建目录: $dir"
        fi
    done
    
    log_success "目录创建完成"
}

# 更新系统包
update_system() {
    log_step "更新系统包管理器"
    
    case "$PACKAGE_MANAGER" in
        apt)
            apt-get update -qq || {
                log_error "系统包更新失败"
                exit 1
            }
            ;;
        yum|dnf)
            $PACKAGE_MANAGER makecache -q || {
                log_error "系统包更新失败"
                exit 1
            }
            ;;
    esac
    
    log_success "系统包管理器更新完成"
}

# 安装基础依赖
install_dependencies() {
    log_step "安装基础依赖包"
    
    local deps=("curl" "wget" "openssl" "cron" "ufw")
    local missing_deps=()
    
    # 检查缺失的依赖
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_info "安装缺失的依赖: ${missing_deps[*]}"
        
        case "$PACKAGE_MANAGER" in
            apt)
                apt-get install -y "${missing_deps[@]}" || {
                    log_error "依赖安装失败"
                    exit 1
                }
                ;;
            yum|dnf)
                $PACKAGE_MANAGER install -y "${missing_deps[@]}" || {
                    log_error "依赖安装失败"
                    exit 1
                }
                ;;
        esac
    fi
    
    log_success "基础依赖安装完成"
}

# 安装Docker
install_docker() {
    log_step "检查并安装 Docker"
    
    if command -v docker &>/dev/null; then
        local docker_version
        docker_version=$(docker --version | cut -d' ' -f3 | cut -d',' -f1)
        log_success "Docker 已安装 (版本: $docker_version)"
        return 0
    fi
    
    log_info "开始安装 Docker..."
    
    # 添加Docker官方GPG密钥和仓库
    case "$PACKAGE_MANAGER" in
        apt)
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
            apt-get update -qq
            apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin
            ;;
        yum|dnf)
            $PACKAGE_MANAGER install -y yum-utils
            yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            $PACKAGE_MANAGER install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin
            ;;
    esac
    
    # 启动并启用Docker服务
    systemctl enable docker
    systemctl start docker
    
    # 验证安装
    if ! docker --version &>/dev/null; then
        log_error "Docker 安装失败"
        exit 1
    fi
    
    log_success "Docker 安装完成"
}

# 安装Docker Compose
install_docker_compose() {
    log_step "检查并安装 Docker Compose"
    
    if docker compose version &>/dev/null; then
        local compose_version
        compose_version=$(docker compose version --short)
        log_success "Docker Compose 已安装 (版本: $compose_version)"
        return 0
    fi
    
    log_info "Docker Compose 插件未找到，检查传统版本..."
    
    if command -v docker-compose &>/dev/null; then
        local compose_version
        compose_version=$(docker-compose --version | cut -d' ' -f3 | cut -d',' -f1)
        log_success "Docker Compose 已安装 (传统版本: $compose_version)"
        return 0
    fi
    
    log_info "开始安装 Docker Compose..."
    
    # 获取最新版本号
    local latest_version
    latest_version=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')
    
    if [[ -z "$latest_version" ]]; then
        log_warning "无法获取最新版本，使用默认版本"
        latest_version="v2.24.0"
    fi
    
    # 下载并安装
    curl -L "https://github.com/docker/compose/releases/download/${latest_version}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    
    # 创建符号链接
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    
    # 验证安装
    if ! docker-compose --version &>/dev/null; then
        log_error "Docker Compose 安装失败"
        exit 1
    fi
    
    log_success "Docker Compose 安装完成"
}

# 获取公网IP
get_public_ip() {
    log_step "获取公网IP地址"
    
    local ip_services=(
        "https://ifconfig.me/ip"
        "https://ipinfo.io/ip"
        "https://icanhazip.com"
        "https://ipecho.net/plain"
        "https://ident.me"
        "https://checkip.amazonaws.com"
    )
    
    local public_ip=""
    local timeout=5
    
    for service in "${ip_services[@]}"; do
        log_debug "尝试从 $service 获取IP"
        
        if public_ip=$(curl -sS --connect-timeout $timeout --max-time $timeout "$service" 2>/dev/null); then
            # 验证IP格式
            if [[ "$public_ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
                # 验证每个数字段是否在有效范围内
                local valid=true
                IFS='.' read -ra ADDR <<< "$public_ip"
                for i in "${ADDR[@]}"; do
                    if [[ $i -gt 255 ]]; then
                        valid=false
                        break
                    fi
                done
                
                if $valid; then
                    log_success "获取到公网IP: $public_ip"
                    echo "$public_ip"
                    return 0
                fi
            fi
        fi
        
        sleep 1
    done
    
    log_error "无法获取公网IP地址，请检查网络连接"
    exit 1
}

# 生成安全密钥
generate_secret_key() {
    log_step "生成安全密钥"
    
    local secret_key
    secret_key=$(openssl rand -hex 32)
    
    if [[ ${#secret_key} -ne 64 ]]; then
        log_error "密钥生成失败"
        exit 1
    fi
    
    log_success "安全密钥生成完成"
    echo "$secret_key"
}

# 配置防火墙
configure_firewall() {
    log_step "配置防火墙规则"
    
    if ! command -v ufw &>/dev/null; then
        log_warning "UFW未安装，跳过防火墙配置"
        return 0
    fi
    
    # 启用UFW
    ufw --force enable &>/dev/null || true
    
    # 允许SSH
    ufw allow ssh &>/dev/null || true
    
    # 允许Sub-Store端口
    ufw allow $SERVICE_PORT/tcp &>/dev/null || true
    
    log_success "防火墙规则配置完成"
}

# 清理旧部署
cleanup_old_deployment() {
    log_step "清理旧的部署"
    
    # 停止并删除旧容器
    if docker ps -a --format "table {{.Names}}" | grep -q "^${SERVICE_NAME}$"; then
        log_info "停止旧容器..."
        docker stop "$SERVICE_NAME" &>/dev/null || true
        docker rm "$SERVICE_NAME" &>/dev/null || true
    fi
    
    # 停止docker-compose服务
    if [[ -f "$COMPOSE_FILE" ]]; then
        log_info "停止旧的docker-compose服务..."
        docker compose -p "$SERVICE_NAME" down &>/dev/null 2>&1 || true
    fi
    
    # 清理未使用的镜像
    log_info "清理未使用的Docker镜像..."
    docker image prune -f &>/dev/null || true
    
    log_success "旧部署清理完成"
}

# 创建配置文件
create_config_files() {
    local secret_key="$1"
    local public_ip="$2"
    
    log_step "创建配置文件"
    
    # 创建环境变量文件
    cat > "$ENV_FILE" << EOF
# Sub-Store Configuration
# Generated on $(date)

# Basic Settings
SUB_STORE_PORT=$SERVICE_PORT
SUB_STORE_SECRET_KEY=$secret_key
PUBLIC_IP=$public_ip

# Backend Settings
SUB_STORE_BACKEND_UPLOAD_CRON=55 23 * * *
SUB_STORE_FRONTEND_BACKEND_PATH=/$secret_key

# Data Directories
SUB_STORE_DATA_DIR=$DATA_DIR
SUB_STORE_LOG_DIR=$LOG_DIR

# Performance Settings
SUB_STORE_CACHE_SIZE=100
SUB_STORE_MAX_CONNECTIONS=1000

# Security Settings
SUB_STORE_RATE_LIMIT=100
SUB_STORE_CORS_ORIGIN=*
EOF
    
    # 创建Docker Compose文件
    cat > "$COMPOSE_FILE" << EOF
# Sub-Store Docker Compose Configuration
# Generated on $(date)

name: ${SERVICE_NAME}-app

services:
  ${SERVICE_NAME}:
    image: xream/sub-store:latest
    container_name: ${SERVICE_NAME}
    hostname: ${SERVICE_NAME}
    restart: unless-stopped
    
    environment:
      - SUB_STORE_BACKEND_UPLOAD_CRON=\${SUB_STORE_BACKEND_UPLOAD_CRON}
      - SUB_STORE_FRONTEND_BACKEND_PATH=\${SUB_STORE_FRONTEND_BACKEND_PATH}
      - TZ=Asia/Shanghai
      
    ports:
      - "\${SUB_STORE_PORT}:\${SUB_STORE_PORT}"
      
    volumes:
      - \${SUB_STORE_DATA_DIR}:/opt/app/data
      - \${SUB_STORE_LOG_DIR}:/opt/app/logs
      
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:\${SUB_STORE_PORT}"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
      
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"
        
    security_opt:
      - no-new-privileges:true
      
    user: "1000:1000"
    
    networks:
      - sub-store-network

networks:
  sub-store-network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
EOF
    
    # 设置文件权限
    chmod 600 "$ENV_FILE"
    chmod 644 "$COMPOSE_FILE"
    
    log_success "配置文件创建完成"
}

# 部署服务
deploy_service() {
    log_step "部署Sub-Store服务"
    
    # 拉取最新镜像
    log_info "拉取最新Docker镜像..."
    if ! docker compose --env-file "$ENV_FILE" pull; then
        log_error "镜像拉取失败"
        exit 1
    fi
    
    # 启动服务
    log_info "启动Sub-Store服务..."
    if ! docker compose --env-file "$ENV_FILE" -p "$SERVICE_NAME" up -d; then
        log_error "服务启动失败"
        exit 1
    fi
    
    log_success "服务部署完成"
}

# 配置自动更新
setup_auto_update() {
    log_step "配置自动更新任务"
    
    # 创建更新脚本
    local update_script="/usr/local/bin/sub-store-update.sh"
    
    cat > "$update_script" << 'EOF'
#!/bin/bash
# Sub-Store Auto Update Script

set -euo pipefail

LOG_FILE="/var/log/sub-store/auto-update.log"
WORK_DIR="/opt/sub-store"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

cd "$WORK_DIR" || exit 1

log "开始自动更新Sub-Store..."

# 拉取最新镜像
if docker compose pull; then
    log "镜像拉取成功"
else
    log "镜像拉取失败"
    exit 1
fi

# 重启服务
if docker compose -p sub-store up -d; then
    log "服务重启成功"
else
    log "服务重启失败"
    exit 1
fi

# 清理旧镜像
docker image prune -f &>/dev/null || true

log "自动更新完成"
EOF
    
    chmod +x "$update_script"
    
    # 添加到crontab
    local cron_job="0 3 * * 0 $update_script >/dev/null 2>&1"
    
    # 检查cron是否已存在
    if ! crontab -l 2>/dev/null | grep -q "$update_script"; then
        (crontab -l 2>/dev/null || true; echo "$cron_job") | crontab -
        log_success "自动更新任务已配置 (每周日凌晨3点)"
    else
        log_info "自动更新任务已存在"
    fi
    
    # 确保cron服务运行
    systemctl enable cron &>/dev/null || systemctl enable crond &>/dev/null || true
    systemctl start cron &>/dev/null || systemctl start crond &>/dev/null || true
}

# 等待服务启动
wait_for_service() {
    local public_ip="$1"
    local max_attempts=60
    local attempt=0
    
    log_step "等待服务启动"
    
    while [[ $attempt -lt $max_attempts ]]; do
        if curl -s --connect-timeout 3 "http://127.0.0.1:$SERVICE_PORT" >/dev/null 2>&1; then
            log_success "服务已启动并响应"
            return 0
        fi
        
        ((attempt++))
        echo -ne "\r等待服务启动... ($attempt/$max_attempts)"
        sleep 2
    done
    
    echo
    log_warning "服务在预期时间内未响应，但可能仍在启动中"
    return 1
}

# 显示部署信息
show_deployment_info() {
    local public_ip="$1"
    local secret_key="$2"
    
    echo -e "\n${GREEN}"
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║                    部署成功！                           ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    echo -e "${WHITE}📋 Sub-Store 服务信息:${NC}"
    echo -e "   ${CYAN}管理面板:${NC} http://$public_ip:$SERVICE_PORT"
    echo -e "   ${CYAN}后端地址:${NC} http://$public_ip:$SERVICE_PORT/$secret_key"
    echo -e "   ${CYAN}数据目录:${NC} $DATA_DIR"
    echo -e "   ${CYAN}日志目录:${NC} $LOG_DIR"
    
    echo -e "\n${WHITE}🔧 管理命令:${NC}"
    echo -e "   ${CYAN}查看状态:${NC} docker compose -p $SERVICE_NAME ps"
    echo -e "   ${CYAN}查看日志:${NC} docker compose -p $SERVICE_NAME logs -f"
    echo -e "   ${CYAN}重启服务:${NC} docker compose -p $SERVICE_NAME restart"
    echo -e "   ${CYAN}停止服务:${NC} docker compose -p $SERVICE_NAME down"
    
    echo -e "\n${WHITE}📝 配置文件:${NC}"
    echo -e "   ${CYAN}环境配置:${NC} $ENV_FILE"
    echo -e "   ${CYAN}Compose文件:${NC} $COMPOSE_FILE"
    
    echo -e "\n${WHITE}🔄 自动更新:${NC}"
    echo -e "   ${CYAN}更新脚本:${NC} /usr/local/bin/sub-store-update.sh"
    echo -e "   ${CYAN}更新时间:${NC} 每周日凌晨3点"
    
    echo -e "\n${YELLOW}⚠️  重要提醒:${NC}"
    echo -e "   • 请妥善保存后端密钥: ${RED}$secret_key${NC}"
    echo -e "   • 建议定期备份数据目录: ${CYAN}$DATA_DIR${NC}"
    echo -e "   • 确保防火墙开放端口: ${CYAN}$SERVICE_PORT${NC}"
    
    echo
}

# 创建卸载脚本
create_uninstall_script() {
    log_step "创建卸载脚本"
    
    local uninstall_script="/usr/local/bin/sub-store-uninstall.sh"
    
    cat > "$uninstall_script" << 'EOF'
#!/bin/bash
# Sub-Store Uninstall Script

set -euo pipefail

echo "正在卸载Sub-Store..."

# 停止服务
docker compose -p sub-store down 2>/dev/null || true

# 删除容器和镜像
docker rm -f sub-store 2>/dev/null || true
docker rmi xream/sub-store 2>/dev/null || true

# 删除数据（可选）
read -p "是否删除所有数据？[y/N]: " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -rf /opt/sub-store
    rm -rf /etc/sub-store
    rm -rf /var/log/sub-store
    echo "数据已删除"
fi

# 删除配置文件
rm -f docker-compose.yml .env

# 删除cron任务
crontab -l 2>/dev/null | grep -v "sub-store-update.sh" | crontab - || true

# 删除脚本
rm -f /usr/local/bin/sub-store-update.sh
rm -f /usr/local/bin/sub-store-uninstall.sh

echo "Sub-Store 卸载完成"
EOF
    
    chmod +x "$uninstall_script"
    log_success "卸载脚本已创建: $uninstall_script"
}

# 主函数
main() {
    # 设置错误处理
    trap 'log_error "脚本在第 $LINENO 行执行失败"; exit 1' ERR
    trap 'log_info "脚本被用户中断"; exit 130' INT
    
    # 显示横幅
    show_banner
    
    # 执行部署步骤
    check_os
    check_root
    check_system_resources
    create_directories
    update_system
    install_dependencies
    install_docker
    install_docker_compose
    
    # 获取配置信息
    local public_ip
    public_ip=$(get_public_ip)
    
    local secret_key
    secret_key=$(generate_secret_key)
    
    # 配置和部署
    cleanup_old_deployment
    create_config_files "$secret_key" "$public_ip"
    configure_firewall
    deploy_service
    setup_auto_update
    create_uninstall_script
    
    # 等待服务启动
    wait_for_service "$public_ip"
    
    # 显示部署信息
    show_deployment_info "$public_ip" "$secret_key"
    
    log_success "Sub-Store 部署完成！"
}

# 运行主函数
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
