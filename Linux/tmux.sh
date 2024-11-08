#!/usr/bin/env bash

if ! command -v tmux &> /dev/null
then
    echo "tmux 未安装,正在安装..."
    sudo apt-get update
    sudo apt-get install -y tmux
fi


echo "当前 tmux 会话:"
tmux list-sessions | cat -n

read -p "请输入序号进入会话(或输入 'n' 创建新会话, 'd' 删除会话): " session_input
if [ "$session_input" = "n" ]
then

    read -p "请输入新会话名称: " new_session_name
    tmux new-session -s "$new_session_name" -d
    echo "已创建新会话: $new_session_name"
    tmux attach-session -t "$new_session_name"
elif [ "$session_input" = "d" ]
then

    echo "当前 tmux 会话:"
    tmux list-sessions | cat -n
    read -p "请输入要删除的会话序号: " del_session_num
    del_session_name=$(tmux list-sessions | sed -n "${del_session_num}p" | cut -d':' -f1)
    tmux kill-session -t "$del_session_name"
    echo "已删除会话: $del_session_name"
else

    session_name=$(tmux list-sessions | sed -n "${session_input}p" | cut -d':' -f1)
    tmux attach-session -t "$session_name"
fi