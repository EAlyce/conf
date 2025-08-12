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
pip3 install coloredlogs --break-system-packages

# 安装项目依赖
python3 -m pip install -r requirements.txt --root-user-action=ignore
```

---

## ⚙️ 服务配置

### 步骤 5：初始化配置

```bash
# 进入项目目录
cd /root/PagerMaid-Modify

# 复制配置模板
cp config.gen.yml config.yml

# 首次运行生成配置
python3.13 -m pagermaid
```

> 📝 **配置说明**：请编辑 `config.yml` 文件，填入您的 `api_id` 和 `api_hash`

### 步骤 6：创建系统服务
在命令编辑器中粘贴发送以下内容
```bash
sudo tee /etc/systemd/system/PagerMaid-Modify.service > /dev/null << 'EOF'
[Unit]
Description=PagerMaid-Modify telegram utility daemon
After=network.target

[Service]
WorkingDirectory=/root/PagerMaid-Modify
ExecStart=python3 -m pagermaid
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF
```

---

## 🎯 启动管理

### 快速启动（推荐）

```bash
systemctl daemon-reload && \
systemctl enable --now PagerMaid-Modify && \
systemctl status PagerMaid-Modify
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

---

<div align="center">

### 🎉 恭喜完成安装！

*PagerMaid-Modify 现已成功部署并运行*

**如遇问题，请检查服务状态或查看系统日志**

---

</div>
