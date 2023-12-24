kill_process() {
    echo "正在停止 apt 和 dpkg 进程..."
    sudo pkill -9 apt || true
    sudo pkill -9 dpkg || true
}

remove_locks() {
    echo "正在移除锁文件..."
    sudo rm -f /var/lib/dpkg/lock-frontend /var/lib/apt/lists/lock
}

configure_packages() {
    echo "正在配置未配置的包..."
    sudo dpkg --configure -a
}

install_curl() {
    echo "正在安装 curl..."
    sudo apt install -y curl || {
        echo "安装 curl 失败"
        exit 1
    }
}

update_dns() {
    echo "正在更新 DNS 到 Google 的 DNS..."
    echo -e "nameserver 8.8.4.4\nnameserver 8.8.8.8" | sudo tee /etc/resolv.conf
}

install_linux() {
    echo "您选择了Linux环境下安装。"
    cd /var/lib
    sudo find /var/lib/ -type f -name "Pagermaid.sh*" -exec rm -f {} \;
    curl -O https://cdn.jsdelivr.net/gh/EAlyce/conf@main/PagerMaid/Pagermaid.sh || {
        echo "下载 Installer 失败"
        exit 1;
    }
    chmod +x Pagermaid.sh || {
        echo "更改权限失败"
        exit 1;
    }
    ./Pagermaid.sh
}

install_docker() {
    echo "您选择了Docker环境下安装。"
    curl -O https://cdn.jsdelivr.net/gh/EAlyce/conf@main/PagerMaid/DockerPagermaid.sh || {
        echo "下载 Docker Installer 失败"
        exit 1;
    }
    chmod +x DockerPagermaid.sh || {
        echo "更改权限失败"
        exit 1;
    }
    ./DockerPagermaid.sh
}

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

    kill_process
    remove_locks
    configure_packages
    install_curl
    update_dns

    read -p "输入选项 [ 0 - 2 ] " choice
    
    case $choice in
        1) 
            install_linux 
            ;;
        
        2)
            install_docker
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