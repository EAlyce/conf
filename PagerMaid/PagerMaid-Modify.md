# 🚀 PagerMaid-Modify 安装指南

## 1. 系统更新和基础依赖安装
```bash
sudo apt update && sudo apt upgrade -y
sudo apt install git curl -y
```

## 2. 安装 Python 3.13  选13 选4 输入 3.13.7
```bash
curl -sS -O https://kejilion.pro/kejilion.sh && chmod +x kejilion.sh && ./kejilion.sh
```

## 3. 安装系统依赖包
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
    tesseract-ocr-all \
    ffmpeg
```

## 4. 解决 Python 包管理限制
```bash
find /usr -name "EXTERNALLY-MANAGED" -delete 2>/dev/null
```

## 5. 升级 pip 并安装 Python 依赖
```bash
python3 -m pip install --upgrade pip
sudo pip install --break-system-packages youtube-search-python yt-dlp aiohttp PyYAML coloredlogs
/root/.pyenv/versions/3.13.7/bin/python3 -m pip install yt-dlp
```

## 6. 下载和配置 PagerMaid-Modify
```bash
cd /root
mkdir -p PagerMaid-Modify && git clone https://github.com/TeamPGM/PagerMaid-Modify.git PagerMaid-Modify
cd ~/PagerMaid-Modify/
```

## 7. 安装项目依赖
```bash
/root/.pyenv/versions/3.13.7/bin/python3 -m pip install -r requirements.txt --root-user-action=ignore
```

## 8. 配置文件设置
```bash
cp config.gen.yml config.yml
```

> 📝 **配置说明**：请编辑 `config.yml` 文件，填入您的 `api_id` 和 `api_hash`

## 9. 首次运行测试
```bash
/root/.pyenv/versions/3.13.7/bin/python3 -m pagermaid
```

## 10. 创建系统服务（自动启动）
```bash
sudo tee /etc/systemd/system/PagerMaid-Modify.service > /dev/null << 'EOF'
[Unit]
Description=PagerMaid-Modify telegram utility daemon
After=network.target

[Service]
WorkingDirectory=/root/PagerMaid-Modify
ExecStart=/root/.pyenv/versions/3.13.7/bin/python3 -m pagermaid
Restart=always
RestartSec=5
User=root
StandardOutput=append:/var/log/pagermaid.log
StandardError=append:/var/log/pagermaid-error.log

[Install]
WantedBy=multi-user.target
EOF

# 重新加载配置并启动服务
sudo systemctl daemon-reload && \
sudo systemctl enable --now PagerMaid-Modify && \
sudo systemctl restart PagerMaid-Modify && \
sudo systemctl status PagerMaid-Modify
```
