#!/usr/bin/env bash
if [[ $EUID -ne 0 ]]; then echo "错误：本脚本需要 root 权限执行。" 1>&2; exit 1; fi
docker_check() {
    sudo pkill -9 apt dpkg || true
    sudo rm -f /var/lib/dpkg/lock-frontend /var/lib/apt/lists/lock
    sudo dpkg --configure -a
    command -v docker &> /dev/null || { echo "Installing Docker..."; curl -fsSL https://test.docker.com | bash; }
    command -v docker &> /dev/null && echo "Docker已安装"
    command -v docker-compose &> /dev/null || { echo "Installing Docker Compose..."; sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose && sudo chmod +x /usr/local/bin/docker-compose; }
    command -v docker-compose &> /dev/null && echo "Docker Compose已安装" || { echo "Docker Compose安装失败。"; exit 1; }
}
build_docker() {
    container_name="PagerMaid-$(date +%s)"
    echo "容器的名称为 $container_name"
    echo "正在拉取 Docker 镜像 . . ."
    docker rm -f "$container_name" > /dev/null 2>&1
    docker pull teampgm/pagermaid_pyro
}
start_docker() {
    docker run -dit --restart=always --name="$container_name" --hostname="$container_name" teampgm/pagermaid_pyro <&1
    sleep 3
    docker exec -it "$container_name" bash utils/docker-config.sh
    docker restart "$container_name"
}
data_persistence() {
    echo "数据持久化可以在升级或重新部署容器时保留配置文件和插件。"
    container_name="PagerMaid-Pyro"
    data_path="/root/${container_name}"
    mkdir -p "${data_path}"
    if docker inspect "$container_name" &>/dev/null; then
        docker cp "$container_name":/pagermaid/workdir "$data_path"
        docker stop "$container_name" &>/dev/null
        docker rm "$container_name" &>/dev/null
    fi
    docker run -dit -v "$data_path":/pagermaid/workdir --restart=always --name="$container_name" --hostname="$container_name" teampgm/pagermaid_pyro <&1
echo -e "\n数据持久化操作完成。\n"
}
start_installation() {
    docker_check
    build_docker
    start_docker
    data_persistence
	exit
}

cleanup() {
    printf "请输入 PagerMaid 容器的名称："
    read -r container_name <&1
    echo "开始删除 Docker 镜像 . . ."
    if docker inspect "$container_name" &>/dev/null; then 
        echo "开始删除名为 $container_name 的容器..."
        docker rm -f "$container_name" &>/dev/null
        if [ -d "/root/PagerMaid-Pyro/$container_name" ]; then
            echo "开始删除 /root/PagerMaid-Pyro/$container_name 文件夹..."
            rm -rf "/root/PagerMaid-Pyro/$container_name"
        fi
        shon_online
    else 
        echo "不存在名为 $container_name 的容器，退出。"; 
        exit 1
    fi
}
shon_online() {
    echo -e "\n欢迎使用 PagerMaid-Pyro Docker 一键安装脚本。\n\n请选择您需要进行的操作:\n  1) 使用 Docker 安装 PagerMaid\n  2) 使用 Docker 卸载 PagerMaid\n  3) 退出脚本\n"
    echo -n "请输入选项对应的数字: "
    read -r N <&1
    case $N in
        1) echo "Docker安装PagerMaid-Pyro"
           start_installation;;
        2) echo "Docker卸载PagerMaid-Pyro"
           cleanup;;
        3) echo "正在退出脚本..."
           exit 0;;
        *) echo "无效的选择!";
           sleep 5s; 
           shon_online;;
    esac
}
shon_online