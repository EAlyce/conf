# 🐧 Linux 服务器快速配置与管理指南

本指南汇集了常用的 Linux 服务器设置与管理命令，旨在提供一个快速、便捷的参考。

---

## 🚀 系统初始化

在开始之前，请先更新系统并安装基础工具。
清理残留配置
```
dpkg --purge $(dpkg -l | grep '^rc' | awk '{print $2}')
```

### 1. 更新系统软件包

保持系统更新是确保安全与稳定性的第一步。

```bash
apt-get update -y && apt-get upgrade -y && apt-get dist-upgrade -y && apt full-upgrade -y
```
系统补全
```
apt update && apt upgrade -y && apt install -y sudo vim nano curl wget git gnupg lsb-release ca-certificates net-tools dnsutils build-essential python3 python3-pip python3-venv tzdata util-linux htop tree unzip zip tar rsync man-db netcat-openbsd tcpdump iproute2 iputils-ping less screen tmux && timedatectl set-timezone Asia/Shanghai && ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && date && timedatectl status && (command -v hwclock >/dev/null && hwclock --show || echo "⚠️ hwclock not available in this VM") && echo "✅ Debian Minimal 已补全 🚀"
```
### 2. 安装常用工具

安装一些日常管理和开发中不可或缺的命令行工具。
环境变量优化
```
grep -qxF 'export PATH=$PATH:/root/bin' /etc/profile || echo 'export PATH=$PATH:/root/bin' >> /etc/profile && source /etc/profile
```
```
apt update && apt install -y curl git zip unzip wget sudo netcat-openbsd vim nano cron tmux file python3-pip
```

文件同步工具
```
bash <(curl -fsSL https://github.com/EAlyce/conf/raw/refs/heads/main/Linux/syncthing.sh)
```
自动生成密钥并发送到Telegram bot
```
bash <(curl -fsSL https://github.com/EAlyce/conf/raw/refs/heads/main/Linux/sshkey.sh)
```
WARP
```
wget -N https://gitlab.com/fscarmen/warp/-/raw/main/menu.sh && bash menu.sh
```
解除Python限制
```
SITE_FILE=$(python3 -c "import site,inspect; print(inspect.getsourcefile(site))" 2>/dev/null) && [ -n "$SITE_FILE" ] && [ -f "$SITE_FILE" ] && sudo cp "$SITE_FILE" "$SITE_FILE.backup.$(date +%s)" && sudo sed -i '/sys\.setprofile/d' "$SITE_FILE" && sudo find /usr/lib/python3* /usr/local/lib/python3* /opt/*/lib/python3* -name "*.pyc" -type f -delete 2>/dev/null && sudo find /usr/lib/python3* /usr/local/lib/python3* -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null && unset PYTHONNOUSERSITE PYTHONPATH && echo "✅ Python环境清理完成"
```
安装依赖
```
sudo pip install --break-system-packages youtube-search-python yt-dlp aiohttp mutagen&& \
sudo apt install -y ffmpeg
```

## 🛠️ 应用环境配置

为您的应用程序配置必要的运行环境。

### 1. 安装 Node.js

此命令将安装 Node.js 20.x 版本，并初始化一个 `npm` 项目及常用依赖。

```bash
curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
apt install -y nodejs && \
npm init -y && \
npm install node-fetch cheerio
```

### 2. 安装 PM2 进程管理器

PM2 是一个强大的 Node.js 进程管理器，可以帮助您保持应用持续在线。

```bash
npm install -g pm2
```

---

## 🐳 Docker 管理

管理 Docker 容器和镜像的实用命令。

### 清理 Docker 资源

一键停止并删除所有容器、镜像和未使用的卷，释放磁盘空间。

> **⚠️ 注意：** 这将删除所有未在运行的容器和所有未被使用的镜像，请谨慎操作。

```bash
# 紧急停止并重启 Docker 服务
sudo systemctl stop docker && sudo iptables -t filter -F && sudo systemctl restart docker

# 强制停止并删除所有容器和镜像
docker kill $(docker ps -q)
docker rm -f $(docker ps -aq)
docker rmi -f $(docker images -q)
docker system prune -a --volumes -f
```

---

## ⚙️ 系统维护

高级系统管理任务，如系统重装和会话管理。

### 1. 系统 DD 重装

使用一键脚本来重新安装您的操作系统。

> **⚠️ 警告：** 此操作将完全清除您服务器上的所有数据！请务必提前备份重要文件。

- **MoeClub 脚本:**
  ```bash
  bash <(wget --no-check-certificate -qO- 'https://raw.githubusercontent.com/MoeClub/Note/master/InstallNET.sh') -d 12 -v 64 -p 'YourPassword' -port 'YourSSHPort'
  ```

- **Bin456789 脚本:**
  ```bash
  curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh && bash reinstall.sh debian 12 --password 'YourPassword' --ssh-port 'YourSSHPort'
  ```

### 2. Tmux 会话管理

此命令会检查是否存在名为 `default` 的 `tmux` 会话。如果存在，则附加到该会话；如果不存在，则创建一个新的会话。

```bash
[ -n "$(tmux ls 2>/dev/null | grep default)" ] && tmux attach -t default || tmux new -s default
```

---

## 📦 一键安装脚本

通过预设脚本快速部署常用应用。

- **安装 Sub-Store:**
  ```bash
  bash <(curl -fsSL https://raw.githubusercontent.com/EAlyce/conf/main/Sub-Store/Sub-Store_Docker-compose.sh)
  ```

- **安装 PagerMaid (PGP 版):**
  ```bash
  wget https://raw.githubusercontent.com/EAlyce/conf/refs/heads/main/Linux/RXsetup.sh -O install.sh && chmod +x install.sh && bash install.sh
  ```

- **安装 Snell:**
  ```bash
  bash <(curl -fsSL https://raw.githubusercontent.com/EAlyce/conf/main/Snell/install_snell.sh)
  ```
