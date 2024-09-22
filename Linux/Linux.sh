#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install a package if it's not already installed
install_if_not_exists() {
    if ! command_exists "$1"; then
        echo "Installing $1..."
        apt install -y "$1"
    else
        echo "$1 is already installed."
    fi
}

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root. Please run as root or use sudo."
    exit 1
fi

# Stop all process locks
echo "Stopping all process locks..."
install_if_not_exists psmisc
killall -9 lockfile || true

echo "Setting system language and timezone..."
install_if_not_exists locales
locale-gen en_US.UTF-8
update-locale LANG=en_US.UTF-8

install_if_not_exists tzdata
timedatectl set-timezone Asia/Shanghai || echo "Failed to set timezone. Please set it manually."

# Display current time settings
timedatectl status

echo "Configuring DNS to 8.8.8.8 and 8.8.4.4..."

# 确保 systemd-resolved 服务已安装并启动
systemctl enable systemd-resolved
systemctl start systemd-resolved

# 自动配置 DNS
sed -i '/^#DNS=/c DNS=8.8.8.8 8.8.4.4' /etc/systemd/resolved.conf

# 重启 systemd-resolved 服务以应用更改
systemctl restart systemd-resolved

# 确认配置是否生效
systemd-resolve --status | grep "DNS Servers"


# Update all packages
echo "Updating all packages..."
apt update && apt full-upgrade -y

# Install common software
echo "Installing common software..."
apt install -y curl wget git vim htop net-tools zip unzip jq

# Docker and Docker Compose installation
if command_exists docker && (command_exists docker-compose || docker compose version &>/dev/null); then
    echo "Both Docker and Docker Compose are already installed. Skipping installation."
else
    echo "Installing Docker and/or Docker Compose..."
    install_if_not_exists apt-transport-https
    install_if_not_exists ca-certificates
    install_if_not_exists curl
    install_if_not_exists software-properties-common
    install_if_not_exists gnupg
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt update
    apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

    systemctl start docker
    systemctl enable docker

    if ! systemctl is-active --quiet docker; then
        echo "Docker service is not running"
        exit 1
    fi

    echo "Docker and Docker Compose installation completed successfully"
fi

# Clean up system and Docker images
echo "Cleaning system and removing unused Docker images..."
apt autoremove -y
docker system prune -a -f

# Check if Docker is functioning correctly
if ! docker run hello-world; then
    echo "Docker is not functioning correctly"
    exit 1
fi

# Open ports
install_if_not_exists iptables
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
iptables -F

# Set MTU to 1500 for all interfaces
interfaces=$(ls /sys/class/net | grep -v lo)
for iface in $interfaces; do
    echo "Setting MTU=1500 for interface: $iface"
    ip link set dev "$iface" mtu 1500
    if grep -q "$iface" /etc/network/interfaces; then
        sed -i "/iface $iface inet/c\iface $iface inet dhcp\n    mtu 1500" /etc/network/interfaces
    else
        echo -e "auto $iface\niface $iface inet dhcp\n    mtu 1500" | tee -a /etc/network/interfaces
    fi
done

systemctl restart networking

# Install Python3 and pip3
echo "Installing Python3 and pip3..."
apt install -y python3 python3-pip

# Network optimization
echo "Optimizing network settings..."
install_if_not_exists procps
sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf

modprobe tcp_bbr
echo "tcp_bbr" >> /etc/modules-load.d/modules.conf
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf

sysctl -w net.ipv4.tcp_ecn=1
echo "net.ipv4.tcp_ecn=1" >> /etc/sysctl.conf

sysctl -p

# Disable swap
echo "Disabling swap..."
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

# Process optimization
echo "Optimizing process limits..."
echo "* soft nproc 65535" >> /etc/security/limits.conf
echo "* hard nproc 65535" >> /etc/security/limits.conf

echo "System optimization completed!"
