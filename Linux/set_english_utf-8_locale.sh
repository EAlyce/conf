#!/bin/bash

# 检查是否为超级用户权限
if [ "$(id -u)" != "0" ]; then
   echo "此脚本必须以超级用户权限运行" 1>&2
   exit 1
fi

# 设置系统语言为英文
echo 'LANG="en_US.UTF-8"' > /etc/default/locale

# 更新locale
locale-gen en_US.UTF-8

# 应用设置
source /etc/default/locale

# 重启相关服务或系统来使设置生效，具体操作视系统和需要而定
# 例如：重启系统
# reboot

# 输出设置成功消息
echo "系统语言设置为英文并使用UTF-8编码成功！"
