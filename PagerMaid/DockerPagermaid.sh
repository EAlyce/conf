#!/usr/bin/env bash

docker_check() {
    sudo pkill -9 apt dpkg || true
    sudo rm -f /var/lib/dpkg/lock-frontend /var/lib/apt/lists/lock
    sudo dpkg --configure -a

    update_docker_repository() {
        local repo_keyring="/usr/share/keyrings/docker-archive-keyring.gpg"
        local repo_url="https://download.docker.com/linux/debian"

        sudo rm -f "$repo_keyring"
        sudo curl -fsSL "$repo_url/gpg" | sudo gpg --dearmor -o "$repo_keyring"

        echo "deb [arch=amd64 signed-by=$repo_keyring] $repo_url $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    }

    if [ "$(lsb_release -cs)" = "bookworm" ]; then
        update_docker_repository
    fi

    sudo apt update

    install_package_if_not_exists() {
        local package_name="$1"
        if ! command -v "$package_name" &> /dev/null; then
            sudo apt install -y "$package_name"
            echo "$package_name 已安装成功"
        else
            echo "$package_name 已经安装"
        fi
    }

    install_package_if_not_exists "docker-ce"
    install_package_if_not_exists "docker-ce-cli"
    install_package_if_not_exists "containerd.io"

    sudo systemctl enable --now docker

    install_package_if_not_exists "docker-compose"

    check_python_version() {
        local docker_python_version=$(docker run --rm python:latest python3 --version | awk '{print $2}')
        local required_python_version="3.9.2"

        if [[ "$(printf '%s\n' "$required_python_version" "$docker_python_version" | sort -V | head -n1)" == "$required_python_version" ]]; then
            echo "Docker中的Python版本 ($docker_python_version) 大于 3.9.2"
        else
            echo "Docker中的Python版本 ($docker_python_version) 不符合要求，将尝试更新升级..."
            docker pull python:latest
            docker_python_version=$(docker run --rm python:latest python3 --version | awk '{print $2}')

            if [[ "$(printf '%s\n' "$required_python_version" "$docker_python_version" | sort -V | head -n1)" == "$required_python_version" ]]; then
                echo "Docker中的Python版本已成功更新为 $docker_python_version"
            else
                echo "错误: Docker中的Python版本无法更新升级。请手动检查并更新。"
                exit 1
            fi
        fi
    }

    check_python_version
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