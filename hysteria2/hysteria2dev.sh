#!/usr/bin/env bash

export LANG=en_US.UTF-8

[[ $EUID -ne 0 ]] && echo "注意: 请在root用户下运行脚本" && exit 1

if [[ -z $(type -P curl) ]]; then
    apt-get update
    apt -y install curl
fi

realip(){
    ip=$(curl -s4m8 ip.gs -k) || ip=$(curl -s6m8 ip.gs -k)
}

realip

echo "当前系统的IP地址是：$ip"

inst_cert(){
    cert_path="/etc/hysteria/cert.crt"
    key_path="/etc/hysteria/private.key"

    openssl ecparam -genkey -name prime256v1 -out $key_path
    openssl req -new -x509 -days 36500 -key $key_path -out $cert_path -subj "/CN=www.bing.com"

    chmod 777 $cert_path
    chmod 777 $key_path

    hy_domain="www.bing.com"
    domain="www.bing.com"

    echo "证书已生成: $cert_path"
    echo "密钥已生成: $key_path"
}


inst_port(){
    iptables -t nat -F PREROUTING >/dev/null 2>&1

    while true; do
        port=$(shuf -i 10000-39999 -n 1)
        if [[ -z $(ss -tunlp | grep -w udp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]]; then
            break
        fi
    done

     "Hysteria 2 节点将使用的端口是：$port"
    inst_jump
}

inst_jump(){
    firstport=40000
    endport=50000
    
    iptables -t nat -A PREROUTING -p udp --dport $firstport:$endport -j DNAT --to-destination :$port
    ip6tables -t nat -A PREROUTING -p udp --dport $firstport:$endport -j DNAT --to-destination :$port
    netfilter-persistent save >/dev/null 2>&1

}

inst_pwd(){
    auth_pwd=$(openssl rand -hex 8)
}

inst_site(){
    proxysite="www.bing.com"
    echo "Hysteria 2 的伪装网站地址已设置为：$proxysite"
}

insthysteria(){
    warpv6=$(curl -s6m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
    warpv4=$(curl -s4m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
    if [[ $warpv4 =~ on|plus || $warpv6 =~ on|plus ]]; then
        wg-quick down wgcf >/dev/null 2>&1
        systemctl stop warp-go >/dev/null 2>&1
        realip
        systemctl start warp-go >/dev/null 2>&1
        wg-quick up wgcf >/dev/null 2>&1
    else
        realip
    fi

    if [[ ! ${SYSTEM} == "CentOS" ]]; then
        ${PACKAGE_UPDATE}
    fi
    ${PACKAGE_INSTALL} curl wget sudo qrencode procps iptables-persistent netfilter-persistent

    wget -N https://raw.githubusercontent.com/Misaka-blog/hysteria-install/main/hy2/install_server.sh
    bash install_server.sh
    rm -f install_server.sh

    if [[ -f "/usr/local/bin/hysteria" ]]; then
        echo "Hysteria 2 安装成功！"
    else
        red "Hysteria 2 安装失败！"
        exit 1
    fi

    # 询问用户 Hysteria 配置
    inst_cert
    inst_port
    inst_pwd
    inst_site

    # 设置 Hysteria 配置文件
    cat << EOF > /etc/hysteria/config.yaml
listen: :$port

tls:
  cert: $cert_path
  key: $key_path

quic:
  initStreamReceiveWindow: 16777216
  maxStreamReceiveWindow: 16777216
  initConnReceiveWindow: 33554432
  maxConnReceiveWindow: 33554432

auth:
  type: password
  password: $auth_pwd

masquerade:
  type: proxy
  proxy:
    url: https://$proxysite
    rewriteHost: true
EOF

    # 确定最终入站端口范围
    if [[ -n $firstport ]]; then
        last_port="$port,$firstport-$endport"
    else
        last_port=$port
    fi

    # 给 IPv6 地址加中括号
    if [[ -n $(echo $ip | grep ":") ]]; then
        last_ip="[$ip]"
    else
        last_ip=$ip
    fi

    mkdir /root/hy
    cat << EOF > /root/hy/hy-client.yaml
server: $last_ip:$last_port

auth: $auth_pwd

tls:
  sni: $hy_domain
  insecure: true

quic:
  initStreamReceiveWindow: 16777216
  maxStreamReceiveWindow: 16777216
  initConnReceiveWindow: 33554432
  maxConnReceiveWindow: 33554432

fastOpen: true

socks5:
  listen: 127.0.0.1:5080

transport:
  udp:
    hopInterval: 30s 
EOF
    cat << EOF > /root/hy/hy-client.json
{
  "server": "$last_ip:$last_port",
  "auth": "$auth_pwd",
  "tls": {
    "sni": "$hy_domain",
    "insecure": true
  },
  "quic": {
    "initStreamReceiveWindow": 16777216,
    "maxStreamReceiveWindow": 16777216,
    "initConnReceiveWindow": 33554432,
    "maxConnReceiveWindow": 33554432
  },
  "fastOpen": true,
  "socks5": {
    "listen": "127.0.0.1:5080"
  },
  "transport": {
    "udp": {
      "hopInterval": "30s"
    }
  }
}
EOF
    node_info="$LOCATION $RANDOM_PORT = hysteria2, $public_ip, $RANDOM_PORT, password=$PASSWORD, ecn=true, skip-cert-verify=true, sni=wew.bing.com, port-hopping=40000-50000, port-hopping-interval=30"
    echo 
    echo "$node_info"
    echo 
}

unsthysteria(){
    systemctl stop hysteria-server.service >/dev/null 2>&1
    systemctl disable hysteria-server.service >/dev/null 2>&1
    rm -f /lib/systemd/system/hysteria-server.service /lib/systemd/system/hysteria-server@.service
    rm -rf /usr/local/bin/hysteria /etc/hysteria /root/hy /root/hysteria.sh
    iptables -t nat -F PREROUTING >/dev/null 2>&1
    netfilter-persistent save >/dev/null 2>&1

    echo "Hysteria 2 已彻底卸载完成！"
}

starthysteria(){
    systemctl start hysteria-server
    systemctl enable hysteria-server >/dev/null 2>&1
}

stophysteria(){
    systemctl stop hysteria-server
    systemctl disable hysteria-server >/dev/null 2>&1
}

hysteriaswitch(){
    echo ""
    echo -e " 1.${PLAIN} 启动 Hysteria 2"
    echo -e " 2.${PLAIN} 关闭 Hysteria 2"
    echo -e " 3.${PLAIN} 重启 Hysteria 2"
    echo ""
    read -rp "请输入选项 [0-3]: " switchInput
    case $switchInput in
        1 ) starthysteria ;;
        2 ) stophysteria ;;
        3 ) stophysteria && starthysteria ;;
        * ) exit 1 ;;
    esac
}

