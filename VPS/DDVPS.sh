setting_system() {
  echo "export PS1='\h:\W \u\$ '" >> /root/.bashrc
  echo "nameserver 8.8.8.8" > /etc/resolv.conf && echo "nameserver 8.8.4.4" >> /etc/resolv.conf
  apt-get update && apt-get install -y tmux mosh curl wget git sudo > /dev/null 2>&1
}

# SSH窗口及系统优化
optimize_system() {
  tmux new-session -d -s A && echo -e 'if [ -z "$TMUX" ]; then tmux attach-session -t A || tmux new-session -s A; fi' >> /root/.bashrc && source /root/.bashrc && tmux attach-session -t A
  lsb_release -a && python --version && pip --version && docker --version && docker-compose --version && free -h
}

Time_Lang_system() {
  swapon --show | grep -q 'partition' && sudo sysctl vm.swappiness=1 && echo "vm.swappiness=1" | sudo tee -a /etc/sysctl.conf
  sudo update-locale LANG=en_US.UTF-8 && sudo locale-gen en_US.UTF-8 && sudo update-locale LANG=en_US.UTF-8 && sudo timedatectl set-timezone Asia/Shanghai
}

# 更新系统及安装常见应用
update_install_apps() {
  apt-get update -y && apt-get upgrade -y && apt-get dist-upgrade -y && apt full-upgrade -y
  apt-get update && apt-get install -y tmux mosh curl wget git sudo ufw screen socat dnsutils bind9-utils cpulimit htop chrony iftop unzip tar screenfetch jq fail2ban
}

# 安装Python及Docker
install_python_docker() {
  apt update && apt install -y python3 python3-pip && ln -s /usr/bin/python3 /usr/bin/python && ln -s /usr/bin/pip3 /usr/bin/pip
  sudo apt install -y apt-transport-https ca-certificates curl software-properties-common && curl -fsSL https://test.docker.com | bash && apt update && apt install -y docker-compose
}

# 清理系统垃圾及查看系统信息
clean_system_info() {
  apt clean && apt autoclean && apt autoremove -y && rm -rf /tmp/* && history -c && history -w && docker system prune -a --volumes -f && dpkg --list | egrep -i 'linux-image|linux-headers' | awk '/^ii/{print $2}' | grep -v `uname -r` | xargs apt-get -y purge
}
setting_system
Time_Lang_system
update_install_apps
install_python_docker
clean_system
optimize_system



