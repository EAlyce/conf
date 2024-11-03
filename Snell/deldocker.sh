#!/usr/bin/env bash

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 全局容器映射
declare -A container_map
declare -A container_names

# 深度清理容器和所有相关资源
deep_clean_container() {
    local container_id=$1
    local container_name=${container_names[$container_id]}
    
    echo -e "${YELLOW}开始深度清理容器 $container_id ($container_name)...${NC}"
    
    # 获取容器信息
    local container_info=$(docker inspect $container_id)
    local mounts=$(docker inspect --format '{{range .Mounts}}{{println .Source}}{{end}}' $container_id)
    local volumes=$(docker inspect --format '{{range .Mounts}}{{if eq .Type "volume"}}{{println .Name}}{{end}}{{end}}' $container_id)
    local image=$(docker inspect --format '{{.Config.Image}}' $container_id)
    
    # 1. 停止容器
    echo "正在停止容器..."
    docker stop $container_id
    
    # 2. 删除容器
    echo "正在删除容器..."
    docker rm -f $container_id
    
    # 3. 删除持久化目录
    if [ -n "$mounts" ]; then
        echo "正在删除挂载目录..."
        while IFS= read -r mount; do
            if [ -d "$mount" ]; then
                rm -rf "$mount"
                echo "已删除目录: $mount"
            fi
        done <<< "$mounts"
    fi
    
    # 4. 删除容器名称对应的文件夹
    echo "正在查找和删除容器相关文件夹..."
    
    # 查找根目录下的容器文件夹
    if [ -d "/root/${container_name}" ]; then
        rm -rf "/root/${container_name}"
        echo "已删除文件夹: /root/${container_name}"
    fi
    
    # 查找 /root 下一级目录中的容器文件夹
    find /root -maxdepth 2 -type d -name "${container_name}" 2>/dev/null | while read folder; do
        echo "发现容器文件夹: $folder"
        rm -rf "$folder"
        echo "已删除文件夹: $folder"
    done
    
    # 查找 /root 下二级目录中的容器文件夹
    find /root -maxdepth 3 -type d -name "${container_name}" 2>/dev/null | while read folder; do
        echo "发现容器文件夹: $folder"
        rm -rf "$folder"
        echo "已删除文件夹: $folder"
    done
    
    # 5. 删除数据卷
    if [ -n "$volumes" ]; then
        echo "正在删除数据卷..."
        while IFS= read -r volume; do
            docker volume rm $volume
            echo "已删除数据卷: $volume"
        done <<< "$volumes"
    fi
    
    # 6. 删除镜像
    echo "正在删除相关镜像..."
    docker rmi $image
    
    # 7. 清理系统资源
    echo "正在清理系统资源..."
    docker system prune -af --volumes
    
    echo -e "${GREEN}深度清理完成!${NC}"
}

# 显示运行中的容器
list_running_containers() {
    local containers=$(docker ps --format "{{.ID}}:{{.Names}}:{{.Image}}:{{.Status}}")
    
    if [ -z "$containers" ]; then
        echo -e "${RED}没有正在运行的容器${NC}"
        exit 0
    fi
    
    echo -e "${GREEN}正在运行的容器:${NC}"
    container_map=()
    container_names=()
    local index=1
    
    while IFS=: read -r id name image status; do
        echo -e "${GREEN}$index.${NC} $name ($id)"
        echo "   镜像: $image"
        echo "   状态: $status"
        container_map[$index]=$id
        container_names[$id]=$name
        ((index++))
    done <<< "$containers"
    
    echo "0. 退出脚本"
    
    read -p "请选择要删除的容器 (0 退出): " choice
    
    if [ "$choice" = "0" ]; then
        echo "退出脚本"
        exit 0
    elif [ -n "${container_map[$choice]}" ]; then
        deep_clean_container "${container_map[$choice]}"
    else
        echo -e "${RED}无效的选择${NC}"
    fi
}

# 主程序
if ! docker info &>/dev/null; then
    echo -e "${RED}Docker 服务未运行${NC}"
    exit 1
fi

list_running_containers
