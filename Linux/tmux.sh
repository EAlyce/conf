#!/usr/bin/env bash

if ! command -v tmux &> /dev/null
then
    echo "tmux 未安装,正在安装..."
    sudo apt-get update
    sudo apt-get install -y tmux
fi

echo "当前 tmux 会话:"
tmux list-sessions | cat -n

read -p "请输入序号进入会话: " session_num
session_name=$(tmux list-sessions | sed -n "${session_num}p" | cut -d':' -f1)
tmux attach-session -t "$session_name"

if [ -z "$session_name" ]
then
    read -p "当前没有 tmux 会话,是否创建一个新会话?(y/n) " create_new
    if [ "$create_new" = "y" ]
    then
        session_name="tmux_$(openssl rand -hex 4)"
        tmux new-session -s "$session_name" -d
        echo "已创建新会话: $session_name"
        tmux attach-session -t "$session_name"
    fi
fi