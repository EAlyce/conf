#vps开机一条龙

#DD  密码： MoeClub.org 端口 22
bash <(wget --no-check-certificate -qO- 'https://www.moeelf.com/attachment/LinuxShell/InstallNET.sh') -d 12 -v 64 -a

# 打断进程
pkill -9 apt || true && pkill -9 dpkg || true
rm -f /var/lib/dpkg/lock-frontend /var/lib/apt/lists/lock
dpkg --configure -a

# 标识符优化
echo "export PS1='\h:\W \u\$ '" >> /root/.bashrc

# 修改Debian系统DNS
sed -i '/nameserver/s/\S\+/8.8.8.8 8.8.4.4 1.1.1.1 1.0.0.1/' /etc/resolv.conf

# SSH窗口优化
apt-get update && apt-get install -y tmux mosh curl wget git sudo && tmux new-session -d -s A && echo -e 'if [ -z "$TMUX" ]; then tmux attach-session -t A || tmux new-session -s A; fi' >> /root/.bashrc && source /root/.bashrc && tmux attach-session -t A

# 优先使用虚拟内存
swapon --show | grep -q 'partition' && sudo sysctl vm.swappiness=1 && echo "vm.swappiness=1" | sudo tee -a /etc/sysctl.conf

# 系统编码语言时区
sudo update-locale LANG=en_US.UTF-8 && sudo locale-gen en_US.UTF-8 && sudo update-locale LANG=en_US.UTF-8 && sudo timedatectl set-timezone Asia/Shanghai

# 更新所有包
apt-get update -y && apt-get upgrade -y && apt-get dist-upgrade -y && apt full-upgrade -y

# 安装常见应用
apt-get update && apt-get install -y ufw screen socat dnsutils bind9-utils cpulimit htop chrony iftop unzip tar screenfetch jq fail2ban

# 安装 python pip
apt update && apt install -y python3 python3-pip && ln -s /usr/bin/python3 /usr/bin/python && ln -s /usr/bin/pip3 /usr/bin/pip

# 安装Docker
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common && curl -fsSL https://test.docker.com | bash && apt update && apt install -y docker-compose

# 清理系统垃圾
apt clean && apt autoclean && apt autoremove -y && rm -rf /tmp/* && history -c && history -w && docker system prune -a --volumes -f && dpkg --list | egrep -i 'linux-image|linux-headers' | awk '/^ii/{print $2}' | grep -v `uname -r` | xargs apt-get -y purge

# 查看系统信息
lsb_release -a && python --version && pip --version && docker --version && docker-compose --version && free -h



