#!/bin/bash

# =============================================================================
# Linux System Configuration and Setup Script
# =============================================================================
# Description: Automated Linux system setup and configuration utilities
# Author: System Administrator
# Last Updated: $(date +%Y-%m-%d)
# =============================================================================

set -e  # Exit on any error

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
    print_info "Starting complete system setup..."
    
    check_root
    update_system
    configure_hostname
    configure_dns
    install_curl
    optimize_apt_sources
    install_essential_packages
    configure_timezone
    install_python_packages
    cleanup_system
    
    print_success "✅ Debian Minimal system setup completed! 🚀"
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
    echo "=== Linux System Setup Menu ==="
    echo "1. Full System Setup (Complete)"
    echo "2. Quick Setup (Basic packages only)"
    echo "3. Update System Only"
    echo "4. Install Essential Packages"
    echo "5. Configure DNS"
    echo "6. Configure Timezone"
    echo "7. Install Python Packages"
    echo "8. System Cleanup"
    echo "9. Show System Information"
    echo "0. Exit"
    echo "==============================="
}

# Main menu function
main_menu() {
    while true; do
        show_menu
        read -p "Select an option (0-9): " choice
        
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
            0) print_info "Goodbye!"; exit 0 ;;
            *) print_error "Invalid option. Please try again." ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
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