changeport(){
    oldport=$(cat /etc/hysteria/config.yaml 2>/dev/null | sed -n 1p | awk '{print $2}' | awk -F ":" '{print $2}')
    
    read -p "设置 Hysteria 2 端口[1-65535]（回车则随机分配端口）：" port
    [[ -z $port ]] && port=$(shuf -i 2000-65535 -n 1)

    until [[ -z $(ss -tunlp | grep -w udp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]]; do
        if [[ -n $(ss -tunlp | grep -w udp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]]; then
            echo -e "${RED} $port ${PLAIN} 端口已经被其他程序占用，请更换端口重试！"
            read -p "设置 Hysteria 2 端口 [1-65535]（回车则随机分配端口）：" port
            [[ -z $port ]] && port=$(shuf -i 2000-65535 -n 1)
        fi
    done

    sed -i "1s#$oldport#$port#g" /etc/hysteria/config.yaml
    sed -i "1s#$oldport#$port#g" /root/hy/hy-client.yaml
    sed -i "2s#$oldport#$port#g" /root/hy/hy-client.json

    stophysteria && starthysteria

    showconf
}

changepasswd(){
    oldpasswd=$(cat /etc/hysteria/config.yaml 2>/dev/null | sed -n 15p | awk '{print $2}')

    read -p "设置 Hysteria 2 密码（回车跳过为随机字符）：" passwd
    [[ -z $passwd ]] && passwd=$(date +%s%N | md5sum | cut -c 1-8)

    sed -i "1s#$oldpasswd#$passwd#g" /etc/hysteria/config.yaml
    sed -i "1s#$oldpasswd#$passwd#g" /root/hy/hy-client.yaml
    sed -i "3s#$oldpasswd#$passwd#g" /root/hy/hy-client.json

    stophysteria && starthysteria

    showconf
}

change_cert(){
    old_cert=$(cat /etc/hysteria/config.yaml | grep cert | awk -F " " '{print $2}')
    old_key=$(cat /etc/hysteria/config.yaml | grep key | awk -F " " '{print $2}')
    old_hydomain=$(cat /root/hy/hy-client.yaml | grep sni | awk '{print $2}')

    inst_cert

    sed -i "s!$old_cert!$cert_path!g" /etc/hysteria/config.yaml
    sed -i "s!$old_key!$key_path!g" /etc/hysteria/config.yaml
    sed -i "6s/$old_hydomain/$hy_domain/g" /root/hy/hy-client.yaml
    sed -i "5s/$old_hydomain/$hy_domain/g" /root/hy/hy-client.json

    stophysteria && starthysteria

    showconf
}

changeproxysite(){
    oldproxysite=$(cat /etc/hysteria/config.yaml | grep url | awk -F " " '{print $2}' | awk -F "https://" '{print $2}')
    
    inst_site

    sed -i "s#$oldproxysite#$proxysite#g" /etc/caddy/Caddyfile

    stophysteria && starthysteria

    "Hysteria 2 节点伪装网站已成功修改为：$proxysite"
}

changeconf(){

    echo -e " 1.${PLAIN} 修改端口"
    echo -e " 2.${PLAIN} 修改密码"
    echo -e " 3.${PLAIN} 修改证书类型"
    echo -e " 4.${PLAIN} 修改伪装网站"
    echo ""
    read -p " 请选择操作 [1-4]：" confAnswer
    case $confAnswer in
        1 ) changeport ;;
        2 ) changepasswd ;;
        3 ) change_cert ;;
        4 ) changeproxysite ;;
        * ) exit 1 ;;
    esac
}

