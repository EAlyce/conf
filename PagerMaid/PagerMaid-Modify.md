# 🚀 PagerMaid-Modify 安装

```
sudo apt update && sudo apt upgrade -y
```
```
sudo apt install git curl -y
```
```
find /usr -name "EXTERNALLY-MANAGED" -delete 2>/dev/null
```
```
sudo pip install --break-system-packages youtube-search-python yt-dlp aiohttp PyYAML coloredlogs
```
```
sudo apt install -y ffmpeg
```
```
/root/.pyenv/versions/3.13.6/bin/python3 -m pip install yt-dlp
```
```
cd /root
```
```
mkdir -p PagerMaid-Modify && git clone https://github.com/TeamPGM/PagerMaid-Modify.git PagerMaid-Modify
```
```
cd ~/PagerMaid-Modify/
```

安装 Python 3.13


```
curl -sS -O https://kejilion.pro/kejilion.sh && chmod +x kejilion.sh && ./kejilion.sh
```
```bash
sudo apt install -y \
    python3-pip \
    python3-venv \
    imagemagick \
    libwebp-dev \
    libzbar-dev \
    libxml2-dev \
    libxslt-dev \
    tesseract-ocr \
    tesseract-ocr-all
```
```
python3 -m pip install --upgrade pip
```
```
/root/.pyenv/versions/3.13.6/bin/python3 -m pip install -r requirements.txt --root-user-action=ignore
```

```
cd /root/PagerMaid-Modify
```
```
cp config.gen.yml config.yml
```
```
/root/.pyenv/versions/3.13.6/bin/python3 -m pagermaid
```

> 📝 **配置说明**：请编辑 `config.yml` 文件，填入您的 `api_id` 和 `api_hash`

在命令编辑器中粘贴发送以下内容
```
sudo tee /etc/systemd/system/PagerMaid-Modify.service > /dev/null << 'EOF'
[Unit]
Description=PagerMaid-Modify telegram utility daemon
After=network.target

[Service]
WorkingDirectory=/root/PagerMaid-Modify
ExecStart=/root/.pyenv/versions/3.13.6/bin/python3 -m pagermaid
Restart=always
RestartSec=5
User=root
StandardOutput=append:/var/log/pagermaid.log
StandardError=append:/var/log/pagermaid-error.log

[Install]
WantedBy=multi-user.target
EOF

# 重新加载 systemd 配置、启用开机自启并立即重启服务
sudo systemctl daemon-reload && \
sudo systemctl enable --now PagerMaid-Modify && \
sudo systemctl restart PagerMaid-Modify && \
sudo systemctl status PagerMaid-Modify
```
### 详细操作命令

| 操作 | 命令 | 说明 |
|------|------|------|
| 🔄 重载配置 | `systemctl daemon-reload` | 重新加载 systemd 配置 |
| ▶️ 启动服务 | `systemctl start PagerMaid-Modify` | 启动 PagerMaid 服务 |
| 🔒 开机自启 | `systemctl enable PagerMaid-Modify` | 设置开机自动启动 |
| 📊 查看状态 | `systemctl status PagerMaid-Modify` | 检查服务运行状态 |
| ⏹️ 停止服务 | `systemctl stop PagerMaid-Modify` | 停止 PagerMaid 服务 |
| 🔄 重启服务 | `systemctl restart PagerMaid-Modify` | 重启 PagerMaid 服务 |

