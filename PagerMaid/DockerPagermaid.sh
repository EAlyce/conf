#!/usr/bin/env bash

docker_check(){
# 如果系统版本是 Debian 12，则重新添加 Docker 存储库，使用新的 signed-by 选项来指定验证存储库的 GPG 公钥
if [ "$(lsb_release -cs)" = "bookworm" ]; then
    # 重新下载 Docker GPG 公钥并保存到 /usr/share/keyrings/docker-archive-keyring.gpg
sudo rm -f /usr/share/keyrings/docker-archive-keyring.gpg && sudo curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
fi

# 更新 apt 存储库
sudo apt update
sudo apt-get update && sudo apt-get install --only-upgrade docker-ce && sudo rm -rf /sys/fs/cgroup/systemd && sudo mkdir /sys/fs/cgroup/systemd && sudo mount -t cgroup -o none,name=systemd cgroup /sys/fs/cgroup/systemd
sudo apt update && sudo apt install docker.io docker-compose

# 如果未安装，则使用包管理器安装 Docker
if ! command -v docker &> /dev/null; then
    sudo apt install -y docker-ce docker-ce-cli containerd.io
    # 启用 Docker 服务
    sudo systemctl enable --now docker
    echo "Docker 已安装并启动成功"
else
    echo "Docker 已经安装"
fi

# 安装 Docker Compose
if ! command -v docker-compose &> /dev/null; then
    sudo apt install -y docker-compose
    echo "Docker Compose 已安装成功"
else
    echo "Docker Compose 已经安装"
fi
}
start_docker () {
    echo "正在启动 Docker 容器 . . ."
    docker run -dit --restart=always --name="$container_name" --hostname="$container_name" teampgm/pagermaid_pyro <&1
    echo
    echo "开始配置参数 . . ."
    echo "在登录后，请按 Ctrl + C 使容器在后台模式下重新启动。"
    sleep 3
    docker exec -it "$container_name" bash utils/docker-config.sh
    echo
    echo "Docker 重启中，如果失败，请手动重启容器。"
    echo
    docker restart "$container_name"
    echo
    echo "Docker 创建完毕。"
    echo
}

data_persistence () {
    echo "数据持久化可以在升级或重新部署容器时保留配置文件和插件。现在开始进行数据持久化操作 ..."
    data_path="/root/$container_name"
    if [ ! -d "$data_path" ]; then
        mkdir -p "$data_path"
        echo "已创建目录 $data_path"
    fi
    if docker inspect "$container_name" &>/dev/null; then
        docker cp "$container_name":/pagermaid/workdir "$data_path"
        docker stop "$container_name" &>/dev/null
        docker rm "$container_name" &>/dev/null
        docker run -dit -v "$data_path"/workdir:/pagermaid/workdir --restart=always --name="$container_name" --hostname="$container_name" teampgm/pagermaid_pyro <&1
        echo
        echo "数据持久化操作完成。"
        echo
    else
        echo "不存在名为 $container_name 的容器，退出。"
    fi
}

start_installation() {
    docker_check
    build_docker
    start_docker
    data_persistence
    exit
}

build_docker () {
    container_name="PagerMaid-"$(openssl rand -hex 5)
    while docker inspect "$container_name" &>/dev/null; do
        container_name="PagerMaid-"$(openssl rand -hex 5)
    done
    echo "生成的容器名称为 $container_name"
    echo "正在拉取 Docker 镜像 . . ."
    docker pull teampgm/pagermaid_pyro
}

cleanup() {
    printf "请输入 PagerMaid 容器的名称："
    read -r container_name <&1
    if [[ -z $container_name ]]; then
        echo "容器名称不能为空!"
        return
    fi
    echo "开始删除 Docker 镜像 . . ."
    if docker inspect "$container_name" &>/dev/null; then 
        echo "开始删除名为 $container_name 的容器..."
        docker rm -f "$container_name" &>/dev/null
        if [ -d "/root/$container_name" ]; then
            echo "开始删除 /root/$container_name 文件夹..."
            rm -rf "/root/$container_name"
        fi
        shon_online
    else 
        echo "不存在名为 $container_name 的容器，退出。"; 
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
           shon_online;;
    esac
}

shon_online