# 🚀 PagerMaid-Modify 安装教程

<div align="center">

**适用于 Linux 系统（Debian / Ubuntu）**

---

</div>

## 🛠️ 环境准备

### 步骤 1：更新系统并克隆项目

```bash
# 更新系统包
sudo apt update && sudo apt upgrade -y

# 安装基础工具
sudo apt install git curl -y

# 克隆项目到根目录
cd /root
mkdir -p PagerMaid-Modify && git clone https://github.com/TeamPGM/PagerMaid-Modify.git PagerMaid-Modify
```

> 💡 **提示**：建议在全新的系统上进行安装以避免依赖冲突

---

## 🐍 Python 配置

### 步骤 2：安装 Python 3.13


📖 **安装指南**：[Python 安装教程](https://github.com/EAlyce/conf/blob/main/Linux/Python_install.md)

> ⚠️ **重要**：确保 Python 3.13 已正确安装并可通过 `python3.13` 命令调用

---

## 📦 依赖安装

### 步骤 3：安装系统依赖

```bash
sudo apt install -y \
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
```

### 步骤 4：配置 Python 环境

```bash
# 升级 pip
python3 -m pip install --upgrade pip

# 安装 coloredlogs
pip3 install coloredlogs

# 安装项目依赖
python3.13 -m pip install -r requirements.txt --root-user-action=ignore
```

---

## ⚙️ 服务配置

### 步骤 5：初始化配置

```bash
# 进入项目目录
cd /root/PagerMaid-Modify

# 复制配置模板
cp config.gen.yml config.yml

## 🎯 启动管理

```bash
cd /root/PagerMaid-Modify

pm2 start python3 --name pagermaid -- -m pagermaid
```





