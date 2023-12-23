# 如果必要，强制结束任何剩余的 apt、dpkg
sudo pkill -9 apt || true
sudo pkill -9 dpkg || true

# 检查锁文件是否存在，如果存在则移除它们
sudo rm -f /var/lib/dpkg/lock-frontend /var/lib/apt/lists/lock

# 配置未配置的包
sudo dpkg --configure -a
sudo apt install -y curl
echo -e "nameserver 8.8.4.4\nnameserver 8.8.8.8" | sudo tee /etc/resolv.conf
while :
do
    clear
    echo "----------------------------"
    echo " PagerMaid安装选项"
    echo "----------------------------"
    echo "[1] Linux环境下安装"
    echo "[2] Docker环境下安装"
    echo "[0] 退出"
    echo "----------------------------"
    read -p "输入选项 [ 0 - 2 ] " choice
    
    case $choice in
        1)
            echo "您选择了Linux环境下安装。"
            cd /var/lib
            sudo find /var/lib/ -type f -name "Pagermaid.sh*" -exec rm -f {} \;
            curl -O https://cdn.jsdelivr.net/gh/EAlyce/conf@main/PagerMaid/Pagermaid.sh
            chmod +x Pagermaid.sh
            ./Pagermaid.sh
            ;;
        
        2)
            echo "您选择了Docker环境下安装。"
            curl -O https://cdn.jsdelivr.net/gh/EAlyce/conf@main/PagerMaid/DockerPagermaid.sh
            chmod +x DockerPagermaid.sh
            ./DockerPagermaid.sh
            ;;
        
        0) 
            echo "退出"
            exit
            ;;
       
        *)
            echo "错误输入， 请重新选择!"
            ;;
    esac
    read -p "按任意键返回菜单 " 
done