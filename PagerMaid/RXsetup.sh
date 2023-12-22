
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "错误：本脚本需要 root 权限执行。" 1>&2
        exit 1
    fi
}

check_ip() {
    country=$(curl --noproxy '*' -sSL https://api.myip.com/ | jq -r '.country' 2>/dev/null)
    if [[ $? -ne 0 ]]; then
        echo "警告：无法获取IP地址信息。" 1>&2
    else
        if [[ $country == "China" ]]; then
            echo "错误：本脚本不支持境内服务器使用。" 1>&2
            exit 1
        fi
    fi
}

check_sys() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        ID_LIKE=$(echo "$ID_LIKE" | awk '{print tolower($0)}')
        ID=$(echo "$ID" | awk '{print tolower($0)}')
        if [[ $ID == "debian" || $ID_LIKE == "debian" ]]; then
            release="debian"
        elif [[ $ID == "ubuntu" || $ID_LIKE == "ubuntu" ]]; then
            release="ubuntu"
        fi
    fi
}

install_python() {
    apt-get update -y >>/dev/null 2>&1
    apt-get install -y python3 python3-pip neofetch libzbar-dev git >>/dev/null 2>&1
    PYV=$(which python3)
    if [ -z "$PYV" ]; then
        echo "Python3 安装失败"
        exit 1
    fi
}

cd /var/lib

wget https://raw.githubusercontent.com/EAlyce/conf/main/PagerMaid/Pagermaid.sh
sudo mv /var/lib/PagerMaid-Pyro /var/lib/pagermaid
chmod +x Pagermaid.sh
./Pagermaid.sh