showconf(){
    node_info="$LOCATION $RANDOM_PORT = hysteria2, $public_ip, $RANDOM_PORT, password=$PASSWORD, ecn=true, skip-cert-verify=true, sni=wew.bing.com, port-hopping=40000-50000, port-hopping-interval=30"
    echo 
    echo "$node_info"
    echo 
}

update_core(){
    wget -N https://raw.githubusercontent.com/Misaka-blog/hysteria-install/main/hy2/install_server.sh
    bash install_server.sh
    
    rm -f install_server.sh
}

menu() {
    clear
    echo ""
    echo -e " 1.${PLAIN} 安装 Hysteria 2"
    echo -e " 2.${PLAIN} ${RED}卸载 Hysteria 2${PLAIN}"
    echo " -------------"
    echo -e " 3.${PLAIN} 关闭、开启、重启 Hysteria 2"
    echo -e " 4.${PLAIN} 修改 Hysteria 2 配置"
    echo -e " 5.${PLAIN} 显示 Hysteria 2 配置文件"
    echo " -------------"
    echo -e " 6.${PLAIN} 更新 Hysteria 2 内核"
    echo " -------------"
    echo -e " 0.${PLAIN} 退出脚本"
    echo ""
    read -rp "请输入选项 [0-5]: " menuInput
    case $menuInput in
        1 ) insthysteria ;;
        2 ) unsthysteria ;;
        3 ) hysteriaswitch ;;
        4 ) changeconf ;;
        5 ) showconf ;;
        6 ) update_core ;;
        * ) exit 1 ;;
    esac
}

menu
