# PagerMaid-Modify 系统服务启动教程

## 一、创建系统服务文件

```bash
sudo tee /etc/systemd/system/PagerMaid-Modify.service > /dev/null << 'EOF'
[Unit]
Description=PagerMaid-Modify telegram utility daemon
After=network.target
[Install]
WantedBy=multi-user.target
[Service]
Type=simple
WorkingDirectory=/root/PagerMaid-Modify
ExecStart=/usr/bin/python3 -m pagermaid
Restart=always
User=root
Environment=PYTHONPATH=/root/PagerMaid-Modify
StandardOutput=journal
StandardError=journal
EOF
```

## 二、启动和设置服务

**一键命令（推荐）：**
```bash
systemctl daemon-reload && systemctl enable --now PagerMaid-Modify && systemctl status PagerMaid-Modify
```

**分步执行：**
```bash
# 重新加载systemd配置
systemctl daemon-reload

# 启动服务
systemctl start PagerMaid-Modify

# 设置开机自启
systemctl enable PagerMaid-Modify

# 查看服务状态
systemctl status PagerMaid-Modify
```

## 三、服务管理命令

### 基本操作
```bash
# 查看服务状态
systemctl status PagerMaid-Modify

# 启动服务
systemctl start PagerMaid-Modify

# 停止服务
systemctl stop PagerMaid-Modify

# 重启服务
systemctl restart PagerMaid-Modify

# 重新加载配置
systemctl reload PagerMaid-Modify
```

### 开机自启管理
```bash
# 启用开机自启
systemctl enable PagerMaid-Modify

# 禁用开机自启
systemctl disable PagerMaid-Modify

# 检查是否已启用开机自启
systemctl is-enabled PagerMaid-Modify
```

## 四、日志查看

### 查看日志
```bash
# 查看最新日志
journalctl -u PagerMaid-Modify

# 实时查看日志
journalctl -u PagerMaid-Modify -f

# 查看最近1小时日志
journalctl -u PagerMaid-Modify --since "1 hour ago"

# 查看最近50行日志
journalctl -u PagerMaid-Modify -n 50

# 查看今天的日志
journalctl -u PagerMaid-Modify --since today
```

### 日志级别过滤
```bash
# 只显示错误和警告
journalctl -u PagerMaid-Modify -p warning

# 只显示错误
journalctl -u PagerMaid-Modify -p err
```

## 五、故障排除

### 常见问题及解决方案

**1. 服务启动失败（exit code 203）**
- 检查Python路径：`which python3`
- 检查工作目录：`ls -la /root/PagerMaid-Modify`
- 手动测试：`cd /root/PagerMaid-Modify && python3 -m pagermaid`

**2. 权限问题**
- 确保服务以正确用户运行
- 检查文件权限：`ls -la /root/PagerMaid-Modify`

**3. 依赖问题**
- 检查Python版本：`python3 --version`
- 重新安装依赖：`pip install -r requirements.txt`

**4. 配置文件问题**
- 检查配置文件：`cat config.yml`
- 确保Telegram配置正确

### 调试步骤
```bash
# 1. 手动测试程序
cd /root/PagerMaid-Modify && python3 -m pagermaid

# 2. 检查服务配置
systemctl cat PagerMaid-Modify

# 3. 查看详细错误信息
journalctl -u PagerMaid-Modify -n 100

# 4. 重新创建服务
systemctl stop PagerMaid-Modify
systemctl disable PagerMaid-Modify
# 删除服务文件
rm /etc/systemd/system/PagerMaid-Modify.service
# 重新创建（使用上面的创建命令）
```

## 六、服务配置说明

### 服务文件各部分说明
```ini
[Unit]
Description=服务描述
After=network.target          # 网络启动后再启动此服务

[Install]
WantedBy=multi-user.target    # 多用户模式下启动

[Service]
Type=simple                   # 简单服务类型
WorkingDirectory=工作目录      # 程序运行目录
ExecStart=启动命令            # 服务启动命令
Restart=always               # 自动重启
User=运行用户                # 指定运行用户
Environment=环境变量          # 设置环境变量
StandardOutput=journal       # 日志输出到systemd journal
StandardError=journal        # 错误输出到systemd journal
```

## 七、成功运行确认

当看到以下状态时，说明服务运行成功：
```
● PagerMaid-Modify.service - PagerMaid-Modify telegram utility daemon
     Loaded: loaded (/etc/systemd/system/PagerMaid-Modify.service; enabled; vendor preset: enabled)
     Active: active (running) since Sat 2025-08-02 12:06:46 CST; 5ms ago
   Main PID: 806007 (python3)
```

关键指标：
- **Loaded**: loaded + enabled（已加载并启用）
- **Active**: active (running)（正在运行）
- **Main PID**: 显示进程ID（说明进程正常运行）

## 八、完整一键部署脚本

```bash
#!/bin/bash
# PagerMaid-Modify 一键部署为系统服务

echo "正在创建 PagerMaid-Modify 系统服务..."

# 创建服务文件
sudo tee /etc/systemd/system/PagerMaid-Modify.service > /dev/null << 'EOF'
[Unit]
Description=PagerMaid-Modify telegram utility daemon
After=network.target
[Install]
WantedBy=multi-user.target
[Service]
Type=simple
WorkingDirectory=/root/PagerMaid-Modify
ExecStart=/usr/bin/python3 -m pagermaid
Restart=always
User=root
Environment=PYTHONPATH=/root/PagerMaid-Modify
StandardOutput=journal
StandardError=journal
EOF

# 启动服务
echo "正在启动服务..."
systemctl daemon-reload
systemctl enable --now PagerMaid-Modify

# 检查状态
echo "服务状态："
systemctl status PagerMaid-Modify --no-pager

echo "部署完成！"
echo "使用 'journalctl -u PagerMaid-Modify -f' 查看实时日志"
```

将以上脚本保存为 `install_service.sh`，然后执行：
```bash
chmod +x install_service.sh && ./install_service.sh
```