#!/usr/bin/env bash

docker_check() {
    # 检查是否已安装 Docker
    if ! command -v docker &> /dev/null; then
        echo "Docker 未安装。正在安装 Docker..."

        # 更新包列表并安装 Docker
        sudo apt update
        sudo apt install -y docker.io

        # 启用并启动 Docker 服务
        sudo systemctl enable --now docker

        # 验证 Docker 安装
        if command -v docker &> /dev/null; then
            echo "Docker 安装成功。"
        else
            echo "Docker 安装失败。"
            return 1
        fi
    else
        echo "Docker 已经安装。"
    fi

    # 检查是否已安装 Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        echo "Docker Compose 未安装。正在安装 Docker Compose..."

        # 安装 Docker Compose
        sudo apt install -y docker-compose

        # 验证 Docker Compose 安装
        if command -v docker-compose &> /dev/null; then
            echo "Docker Compose 安装成功。"
        else
            echo "Docker Compose 安装失败。"
            return 1
        fi
    else
        echo "Docker Compose 已经安装。"
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

data_persistence() {
    echo "开始数据持久化操作..."
    data_path="/root/$container_name"
    mkdir -p "$data_path"

    if ! docker inspect "$container_name" &>/dev/null; then
        echo "不存在名为 $container_name 的容器，退出。"
        return 1
    fi

    docker cp "$container_name":/pagermaid/workdir "$data_path"
    docker stop "$container_name" &>/dev/null
    docker rm "$container_name" &>/dev/null
    docker run -dit -v "$data_path"/workdir:/pagermaid/workdir --restart=always --name="$container_name" --hostname="$container_name" teampgm/pagermaid_pyro

    # 检查并安装 cron
    if ! command -v crontab &> /dev/null; then
        echo "正在安装 cron..."
        sudo apt-get update && sudo apt-get install -y cron
        sudo systemctl enable --now cron
    fi

    if command -v crontab &> /dev/null; then
        cron_job="43 * * * * docker restart $container_name"
        (crontab -l 2>/dev/null; echo "$cron_job") | sort - | uniq - | crontab -
        echo "数据持久化完成。已添加 cron 任务，每小时 43 分重启 $container_name 容器。"
    else
        echo "cron 安装失败，无法添加定时重启任务。"
        return 1
    fi
}

start_installation() {
    docker_check
    build_docker
    start_docker
    data_persistence
    exit
}

build_docker() {
    local prefix="PagerMaid-"
    container_name=""
    while [ -z "$container_name" ] || docker inspect "$container_name" &>/dev/null; do
        container_name="${prefix}$(openssl rand -hex 5)"
    done
    echo "生成的容器名称为 $container_name"
    echo "正在拉取 Docker 镜像 ..."
    docker pull teampgm/pagermaid_pyro
}

cleanup() {
    read -rp "请输入 PagerMaid 容器的名称：" container_name
    [ -z "$container_name" ] && { echo "容器名称不能为空!"; return 1; }

    if ! docker inspect "$container_name" &>/dev/null; then 
        echo "不存在名为 $container_name 的容器，退出。"
        return 1
    fi

    echo "正在删除名为 $container_name 的容器和相关资源..."
    docker rm -f "$container_name" &>/dev/null
    rm -rf "/root/$container_name" 2>/dev/null

    shon_online
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
