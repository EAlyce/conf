#!/bin/bash

# 检测是否为root用户
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root. Please run as root or use sudo."
    exit 1
fi

# 停止所有进程锁
echo "Stopping all process locks..."
killall -9 lockfile

# 设置语言，编码默认为国际通用
echo "Setting system language and encoding to UTF-8..."
localectl set-locale LANG=en_US.UTF-8
localectl set-keymap us
timedatectl set-timezone Asia/Shanghai && timedatectl status

# 配置DNS
echo "Configuring DNS to 8.8.8.8 and 8.8.4.4..."
sed -i '/^#DNS=/a DNS=8.8.8.8 8.8.4.4' /etc/systemd/resolved.conf
systemctl restart systemd-resolved

# 更新所有包
echo "Updating all packages..."
apt update && apt full-upgrade -y


# 安装常用软件
echo "Installing common software..."
apt install -y curl wget git vim htop net-tools zip unaip jq

# 安装Docker和Docker Compose
echo "Installing Docker and Docker Compose..."
apt install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# 启用Docker服务
systemctl start docker
systemctl enable docker

# 清理垃圾包括Docker镜像
echo "Cleaning system and removing unused Docker images..."
apt autoremove -y
docker system prune -a -f

# 开放端口（示例：开放80和443端口）
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
iptables -F
# 自动检测网络接口
interfaces=$(ls /sys/class/net | grep -v lo)

# 设置 MTU 为 1500 并永久生效
for iface in $interfaces; do
    echo "Setting MTU=1500 for interface: $iface"
    ip link set dev "$iface" mtu 1500

    # 为 Debian/Ubuntu 系统永久生效，修改 /etc/network/interfaces
    if grep -q "$iface" /etc/network/interfaces; then
        sed -i "/iface $iface inet/c\iface $iface inet dhcp\n    mtu 1500" /etc/network/interfaces
    else
        echo -e "auto $iface\niface $iface inet dhcp\n    mtu 1500" | tee -a /etc/network/interfaces
    fi
done

# 重启网络服务以使更改生效
systemctl restart networking

echo "MTU for all network interfaces set to 1500."

# 安装Python3和pip3
echo "Installing Python3 and pip3..."
apt install -y python3 python3-pip

# 网络优化：开启转发、BBR、ECN，关闭虚拟内存，进程优化
echo "Optimizing network settings..."

# 开启IP转发
sysctl -w net.ipv4.ip_forward=1
bash -c 'echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf'

# 开启BBR
modprobe tcp_bbr
bash -c 'echo "tcp_bbr" >> /etc/modules-load.d/modules.conf'
bash -c 'echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf'
bash -c 'echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf'
sysctl -p

# 开启ECN
sysctl -w net.ipv4.tcp_ecn=1
bash -c 'echo "net.ipv4.tcp_ecn=1" >> /etc/sysctl.conf'

# 关闭虚拟内存
echo "Disabling swap..."
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

# 进程优化（限制最大进程数）
echo "Optimizing process limits..."
bash -c 'echo "* soft nproc 65535" >> /etc/security/limits.conf'
bash -c 'echo "* hard nproc 65535" >> /etc/security/limits.conf'

# 完成
echo "System optimization completed!"
