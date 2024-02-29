#!/bin/bash

# 检测是否安装了Docker
if ! command -v docker &> /dev/null; then
  echo "Docker未安装，正在自动安装..."
  sudo apt-get update
  sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
  sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
  sudo apt-get update
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io
  echo "Docker已成功安装。"
fi

# 更新Docker内所有包
echo "正在更新Docker内所有包..."
sudo docker system prune -a -f
sudo docker images | awk '(NR>1) && ($2!="<none>") {print $1":"$2}' | xargs -L1 docker pull

# 验证API_ID
validate_api_id() {
  local api_id="$1"
  [[ "$api_id" =~ ^[0-9]{8,10}$ ]]
}

# 验证API_HASH
validate_api_hash() {
  local api_hash="$1"
  [[ "$api_hash" =~ ^[a-fA-F0-9]{32}$ ]]
}

# 验证容器名称
validate_container_name() {
  local name="$1"
  [[ "$name" =~ ^[a-zA-Z0-9][a-zA-Z0-9_.-]+$ ]] && [ ! -d "/$name" ]
}

read -p "请输入容器名称（只能包含字母、数字、下划线、点和短横线）: " container_name

# 验证容器名称
while true; do
  if validate_container_name "$container_name"; then
    if [ "$(docker ps -a -q -f name=^/${container_name}$)" = "" ]; then
      break
    else
      echo "容器名称已存在，请选择其他名称。"
    fi
  else
    echo "容器名称格式不正确或与系统文件夹同名。"
  fi
  read -p "请输入容器名称（只能包含字母、数字、下划线、点和短横线）: " container_name
done

while true; do
  read -p "请输入API_ID: " api_id
  if validate_api_id "$api_id"; then
    break
  else
    echo "API_ID格式不正确，请输入8到10位数字。"
  fi
done

while true; do
  read -p "请输入API_HASH: " api_hash
  if validate_api_hash "$api_hash"; then
    break
  else
    echo "API_HASH格式不正确，请输入32位的十六进制数。"
  fi
done

data_path="${HOME}/TMBdata/${container_name}"

mkdir -p "$data_path"

docker run -it --restart=always --name=${container_name} \
  -e TZ=Asia/Shanghai \
  -e API_ID=${api_id} \
  -e API_HASH=${api_hash} \
  -v ${data_path}:/TMBot/data \
  noreph/tmbot