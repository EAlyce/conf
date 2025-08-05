#!/bin/bash

# Docker Network Fix Script - Professional Version
# Author: System Administrator
# Version: 2.0
# Description: Comprehensive Docker network troubleshooting and repair script

set -euo pipefail  # 严格错误处理模式

# 颜色定义
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${PURPLE}[STEP]${NC} $1"
}

# 检查是否以root权限运行
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要root权限运行。请使用 sudo 执行。"
        exit 1
    fi
}

# 检查Docker是否安装
check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker 未安装。请先安装 Docker。"
        exit 1
    fi
    log_success "Docker 已安装"
}

# 检查Docker服务状态
check_docker_service() {
    if ! systemctl is-active --quiet docker; then
        log_warning "Docker 服务未运行，正在启动..."
        systemctl start docker || {
            log_error "无法启动 Docker 服务"
            exit 1
        }
    fi
    log_success "Docker 服务正在运行"
}

# 备份现有配置
backup_config() {
    local backup_dir="/tmp/docker-backup-$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    log_step "备份现有配置到 $backup_dir"
    
    # 备份daemon.json
    if [[ -f /etc/docker/daemon.json ]]; then
        cp /etc/docker/daemon.json "$backup_dir/"
        log_info "已备份 daemon.json"
    fi
    
    # 备份网络配置
    if [[ -d /var/lib/docker/network ]]; then
        cp -r /var/lib/docker/network "$backup_dir/" 2>/dev/null || true
        log_info "已备份网络配置"
    fi
    
    echo "$backup_dir" > /tmp/docker-backup-path
    log_success "配置备份完成"
}

# 设置DNS配置
setup_dns() {
    log_step "配置 Docker DNS 设置"
    
    local daemon_json="/etc/docker/daemon.json"
    local backup_suffix=".backup-$(date +%s)"
    
    # 备份现有daemon.json
    if [[ -f "$daemon_json" ]]; then
        cp "$daemon_json" "${daemon_json}${backup_suffix}"
        log_info "已备份现有 daemon.json"
    fi
    
    # 创建新的daemon.json配置
    cat > "$daemon_json" << 'EOF'
{
    "dns": ["8.8.8.8", "1.1.1.1", "223.5.5.5"],
    "dns-opts": ["ndots:2", "timeout:3"],
    "dns-search": [],
    "storage-driver": "overlay2",
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3"
    },
    "live-restore": true,
    "userland-proxy": false,
    "experimental": false,
    "metrics-addr": "127.0.0.1:9323",
    "default-address-pools": [
        {
            "base": "172.17.0.0/12",
            "size": 24
        }
    ]
}
EOF
    
    log_success "DNS 配置已更新"
}

# 清理容器和网络
cleanup_containers_networks() {
    log_step "清理 Docker 容器和网络"
    
    # 获取运行中的容器
    local running_containers
    running_containers=$(docker ps -q 2>/dev/null || true)
    
    if [[ -n "$running_containers" ]]; then
        log_info "停止运行中的容器..."
        docker stop $running_containers || log_warning "部分容器停止失败"
        sleep 2
    else
        log_info "没有运行中的容器"
    fi
    
    # 清理未使用的网络
    log_info "清理未使用的网络..."
    docker network prune -f 2>/dev/null || log_warning "网络清理失败"
    
    # 尝试删除自定义网络（保留默认网络）
    local custom_networks
    custom_networks=$(docker network ls --format "{{.Name}}" | grep -v -E "^(bridge|host|none)$" || true)
    
    if [[ -n "$custom_networks" ]]; then
        log_info "删除自定义网络: $custom_networks"
        echo "$custom_networks" | xargs -I {} docker network rm {} 2>/dev/null || log_warning "部分自定义网络删除失败"
    fi
    
    log_success "容器和网络清理完成"
}

# 重置网络配置
reset_network_config() {
    log_step "重置 Docker 网络配置"
    
    # 停止Docker服务
    log_info "停止 Docker 服务..."
    systemctl stop docker || log_error "无法停止 Docker 服务"
    
    # 清理网络配置文件
    if [[ -d /var/lib/docker/network ]]; then
        log_info "删除网络配置缓存..."
        rm -rf /var/lib/docker/network
    fi
    
    # 清理iptables规则
    log_info "清理 Docker iptables 规则..."
    iptables -t nat -F DOCKER 2>/dev/null || true
    iptables -t filter -F DOCKER 2>/dev/null || true
    iptables -t filter -F DOCKER-ISOLATION-STAGE-1 2>/dev/null || true
    iptables -t filter -F DOCKER-ISOLATION-STAGE-2 2>/dev/null || true
    
    log_success "网络配置重置完成"
}

