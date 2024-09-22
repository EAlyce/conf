#!/bin/bash

# 立即终止遇到的任何错误
set -e

# 检查命令是否存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 安装缺失的包
install_if_not_exists() {
    if ! command_exists "$1"; then
        echo "安装 $1..."
        apt install -y "$1"
    else
        echo "$1 已安装."
    fi
}

# 检查是否为 root 用户
[ "$(id -u)" -ne 0 ] && { echo "请以 root 权限运行此脚本。"; exit 1; }

# 停止所有进程锁
echo "停止所有进程锁..."
install_if_not_exists psmisc
killall -9 lockfile || true

# 设置系统语言和时区
echo "设置系统语言和时区..."
install_if_not_exists locales
locale-gen en_US.UTF-8
update-locale LANG=en_US.UTF-8

install_if_not_exists tzdata
timedatectl set-timezone Asia/Shanghai || echo "设置时区失败，请手动设置。"
timedatectl status

# 配置DNS
echo "配置DNS到 8.8.8.8 和 8.8.4.4..."
systemctl enable systemd-resolved
systemctl start systemd-resolved
sed -i '/^#DNS=/c DNS=8.8.8.8 8.8.4.4' /etc/systemd/resolved.conf
systemctl restart systemd-resolved
systemd-resolve --status | grep "DNS Servers"

# 更新系统
echo "更新系统..."
apt update && apt full-upgrade -y

# 安装常用软件
echo "安装常用软件..."
apt install -y curl wget git vim htop net-tools zip unzip jq

# 安装Docker和Docker Compose
if ! command_exists docker || ! docker compose version &>/dev/null; then
    echo "安装Docker及Compose..."
    apt install -y apt-transport-https ca-certificates curl software-properties-common gnupg
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt update
    apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    systemctl enable --now docker
fi

# 清理系统和Docker镜像
echo "清理系统和Docker镜像..."
apt autoremove -y
docker system prune -a -f

# 验证Docker是否正常运行
docker run hello-world || { echo "Docker 运行异常"; exit 1; }

# 开放端口
install_if_not_exists iptables
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
iptables -F

# 设置网络接口MTU为1500
for iface in $(ls /sys/class/net | grep -v lo); do
    echo "设置接口 $iface 的MTU为1500"
    ip link set dev "$iface" mtu 1500
done
systemctl restart networking

# 安装Python3和pip3
echo "安装Python3和pip3..."
apt install -y python3 python3-pip

# 网络优化
echo "网络优化设置..."
install_if_not_exists procps
sysctl -w net.ipv4.ip_forward=1
modprobe tcp_bbr
echo -e "net.core.default_qdisc=fq\nnet.ipv4.tcp_congestion_control=bbr\nnet.ipv4.ip_forward=1\nnet.ipv4.tcp_ecn=1" >> /etc/sysctl.conf
sysctl -p

# 禁用swap
echo "禁用swap..."
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

# 进程优化
echo "进程优化..."
echo "* soft nproc 65535" >> /etc/security/limits.conf
echo "* hard nproc 65535" >> /etc/security/limits.conf

echo "系统优化完成！"
