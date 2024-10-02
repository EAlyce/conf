#!/usr/bin/env bash

# 删除容器和相关挂载卷的函数
remove_container() {
  local selected_container=$1
  local container_name=$(docker ps --filter "id=$selected_container" --format "{{.Names}}")

  if [ -n "$selected_container" ]; then
    echo "正在停止容器 $selected_container ..."
    docker stop $selected_container

    echo "正在删除容器 $selected_container ..."
    docker rm $selected_container

    if [ $? -eq 0 ]; then
      echo "容器 $selected_container 已删除。"
    else
      echo "容器 $selected_container 删除失败。"
      return 1
    fi

    # 获取容器的挂载点
    local volume_mounts=$(docker inspect --format '{{ range .Mounts }}{{ .Source }} {{ end }}' $selected_container)

    if [ -n "$volume_mounts" ]; then
      echo "找到挂载卷: $volume_mounts"
      for mount in $volume_mounts; do
        if [ -d "$mount" ]; then
          echo "正在删除挂载卷文件夹 $mount ..."
          rm -rf "$mount"
          echo "文件夹 $mount 已删除。"
        fi
      done
    else
      echo "未找到挂载卷，可能没有持久化卷。"
    fi

    # 清理未使用的镜像、构建缓存和其他无用资源
    echo "正在清理未使用的镜像 ..."
    docker image prune --all -f

    echo "正在清理构建缓存 ..."
    docker builder prune --all -f

    echo "正在清理系统未使用的资源（包括卷）..."
    docker system prune -a --volumes -f

    echo "清理完成。"
  else
    echo "未知错误，无法找到容器。"
  fi
}

# 显示容器列表并选择要删除的容器
list_containers() {
  while true; do
    CONTAINERS=$(docker ps -a --format "{{.ID}}:{{.Names}}")

    if [ -z "$CONTAINERS" ]; then
      echo "没有找到 Docker 容器."
      exit 0
    fi

    echo "选择要卸载的容器："
    declare -A container_map
    index=1

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
