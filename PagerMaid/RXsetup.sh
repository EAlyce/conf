# 如果必要，强制结束任何剩余的 apt、dpkg
sudo pkill -9 apt || true
sudo pkill -9 dpkg || true

# 检查锁文件是否存在，如果存在则移除它们
sudo rm -f /var/lib/dpkg/lock-frontend /var/lib/apt/lists/lock

# 配置未配置的包
sudo dpkg --configure -a
echo -e "nameserver 8.8.4.4\nnameserver 8.8.8.8" | sudo tee /etc/resolv.conf
cd /var/lib
sudo find /var/lib/ -type f -name "Pagermaid.sh*" -exec rm -f {} \;
curl -O https://raw.githubusercontent.com/EAlyce/conf/main/PagerMaid/Pagermaid.sh && chmod +x Pagermaid.sh && ./Pagermaid.sh