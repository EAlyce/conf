#!/bin/bash

# 定义要访问的链接列表
urls=(
  "https://purge.jsdelivr.net/gh/Blankwonder/surge-list@master/telegram.list"
  "https://purge.jsdelivr.net/gh/EAlyce/conf@main/Rule/OpenAi.list"
  "https://purge.jsdelivr.net/gh/EAlyce/conf@main/Rule/PRIVATE.list"
  "https://purge.jsdelivr.net/gh/EAlyce/conf@main/Rule/Proxy.list"
  "https://purge.jsdelivr.net/gh/EAlyce/conf@main/Rule/DIRECT.list"
  "https://purge.jsdelivr.net/gh/EAlyce/conf@main/Surge.conf"
)

# 循环访问链接
for url in "${urls[@]}"; do
  # 使用 curl 访问链接，指定 HTTP 方法为 GET，添加 -H 模拟用户代理信息
  result=$(curl -s -I -X GET -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36" "$url" | head -n 1)

  # 输出结果
  echo "访问 $url 的结果：$result"
done
