#!/bin/bash

# SSH密钥生成和配置脚本 (脱敏版本)
# 使用方法: bash sshkey.sh

echo "========================================="
echo "SSH密钥生成和配置脚本"
echo "========================================="

# 用户交互输入配置
echo "请输入Telegram Bot配置信息:"
read -p "Telegram Bot Token: " TG_BOT_TOKEN
read -p "Telegram Chat ID: " TG_CHAT_ID

# 验证输入不为空
if [ -z "$TG_BOT_TOKEN" ] || [ -z "$TG_CHAT_ID" ]; then
    echo "❌ Token和Chat ID不能为空"
    exit 1
fi

# 生成时间戳
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
WORK_DIR="/tmp/ssh_keys_$TIMESTAMP"
KEY_NAME="ssh_key_$TIMESTAMP"

echo "开始生成SSH密钥对..."

# 创建工作目录
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# 生成RSA密钥对 (4096位，无密码保护以便自动化处理)
ssh-keygen -t rsa -b 4096 -f "$KEY_NAME" -N "" -C "generated_on_$(hostname)_$TIMESTAMP"

if [ $? -ne 0 ]; then
    echo "SSH密钥生成失败"
    exit 1
fi

echo "RSA密钥对生成成功"

# 检查是否安装了putty-tools (用于转换PPK格式)
if ! command -v puttygen &> /dev/null; then
    echo "安装putty-tools用于PPK转换..."
    # 根据不同的Linux发行版安装putty-tools
    if command -v apt-get &> /dev/null; then
        apt-get update && apt-get install -y putty-tools
    elif command -v yum &> /dev/null; then
        yum install -y putty
    elif command -v dnf &> /dev/null; then
        dnf install -y putty
    else
        echo "无法自动安装putty-tools，请手动安装后重试"
        exit 1
    fi
fi

# 转换私钥为PPK格式
echo "转换私钥为PPK格式..."
puttygen "$KEY_NAME" -o "${KEY_NAME}.ppk"

if [ $? -ne 0 ]; then
    echo "PPK转换失败"
    exit 1
fi

echo "PPK转换成功"

# 创建密钥信息文件
cat > key_info.txt << EOF
SSH密钥信息
生成时间: $(date)
服务器: $(hostname)
IP地址: $(curl -s ifconfig.me 2>/dev/null || echo "无法获取")

文件说明:
- ${KEY_NAME}: RSA私钥 (OpenSSH格式)
- ${KEY_NAME}.pub: RSA公钥
- ${KEY_NAME}.ppk: RSA私钥 (PuTTY格式)

使用方法:
1. 将公钥内容添加到目标服务器的 ~/.ssh/authorized_keys 文件中
2. 使用OpenSSH客户端时使用 ${KEY_NAME} 私钥文件
3. 使用PuTTY/WinSCP等工具时使用 ${KEY_NAME}.ppk 文件

公钥内容:
$(cat ${KEY_NAME}.pub)
EOF

# 打包所有文件
echo "打包密钥文件..."
tar -czf ssh_keys_package.tar.gz ${KEY_NAME} ${KEY_NAME}.pub ${KEY_NAME}.ppk key_info.txt

