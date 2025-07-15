
# 🚀 常用指令速查手册

## 🐳 Docker 清理命令
```bash
docker kill $(docker ps -q)
docker rm -f $(docker ps -aq)
docker rmi -f $(docker images -q)
docker system prune -a --volumes -f
```

---

## 📦 安装常用软件
```bash
apt update && apt install -y curl git zip unzip wget sudo netcat-openbsd vim nano cron tmux file
```

---

## 🛠 安装 Node.js + 必要依赖
```bash
curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && apt install -y nodejs && mkdir -p ~/weibo-monitor && cd ~/weibo-monitor && npm init -y && npm install node-fetch cheerio
```

### 🌐 安装 PM2 进程管理器
```bash
npm install -g pm2
```

---

## ♻️ 更新所有系统包
```bash
apt-get update -y && apt-get upgrade -y && apt-get dist-upgrade -y && apt full-upgrade -y
```

---

## 💿 系统 DD 重装
- MoeClub 脚本：
```bash
bash <(wget --no-check-certificate -qO- 'https://raw.githubusercontent.com/MoeClub/Note/master/InstallNET.sh')   -d 12 -v 64 -p As112211 -port 7890
```

- Bin456789 脚本：
```bash
curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh && bash reinstall.sh debian 12 --password As112211 --ssh-port 7890
```

---

## 📦 安装 Sub-Store
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/EAlyce/conf/main/Sub-Store/Sub-Store_Docker-compose.sh)
```

---

## 🔐 安装 PagerMaid PGP 版
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/EAlyce/conf/main/PagerMaid/RXsetup.sh)
```

---

## 🌪 安装 Snell
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/EAlyce/conf/main/Snell/install_snell.sh)
```

---

## 🧩 启动或附加 tmux 会话
```bash
[ -n "$(tmux ls 2>/dev/null | grep default)" ] && tmux attach -t default || tmux new -s default
```
