#!/bin/bash
set -e

# 🚀 PagerMaid-Modify 一键安装脚本
# 适用于 Debian / Ubuntu

# 1. 更新系统并安装基础工具
apt update && apt upgrade -y
apt install -y git curl software-properties-common build-essential

# 2. 安装 Python 3.13
add-apt-repository -y ppa:deadsnakes/ppa
apt update
apt install -y python3.13 python3.13-venv python3.13-distutils

# 3. 克隆项目
cd /root
mkdir -p PagerMaid-Modify
git clone https://github.com/TeamPGM/PagerMaid-Modify.git PagerMaid-Modify

# 4. 安装系统依赖
apt install -y \
    python3-pip \
    python3-venv \
    imagemagick \
    libwebp-dev \
    neofetch \
    libzbar-dev \
    libxml2-dev \
    libxslt-dev \
    tesseract-ocr \
    tesseract-ocr-all

# 5. 升级 pip 并安装 Python 依赖
python3 -m pip install --upgrade pip
pip3 install coloredlogs
python3.13 -m pip install --upgrade pip
python3.13 -m pip install -r /root/PagerMaid-Modify/requirements.txt --root-user-action=ignore

# 6. 初始化配置
cd /root/PagerMaid-Modify
cp config.gen.yml config.yml

# 7. 安装 Node.js 20.x
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt install -y nodejs

# 8. 安装 PM2
npm install -g pm2

# 9. 启动 PagerMaid
pm2 start python3.13 --name pagermaid -- -m pagermaid
pm2 save

echo "✅ PagerMaid-Modify 安装完成并已通过 PM2 启动"
