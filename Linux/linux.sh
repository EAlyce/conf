#!/bin/bash

# =============================================================================
# Linux System Configuration and Setup Script
# =============================================================================
# Description: Automated Linux system setup and configuration utilities
# Author: System Administrator
# Last Updated: $(date +%Y-%m-%d)
# =============================================================================

set -e  # Exit on any error

# Non-interactive for Debian apt operations
export DEBIAN_FRONTEND=noninteractive

# =============================================================================
# CONFIGURATION VARIABLES
# =============================================================================

# DNS Configuration
DNS_SERVERS="8.8.8.8 8.8.4.4"
TIMEZONE="Asia/Shanghai"

# Essential packages list
ESSENTIAL_PACKAGES=(
    "sudo" "vim" "nano" "curl" "wget" "git" "gnupg" "lsb-release" 
    "ca-certificates" "net-tools" "dnsutils" "build-essential"
    "python3" "python3-pip" "python3-venv" "tzdata" "util-linux"
    "htop" "tree" "unzip" "zip" "tar" "rsync" "man-db"
    "netcat-openbsd" "tcpdump" "iproute2" "iputils-ping"
    "less" "screen" "tmux" "ffmpeg"
)

# Python packages for media processing
PYTHON_PACKAGES=(
    "youtube-search-python"
    "yt-dlp"
    "aiohttp"
    "mutagen"
)

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Print colored output
print_info() {
    echo -e "\033[1;34m[INFO]\033[0m $1"
}

print_success() {
    echo -e "\033[1;32m[SUCCESS]\033[0m $1"
}

print_warning() {
    echo -e "\033[1;33m[WARNING]\033[0m $1"
}

print_error() {
    echo -e "\033[1;31m[ERROR]\033[0m $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root"
        exit 1
    fi
}

# =============================================================================
# SYSTEM UPDATE FUNCTIONS
# =============================================================================

# Update system packages
update_system() {
    print_info "Updating system packages..."
    
    apt-get update -y
    apt-get upgrade -y
    apt-get dist-upgrade -y
    apt full-upgrade -y
    
    print_success "System packages updated successfully"
}

# Configure DNS settings
configure_dns() {
    print_info "Configuring DNS settings..."
    
    # Backup existing resolv.conf
    if [[ -f /etc/resolv.conf ]]; then
        cp /etc/resolv.conf /etc/resolv.conf.backup
    fi
    
    # Set new DNS servers
    rm -f /etc/resolv.conf
    mkdir -p /etc
    echo -e "nameserver 8.8.8.8\nnameserver 8.8.4.4" > /etc/resolv.conf
    
    print_success "DNS configured with Google DNS servers"
}

# Configure hostname
configure_hostname() {
    print_info "Setting hostname..."
    hostnamectl set-hostname $(hostname)
    print_success "Hostname configured"
}

# =============================================================================
# PACKAGE INSTALLATION FUNCTIONS
# =============================================================================

# Install curl (prerequisite)
install_curl() {
    print_info "Installing curl..."
    apt install -y curl
    print_success "Curl installed"
}

# Optimize APT sources for better speed
optimize_apt_sources() {
    print_info "Optimizing APT sources for better download speed..."
    
    # Install netselect-apt for source optimization
    apt update && apt install -y netselect-apt
    
    # Generate optimized sources.list for Debian Bookworm
    netselect-apt bookworm -o /etc/apt/sources.list
    apt update
    
    print_success "APT sources optimized"
}

# Install essential packages
install_essential_packages() {
    print_info "Installing essential packages..."
    
    apt update
    apt upgrade -y
    
    # Install packages in batches to handle potential failures
    for package in "${ESSENTIAL_PACKAGES[@]}"; do
        print_info "Installing $package..."
        apt install -y "$package" || print_warning "Failed to install $package"
    done
    
    print_success "Essential packages installation completed"
}

# Configure timezone
configure_timezone() {
    print_info "Configuring timezone to $TIMEZONE..."
    
    timedatectl set-timezone "$TIMEZONE"
    ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
    
    print_info "Current date and time:"
    date
    timedatectl status
    
    # Show hardware clock if available
    if command -v hwclock >/dev/null; then
        hwclock --show
    else
        print_warning "hwclock not available in this VM"
    fi
    
    print_success "Timezone configured successfully"
}

