#!/bin/bash

remove_container() {
  local selected_container=$1
  local container_name=$(docker ps --filter "id=$selected_container" --format "{{.Names}}")

  if [ -n "$selected_container" ]; then
    echo "正在停止容器 $selected_container ..."
    docker stop $selected_container

    echo "正在删除容器 $selected_container ..."
    docker rm $selected_container
    echo "容器 $selected_container 已删除。"

    local folder="/root/snelldocker/$container_name"
    if [ -d "$folder" ]; then
      echo "正在删除与容器名 $container_name 相同的文件夹 $folder ..."
      sudo rm -rf "$folder"
	  docker system prune -af --volumes > /dev/null
      echo "文件夹 $folder 已删除。"
    fi
  else
    echo "未知错误，无法找到容器。"
  fi
}

list_containers() {
  while true; do
    CONTAINERS=$(docker ps -a --format "{{.ID}}:{{.Names}}")

    if [ -z "$CONTAINERS" ]; then
      echo "没有找到 Docker 容器."
      exit 0
    fi

    echo "选择要卸载的容器："
    declare -A container_map
    index=1  # 从 1 开始计数

    for container in $CONTAINERS; do
      id=$(echo $container | cut -d ':' -f1)
      name=$(echo $container | cut -d ':' -f2)
      echo "$index. $name ($id)"
      container_map["$index"]=$id
      ((index++))
    done

    echo "0. 退出脚本"
    container_map["0"]="exit"

    read -p "输入选择（输入数字）： " choice

    if [[ "${container_map["$choice"]}" == "exit" ]]; then
      exit 0
    elif [[ "${container_map["$choice"]}" ]]; then
      remove_container "${container_map["$choice"]}"
    else
      echo "输入无效，请输入有效的数字."
    fi
  done
}

list_containers