# 重启Docker服务
restart_docker() {
    log_step "重启 Docker 服务"
    
    # 重新加载systemd配置
    systemctl daemon-reload
    
    # 重启Docker
    systemctl restart docker || {
        log_error "Docker 服务重启失败"
        exit 1
    }
    
    # 等待服务完全启动
    local retry_count=0
    local max_retries=30
    
    while ! docker info &>/dev/null && [[ $retry_count -lt $max_retries ]]; do
        sleep 1
        ((retry_count++))
    done
    
    if [[ $retry_count -eq $max_retries ]]; then
        log_error "Docker 服务启动超时"
        exit 1
    fi
    
    log_success "Docker 服务重启成功"
}

# 验证网络配置
verify_network() {
    log_step "验证 Docker 网络配置"
    
    # 显示网络列表
    echo -e "\n${CYAN}当前 Docker 网络配置:${NC}"
    docker network ls
    
    # 显示bridge网络详情
    echo -e "\n${CYAN}Bridge 网络详情:${NC}"
    docker network inspect bridge --format='{{range .IPAM.Config}}{{.Subnet}} {{.Gateway}}{{end}}' || log_warning "无法获取bridge网络详情"
}

# 网络连通性测试
test_connectivity() {
    log_step "测试网络连通性"
    
    local test_image="busybox:latest"
    
    # 预拉取测试镜像
    log_info "准备测试镜像..."
    docker pull $test_image &>/dev/null || {
        log_warning "无法拉取测试镜像，使用现有镜像"
    }
    
    # 测试基本网络连通性
    echo -e "\n${CYAN}测试 1: Ping IP 地址 (8.8.8.8)${NC}"
    if docker run --rm $test_image ping -c 3 -W 5 8.8.8.8 &>/dev/null; then
        log_success "✓ IP 连通性测试通过"
    else
        log_error "✗ IP 连通性测试失败"
        return 1
    fi
    
    # 测试DNS解析
    echo -e "\n${CYAN}测试 2: DNS 解析 (google.com)${NC}"
    if docker run --rm $test_image nslookup google.com &>/dev/null; then
        log_success "✓ DNS 解析测试通过"
    else
        log_error "✗ DNS 解析测试失败"
        return 1
    fi
    
    # 测试HTTP连接
    echo -e "\n${CYAN}测试 3: HTTP 连接 (httpbin.org)${NC}"
    if docker run --rm $test_image wget -q --spider --timeout=10 http://httpbin.org/get &>/dev/null; then
        log_success "✓ HTTP 连接测试通过"
    else
        log_error "✗ HTTP 连接测试失败"
        return 1
    fi
    
    log_success "所有网络连通性测试通过！"
}

# 显示系统信息
show_system_info() {
    log_step "系统信息摘要"
    
    echo -e "\n${CYAN}Docker 版本信息:${NC}"
    docker version --format 'Client: {{.Client.Version}} | Server: {{.Server.Version}}'
    
    echo -e "\n${CYAN}Docker 系统信息:${NC}"
    docker system df
    
    echo -e "\n${CYAN}网络接口信息:${NC}"
    ip addr show docker0 2>/dev/null | head -5 || log_info "docker0 接口不存在"
}

# 恢复配置函数
restore_config() {
    if [[ -f /tmp/docker-backup-path ]]; then
        local backup_dir
        backup_dir=$(cat /tmp/docker-backup-path)
        log_warning "如需恢复配置，请运行: cp $backup_dir/daemon.json /etc/docker/"
    fi
}

# 主函数
main() {
    echo -e "${GREEN}"
    echo "╔═══════════════════════════════════════╗"
    echo "║     Docker Network Fix Tool v2.0     ║"
    echo "║     Professional Network Repair      ║"
    echo "╚═══════════════════════════════════════╝"
    echo -e "${NC}\n"
    
    # 设置错误处理
    trap 'log_error "脚本执行失败，正在清理..."; restore_config; exit 1' ERR
    trap 'log_info "脚本被中断"; restore_config; exit 130' INT
    
    # 执行检查和修复步骤
    check_root
    check_docker
    check_docker_service
    backup_config
    setup_dns
    cleanup_containers_networks
    reset_network_config
    restart_docker
    verify_network
    
    # 网络测试
    if test_connectivity; then
        show_system_info
        
        echo -e "\n${GREEN}"
        echo "╔═══════════════════════════════════════╗"
        echo "║            修复完成！                ║"
        echo "║     Docker 网络已成功修复            ║"
        echo "╚═══════════════════════════════════════╝"
        echo -e "${NC}"
        
        # 清理临时文件
        rm -f /tmp/docker-backup-path
        
    else
        log_error "网络连通性测试失败，可能需要手动检查网络配置"
        restore_config
        exit 1
    fi
}

# 运行主函数
main "$@"