# Install Python packages for media processing
install_python_packages() {
    print_info "Installing Python packages for media processing..."
    
    for package in "${PYTHON_PACKAGES[@]}"; do
        print_info "Installing Python package: $package"
        pip install --break-system-packages "$package" || print_warning "Failed to install $package"
    done
    
    print_success "Python packages installed"
}

# 新增：一键最小化补全（中文简化文案）
debian_minimal_bundle() {
    print_info "执行 Debian 最小化补全..."
    apt update
    apt upgrade -y
    apt install -y sudo vim nano curl wget git gnupg lsb-release \
        ca-certificates net-tools dnsutils build-essential \
        python3 python3-pip python3-venv tzdata util-linux \
        htop tree unzip zip tar rsync man-db \
        netcat-openbsd tcpdump iproute2 iputils-ping \
        less screen tmux
    timedatectl set-timezone "$TIMEZONE"
    ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
    date
    timedatectl status
    if command -v hwclock >/dev/null; then
        hwclock --show
    else
        echo "⚠️ 本环境无 hwclock"
    fi
    echo "✅ Debian Minimal 已补全 🚀"
}

# 稳定性增强组件
install_stability_addons() {
    print_info "安装稳定性组件..."
    apt update
    apt install -y \
        apt-utils software-properties-common \
        openssl jq bash-completion \
        openssh-server ethtool \
        rsyslog logrotate cron psmisc \
        socat mtr-tiny traceroute \
        dirmngr xz-utils zstd \
        iptables-persistent
    systemctl enable --now ssh || true
    systemctl enable --now rsyslog || true
    systemctl enable --now cron || true
    update-ca-certificates || true
    print_success "稳定性组件已安装"
}

# 配置中文本地化
configure_locale_zh_cn() {
    print_info "配置中文 Locale..."
    apt install -y locales
    sed -i 's/^# *zh_CN.UTF-8 UTF-8/zh_CN.UTF-8 UTF-8/' /etc/locale.gen
    locale-gen
    update-locale LANG=zh_CN.UTF-8
    export LANG=zh_CN.UTF-8
    print_success "中文 Locale 已配置"
}

# 启用自动安全更新
enable_unattended_upgrades() {
    print_info "启用自动安全更新..."
    apt install -y unattended-upgrades
    printf 'APT::Periodic::Update-Package-Lists "1";\nAPT::Periodic::Unattended-Upgrade "1";\n' > /etc/apt/apt.conf.d/20auto-upgrades
    systemctl enable --now unattended-upgrades || true
    print_success "自动更新已启用"
}

# 启用 Chrony 时间同步
enable_chrony() {
    print_info "启用 Chrony 时间同步..."
    apt install -y chrony
    systemctl enable --now chrony || true
    print_success "Chrony 已启用"
}

# 开放端口并持久化保存
open_ports_and_persist() {
    print_info "开放端口并保存规则..."
    local ports=(8964 23556 23456 40000)
    for p in "${ports[@]}"; do
        iptables -C INPUT -p tcp --dport "$p" -j ACCEPT 2>/dev/null || \
        iptables -I INPUT -p tcp --dport "$p" -j ACCEPT
    done
    # 安装并使用 iptables-persistent 保存
    if ! command -v netfilter-persistent >/dev/null; then
        apt update
        apt install -y iptables-persistent
    fi
    mkdir -p /etc/iptables
    iptables-save > /etc/iptables/rules.v4
    if command -v netfilter-persistent >/dev/null; then
        netfilter-persistent save || true
        netfilter-persistent reload || true
    fi
    print_success "端口已开放并持久化"
}

# =============================================================================
# SYSTEM OPTIMIZATION FUNCTIONS
# =============================================================================

