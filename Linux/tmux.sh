#!/usr/bin/env bash

# Part 1: Check and install tmux
if ! command -v tmux &> /dev/null
then
    echo "tmux 未安装,正在安装..."
    if command -v sudo &> /dev/null; then
        sudo apt-get update
        sudo apt-get install -y tmux
    else
        echo "sudo 未找到，请手动安装 tmux。"
        exit 1
    fi
fi

# Part 2: Session handling logic
# Get session names, one per line. Suppress error if no sessions.
SESSION_NAMES=$(tmux list-sessions -F "#{session_name}" 2>/dev/null)

if [ -z "$SESSION_NAMES" ]; then
    # No sessions exist
    echo "没有活动的 tmux 会话。正在创建并进入 'default' 会话..."
    tmux new-session -s "default" # This will attach by default
    exit 0
fi

# Sessions exist. Count them.
NUM_SESSIONS=$(echo "$SESSION_NAMES" | wc -l)
# Check if 'default' session exists (0 if exists, 1 if not)
DEFAULT_SESSION_EXISTS=$(echo "$SESSION_NAMES" | grep -Fxq "default"; echo $?)

if [ "$NUM_SESSIONS" -eq 1 ] && [ "$DEFAULT_SESSION_EXISTS" -eq 0 ]; then
    # Exactly one session exists, and it is 'default'
    echo "仅存在 'default' 会话。正在进入..."
    tmux attach-session -t "default"
    exit 0
else
    # Multiple sessions exist, OR
    # a single session exists but it's NOT 'default', OR
    # 'default' exists along with other sessions.
    # In all these cases, we list all sessions and prompt the user.

    echo "当前活动的 tmux 会话:"
    tmux list-sessions -F "#S" | cat -n # #S is session_name

    read -p "请输入序号进入会话 (或输入 'n' 创建新会话, 'd' 删除会话, 'q' 退出): " user_choice

    if [ "$user_choice" = "n" ]; then
        read -p "请输入新会话名称: " new_session_name
        if [ -z "$new_session_name" ]; then
            echo "会话名称不能为空。"
            exit 1
        fi
        # Check if session already exists
        if tmux has-session -t "$new_session_name" 2>/dev/null; then
            echo "会话 '$new_session_name' 已存在。"
            read -p "是否进入现有会话 '$new_session_name'? (y/n): " attach_existing
            if [ "$attach_existing" = "y" ]; then
                tmux attach-session -t "$new_session_name"
            else
                echo "操作取消。"
            fi
        else
            tmux new-session -s "$new_session_name" -d
            echo "已创建并分离新会话: $new_session_name"
            tmux attach-session -t "$new_session_name"
        fi
    elif [ "$user_choice" = "d" ]; then
        echo "当前 tmux 会话 (选择要删除的):"
        tmux list-sessions -F "#S" | cat -n
        read -p "请输入要删除的会话序号: " del_session_num

        if ! [[ "$del_session_num" =~ ^[0-9]+$ ]]; then
            echo "无效的序号。"
            exit 1
        fi

        session_to_delete_name=$(tmux list-sessions -F "#S" | sed -n "${del_session_num}p")

        if [ -z "$session_to_delete_name" ]; then
            echo "序号 '${del_session_num}' 无效或超出范围。"
            exit 1
        fi
        
        read -p "确定要删除会话 '$session_to_delete_name'? (y/n): " confirm_delete
        if [ "$confirm_delete" = "y" ]; then
            tmux kill-session -t "$session_to_delete_name"
            echo "已删除会话: $session_to_delete_name"
        else
            echo "删除操作已取消。"
        fi

    elif [[ "$user_choice" =~ ^[0-9]+$ ]]; then # User entered a number to select a session
        session_to_attach_name=$(tmux list-sessions -F "#S" | sed -n "${user_choice}p")

        if [ -z "$session_to_attach_name" ]; then
            echo "序号 '${user_choice}' 无效或超出范围。"
            exit 1
        fi
        tmux attach-session -t "$session_to_attach_name"
    elif [ "$user_choice" = "q" ]; then
        echo "退出。"
        exit 0
    else
        echo "无效输入: '$user_choice'"
        exit 1
    fi
fi