# 发送到Telegram
echo "发送密钥包到Telegram..."
RESPONSE=$(curl -s -X POST "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendDocument" \
    -F "chat_id=${TG_CHAT_ID}" \
    -F "document=@ssh_keys_package.tar.gz" \
    -F "caption=🔐 SSH密钥包 - $(hostname) - $TIMESTAMP

包含文件:
• RSA私钥 (OpenSSH格式)
• RSA公钥  
• RSA私钥 (PPK格式)
• 使用说明

⚠️ 请妥善保管私钥文件，建议下载后立即删除此消息")

# 检查发送结果
if echo "$RESPONSE" | grep -q '"ok":true'; then
    echo "✅ 密钥包已成功发送到Telegram"
else
    echo "❌ Telegram发送失败，响应: $RESPONSE"
fi

# 配置SSH服务器设置
echo "========================================="
echo "配置SSH服务器设置..."
echo "========================================="

# 备份SSH配置文件
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.${TIMESTAMP}
echo "已备份 sshd_config 到 sshd_config.backup.${TIMESTAMP}"

# 修改SSH服务器配置为仅密钥登录
echo "修改SSH服务器配置..."

# 创建新的SSH配置
cat > /etc/ssh/sshd_config.new << 'EOF'
# SSH服务器配置 - 仅密钥登录模式
Port 22
Protocol 2

# 认证设置
PubkeyAuthentication yes
AuthorizedKeysFile /root/.ssh/authorized_keys
PasswordAuthentication no
ChallengeResponseAuthentication no
UsePAM no

# Root登录设置
PermitRootLogin yes
PermitEmptyPasswords no

# 安全设置
X11Forwarding no
PrintMotd no
PrintLastLog yes
TCPKeepAlive yes
UsePrivilegeSeparation yes
StrictModes yes
IgnoreRhosts yes
RhostsRSAAuthentication no
HostbasedAuthentication no
PermitUserEnvironment no
Compression delayed
ClientAliveInterval 30
ClientAliveCountMax 3
UseDNS no

# 日志设置
SyslogFacility AUTH
LogLevel INFO
EOF

# 应用新配置
mv /etc/ssh/sshd_config.new /etc/ssh/sshd_config

# 自动更新 /root/.ssh/authorized_keys
echo "更新 /root/.ssh/authorized_keys..."

# 确保 .ssh 目录存在
mkdir -p /root/.ssh
chmod 700 /root/.ssh

# 如果authorized_keys不存在，创建空文件
if [ ! -f /root/.ssh/authorized_keys ]; then
    touch /root/.ssh/authorized_keys
    echo "已创建 /root/.ssh/authorized_keys 文件"
fi

# 备份现有的 authorized_keys
cp /root/.ssh/authorized_keys /root/.ssh/authorized_keys.backup.${TIMESTAMP}
echo "已备份现有的 authorized_keys 到 authorized_keys.backup.${TIMESTAMP}"

# 询问用户是否要替换还是追加公钥
echo "请选择操作模式:"
echo "1) 追加新公钥 (保留现有密钥，推荐)"
echo "2) 替换所有公钥 (仅保留新密钥，危险!)"
read -p "请输入选择 (1/2): " choice

case $choice in
    2)
        # 替换模式：仅保留新公钥
        cat ${KEY_NAME}.pub > /root/.ssh/authorized_keys
        echo "⚠️  已替换 authorized_keys，仅保留新公钥"
        ;;
    *)
        # 默认追加模式：保留现有密钥
        cat ${KEY_NAME}.pub >> /root/.ssh/authorized_keys
        echo "✅ 新公钥已追加到 authorized_keys"
        ;;
esac

chmod 600 /root/.ssh/authorized_keys

# 重启SSH服务使配置生效
echo "重启SSH服务..."
if systemctl restart sshd 2>/dev/null; then
    echo "✅ SSH服务重启成功 (systemd)"
elif service ssh restart 2>/dev/null; then
    echo "✅ SSH服务重启成功 (service)"
elif /etc/init.d/ssh restart 2>/dev/null; then
    echo "✅ SSH服务重启成功 (init.d)"
else
    echo "❌ 无法重启SSH服务，请手动重启"
fi

# 验证SSH配置
echo "========================================="
echo "验证SSH配置..."
echo "========================================="

# 检查SSH服务状态
if systemctl is-active --quiet sshd 2>/dev/null; then
    echo "✅ SSH服务运行正常"
elif pgrep sshd > /dev/null; then
    echo "✅ SSH服务运行正常"
else
    echo "❌ SSH服务可能未正常运行"
fi

# 显示当前SSH配置摘要
echo ""
echo "当前SSH配置摘要:"
echo "- 仅允许密钥登录: ✅"
echo "- 禁用密码登录: ✅"
echo "- 允许Root登录: ✅"
echo "- 密钥文件位置: /root/.ssh/authorized_keys"

# 显示公钥内容（用于手动复制到其他服务器）
echo ""
echo "========================================="
echo "新生成的公钥内容:"
echo "========================================="
cat ${KEY_NAME}.pub
echo "========================================="

# 安全提醒
echo ""
echo "⚠️  重要提醒:"
echo "1. SSH配置已修改为仅密钥登录模式"
echo "2. 请确保新密钥能正常登录后再断开当前连接"
echo "3. 如果新密钥无法登录，可使用备份文件恢复:"
echo "   cp /etc/ssh/sshd_config.backup.${TIMESTAMP} /etc/ssh/sshd_config"
echo "   systemctl restart sshd"
echo "4. authorized_keys备份位置: /root/.ssh/authorized_keys.backup.${TIMESTAMP}"

# 安全清理
echo "清理临时文件..."
cd /tmp
rm -rf "$WORK_DIR"

echo "========================================="
echo "脚本执行完成"
echo "SSH服务器已配置为仅密钥登录模式"
echo "========================================="
