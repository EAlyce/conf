
# 🚀 PagerMaid-Modify 安装教程（适用于 Linux）

> 本教程适用于 Debian / Ubuntu 系统

---

## 📥 1. 克隆项目并准备环境

```bash
sudo -i
cd /root
git clone https://github.com/TeamPGM/PagerMaid-Modify.git PagerMaid-Modify && cd PagerMaid-Modify
sudo apt update && sudo apt upgrade -y
```

---

## 🐍 2. 安装 Python 3.13

请根据此文档手动安装 Python 3.13：  
👉 [Python 安装教程](https://github.com/EAlyce/conf/blob/main/Linux/Python_install.md)

---

## 📦 3. 安装依赖包

```bash
sudo apt install -y python3-pip python3-venv imagemagick libwebp-dev neofetch \
libzbar-dev libxml2-dev libxslt-dev tesseract-ocr tesseract-ocr-all
```

---

## 🔧 4. 配置 Python 环境并安装依赖

```bash
python3 -m pip install --upgrade pip
pip3 install coloredlogs
/usr/local/bin/python3.13 -m pip install -r requirements.txt --root-user-action=ignore
```

---

## 🚦 5. 启动 PagerMaid-Modify

```bash
cd /root/PagerMaid-Modify
python3 -m pagermaid
cp config.gen.yml config.yml
```

> ✏️ 打开 `config.yml` 文件，**填写你的 `api_id` 和 `api_hash`**

---

## ⚙️ 6. 创建 systemd 服务（用于后台运行）

Finalshell 命令编辑区 粘贴以下内容创建服务文件发送即可：

```bash
sudo tee /etc/systemd/system/PagerMaid-Modify.service > /dev/null << 'EOF'
[Unit]
Description=PagerMaid-Modify telegram utility daemon
After=network.target

[Service]
Type=simple
WorkingDirectory=/root/PagerMaid-Modify
ExecStart=/bin/bash -c "cd /root/PagerMaid-Modify && python3 -m pagermaid"
Restart=always
User=root
Environment="PYTHONPATH=/root/PagerMaid-Modify"
Environment="HOME=/root"
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
```

---

## ▶️ 7. 启动服务并设置开机自启

### ✅ 一键执行（推荐）：

```bash
systemctl daemon-reload && systemctl enable --now PagerMaid-Modify && systemctl status PagerMaid-Modify
```

---

### 🧩 分步操作：

```bash
# 重新加载 systemd 配置
systemctl daemon-reload

# 启动服务
systemctl start PagerMaid-Modify

# 设置开机启动
systemctl enable PagerMaid-Modify

# 查看运行状态
systemctl status PagerMaid-Modify

# 停止服务
systemctl stop PagerMaid-Modify

# 重启服务
systemctl restart PagerMaid-Modify

# 重新加载配置（如果支持）
systemctl reload PagerMaid-Modify
```