# Clean up system
cleanup_system() {
    print_info "Cleaning up system..."
    
    apt autoremove -y
    apt autoclean
    
    # Clean temporary files
    rm -rf /tmp/*
    rm -rf /var/tmp/*
    
    print_success "System cleanup completed"
}

# Display system information
show_system_info() {
    print_info "System Information:"
    echo "===================="
    echo "Hostname: $(hostname)"
    echo "OS: $(lsb_release -d | cut -f2)"
    echo "Kernel: $(uname -r)"
    echo "Architecture: $(uname -m)"
    echo "Uptime: $(uptime -p)"
    echo "Memory: $(free -h | grep Mem | awk '{print $3"/"$2}')"
    echo "Disk Usage: $(df -h / | tail -1 | awk '{print $3"/"$2" ("$5")"}')"
    echo "Timezone: $(timedatectl | grep "Time zone" | awk '{print $3}')"
    echo "===================="
}

# =============================================================================
# MAIN INSTALLATION FUNCTIONS
# =============================================================================

# Complete system setup
full_system_setup() {
    print_info "开始完整系统配置..."
    
    check_root
    install_curl
    configure_hostname
    configure_dns
    
    # 一键最小化补全
    debian_minimal_bundle
    
    # 稳定性增强：常用组件、本地化与自动更新、时间同步
    install_stability_addons
    configure_locale_zh_cn
    enable_unattended_upgrades
    enable_chrony
    
    # 明确新增：iptables 与 ffmpeg
    print_info "安装 iptables..."
    apt install -y iptables
    print_info "安装 ffmpeg..."
    apt install -y ffmpeg
    
    # 明确新增：yt-dlp 强制重装（兼容 pip/pip3）
    print_info "安装/重装 yt-dlp..."
    if command -v pip >/dev/null; then
        sudo pip install --upgrade --force-reinstall yt-dlp --break-system-packages
    else
        sudo pip3 install --upgrade --force-reinstall yt-dlp --break-system-packages
    fi
    
    # 明确新增：3x-ui 安装
    print_info "安装 3x-ui..."
    bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh) || print_warning "3x-ui 安装脚本执行失败"
    
    # 新增：开放端口并持久化
    open_ports_and_persist

    cleanup_system
    
    print_success "✅ Debian Minimal 已补全 🚀"
    show_system_info
}

# Quick setup (minimal packages only)
quick_setup() {
    print_info "Starting quick setup..."
    
    check_root
    update_system
    configure_dns
    install_curl
    
    # Install only basic packages
    apt install -y sudo vim curl wget git python3 python3-pip
    
    print_success "✅ Quick setup completed! 🚀"
}

# =============================================================================
# MENU SYSTEM
# =============================================================================

show_menu() {
    echo ""
    echo "=== Linux 系统一键配置菜单 ==="
    echo "1. 完整配置（推荐）"
    echo "2. 快速配置（基础）"
    echo "3. 仅更新系统"
    echo "4. 安装常用软件"
    echo "5. 配置 DNS"
    echo "6. 配置时区"
    echo "7. 安装 Python 包"
    echo "8. 清理系统"
    echo "9. 显示系统信息"
    echo "0. 退出"
    echo "==============================="
}

# Main menu function
main_menu() {
    while true; do
        show_menu
        read -p "请选择(0-9): " choice
        
        case $choice in
            1) full_system_setup ;;
            2) quick_setup ;;
            3) update_system ;;
            4) install_essential_packages ;;
            5) configure_dns ;;
            6) configure_timezone ;;
            7) install_python_packages ;;
            8) cleanup_system ;;
            9) show_system_info ;;
            0) print_info "再见！"; exit 0 ;;
            *) print_error "无效选项，请重试。" ;;
        esac
        
        echo ""
        read -p "回车继续..."
    done
}

# =============================================================================
# SCRIPT EXECUTION
# =============================================================================

# Main function
main() {
    # If no arguments provided, show menu
    if [[ $# -eq 0 ]]; then
        main_menu
    else
        # Allow direct function calls
        case $1 in
            "full"|"complete") full_system_setup ;;
            "quick"|"basic") quick_setup ;;
            "update") update_system ;;
            "info") show_system_info ;;
            "cleanup") cleanup_system ;;
            *) 
                echo "Usage: $0 [full|quick|update|info|cleanup]"
                echo "Or run without arguments for interactive menu"
                exit 1
                ;;
        esac
    fi
}

# Only run main if script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

