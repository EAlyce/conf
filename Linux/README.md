 # 使用方法：

```
bash <(curl -fsSL https://raw.githubusercontent.com/EAlyce/conf/main/Linux/tmux.sh)
```

# 常用指令

### 安装软件
```
apt update && apt install curl git zip unzip wget sudo netcat-openbsd vim nano cron tmux file
 -y
```

### 更新所有包
```
apt-get update -y && apt-get upgrade -y && apt-get dist-upgrade -y && apt full-upgrade -y
```

### DD
```
bash <(wget --no-check-certificate -qO- 'https://raw.githubusercontent.com/MoeClub/Note/master/InstallNET.sh') -d 12 -v 64 -p As112211 -port 7890

```

```
curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh && bash reinstall.sh debian 12 --password As112211 --ssh-port 7890
```

### 安装Substore
```
bash <(curl -fsSL https://raw.githubusercontent.com/EAlyce/conf/main/Sub-Store/Sub-Store_Docker-compose.sh)
```

### PGP
```
bash <(curl -fsSL https://raw.githubusercontent.com/EAlyce/conf/main/PagerMaid/RXsetup.sh)
```

### Snell
```
bash <(curl -fsSL https://raw.githubusercontent.com/EAlyce/conf/main/Snell/install_snell.sh)
```
### tmux
```
[ -n "$(tmux ls 2>/dev/null | grep default)" ] && tmux attach -t default || tmux new -s default
```
