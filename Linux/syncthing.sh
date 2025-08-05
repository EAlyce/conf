#!/bin/bash

# ========================================
# Syncthing 高级同步管理工具
# 依赖: syncthing CLI + jq
# ========================================

set -euo pipefail

# 颜色定义
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# 环境路径配置
configure_environment() {
    echo -e "🔧 配置系统环境..."
    
    # 添加 /root/bin 到 PATH（如果尚未存在）
    if ! grep -qxF 'export PATH=$PATH:/root/bin' /etc/profile; then
        echo 'export PATH=$PATH:/root/bin' >> /etc/profile
        echo -e "✅ 已添加 /root/bin 到系统 PATH"
    fi
    
    # 加载环境变量
    source /etc/profile 2>/dev/null || true
    
    # 去重 PATH 环境变量
    export PATH=$(echo "$PATH" | awk -v RS=: -v ORS=: '!a[$1]++' | sed 's/:$//')
    echo -e "✅ 环境配置完成"
}

# 依赖检查
check_dependencies() {
    echo -e "🔍 检查系统依赖..."
    
    local missing_deps=()
    
    if ! command -v syncthing >/dev/null 2>&1; then
        missing_deps+=("syncthing")
    fi
    
    if ! command -v jq >/dev/null 2>&1; then
        missing_deps+=("jq")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo -e "❌ 缺少必要依赖: ${missing_deps[*]}"
        echo -e "请先安装缺失的依赖包"
        exit 1
    fi
    
    # 测试 syncthing CLI 连接
    echo -e "🔗 测试 Syncthing 连接..."
    if ! timeout 5 syncthing cli --help >/dev/null 2>&1; then
        echo -e "❌ Syncthing CLI 连接失败"
        echo -e "💡 可能原因："
        echo -e "   • Syncthing 服务未运行"
        echo -e "   • API 配置错误"
        echo -e "   • 网络连接问题"
        echo -e "💡 建议：检查 'systemctl status syncthing' 或手动启动服务"
        exit 1
    fi
    
    echo -e "✅ 依赖检查完成"
}

# 获取文件夹列表
get_folders() {
    echo -e "🔍 正在获取同步文件夹列表..." >&2
    
    # 检查 syncthing CLI 是否可用
    if ! syncthing cli --help >/dev/null 2>&1; then
        echo -e "❌ Syncthing CLI 不可用或配置错误" >&2
        echo -e "💡 请确保 Syncthing 已正确安装并配置" >&2
        return 1
    fi
    
    # 尝试获取文件夹配置
    local folders_json
    folders_json=$(syncthing cli config folders 2>/dev/null)
    
    if [[ $? -ne 0 ]]; then
        echo -e "❌ 无法连接到 Syncthing API" >&2
        echo -e "💡 请检查：" >&2
        echo -e "   • Syncthing 服务是否正在运行" >&2
        echo -e "   • API 密钥配置是否正确" >&2
        echo -e "   • 网络连接是否正常" >&2
        return 1
    fi
    
    # 检查 JSON 是否为空数组
    if [[ "$folders_json" == "[]" ]] || [[ -z "$folders_json" ]]; then
        echo -e "⚠️  未发现同步文件夹配置" >&2
        return 2  # 特殊返回码表示无文件夹
    fi
    
    # 解析 JSON 获取文件夹 ID
    local folder_ids
    folder_ids=$(echo "$folders_json" | jq -r '.[].id' 2>/dev/null)
    
    if [[ $? -ne 0 ]] || [[ -z "$folder_ids" ]]; then
        echo -e "❌ JSON 解析失败" >&2
        return 1
    fi
    
    echo "$folder_ids"
}

# 创建示例同步文件夹
create_sample_folder() {
    echo -e "\n🚀 创建示例同步文件夹..."
    
    local folder_path="/root/syncthing-demo"
    local folder_id="demo-folder"
    
    # 创建本地文件夹
    mkdir -p "$folder_path"
    echo "这是 Syncthing 示例文件夹" > "$folder_path/README.txt"
    echo "创建时间: $(date)" >> "$folder_path/README.txt"
    
    echo -e "✅ 已创建本地文件夹: $folder_path"
    
    # 添加到 Syncthing 配置
    if syncthing cli config folders add --folder-id "$folder_id" --folder-path "$folder_path" 2>/dev/null; then
        echo -e "✅ 已添加到 Syncthing 配置"
        echo -e "💡 文件夹 ID: $folder_id"
        echo -e "💡 文件夹路径: $folder_path"
        return 0
    else
        echo -e "❌ 添加到 Syncthing 失败，请手动配置"
        return 1
    fi
}

# 获取设备列表
get_devices() {
    syncthing cli config devices 2>/dev/null | jq -r '.[] | select(.deviceID != "local") | .name // .deviceID' 2>/dev/null || {
        echo -e "❌ 无法获取远程设备列表"
        return 1
    }
}

# 显示 Web UI 配置指导
show_webui_guide() {
    echo -e "\n========================================"
    echo -e "    Syncthing Web UI 配置指导"
    echo -e "========================================"
    
    # 获取 Web UI 地址
    local webui_url="http://localhost:8384"
    echo -e "🌐 Web UI 地址: $webui_url"
    
    echo -e "\n📋 配置步骤："
    echo -e "1. 打开浏览器访问: $webui_url"
    echo -e "2. 点击右上角 '操作' → '添加文件夹'"
    echo -e "3. 设置文件夹标签和路径"
    echo -e "4. 添加远程设备并共享文件夹"
    echo -e "5. 等待初始同步完成"
    
    echo -e "\n💡 配置完成后重新运行此脚本"
    
    # 检查端口是否可访问
    if command -v nc >/dev/null 2>&1; then
        if nc -z localhost 8384 2>/dev/null; then
            echo -e "✅ Web UI 服务正在运行"
        else
            echo -e "❌ Web UI 服务不可访问"
            echo -e "💡 请启动 Syncthing 服务"
        fi
    fi
}

# 处理无文件夹的情况
handle_no_folders() {
    echo -e "\n📂 未发现同步文件夹配置"
    echo -e "请选择处理方式：\n"
    
    echo -e "1) 创建示例文件夹并继续"
    echo -e "2) 打开 Web UI 手动配置"
    echo -e "3) 返回主菜单"
    echo -e "4) 手动输入同步目录"
    echo -e "5) 自动扫描根目录识别共享文件夹"
    
    while true; do
        read -rp "请输入选项 [1-5]：" choice
        case $choice in
            1)
                echo "创建示例文件夹..."
                if create_sample_folder; then
                    echo -e "\n🎉 示例文件夹创建成功！现在可以使用同步功能"
                    return 0
                else
                    echo -e "\n❌ 示例文件夹创建失败"
                    return 1
                fi
                ;;
            2)
                show_webui_guide
                return 1
                ;;
            3)
                echo "返回主菜单..."
                return 1
                ;;
            4)
                read -rp "请输入你想同步的目录路径：" sync_dir
                if [ -d "$sync_dir" ]; then
                    echo "你输入的同步目录为：$sync_dir"
                    # 这里可以继续后续逻辑
                    return 0
                else
                    echo -e "目录不存在，请重新输入。"
                fi
                ;;
            5)
                echo "自动扫描根目录..."
                found_folders=$(find / -type d -name ".stfolder" 2>/dev/null | xargs -I{} dirname {} | sort | uniq)
                if [ -n "$found_folders" ]; then
                    echo -e "发现以下可能的同步文件夹："
                    echo "$found_folders"
                    return 0
                else
                    echo -e "未在根目录下发现共享文件夹。"
                    return 1
                fi
                ;;
            *)
                echo -e "无效选项，请重新输入。"
                ;;
        esac
    done
}

# 显示主菜单
show_menu() {
    echo -e "\n========================================"
    echo -e "    Syncthing 高级同步管理工具"
    echo -e "========================================"
    echo -e "请选择同步策略：\n"
    
    echo -e "0) 退出程序"
    echo -e "1) 临时推送模式 - 本地覆盖所有远程端（一次性执行）"
    echo -e "2) 临时拉取模式 - 指定远程端覆盖本地（一次性执行）"
    echo -e "3) 安全双向同步 - 恢复双向同步且保护文件不被删除（永久策略）"
    echo -e "4) 完全双向同步 - 强对称性同步包含删除操作（永久策略）"
    
    echo -e "\n========================================"
}

# 选择远程设备
select_remote_device() {
    local devices
    devices=$(get_devices)
    
    if [[ -z "$devices" ]]; then
        echo -e "❌ 未发现可用的远程设备"
        return 1
    fi
    
    echo -e "\n可用的远程设备："
    local device_array=()
    local counter=1
    
    while IFS= read -r device; do
        echo -e "$counter) $device"
        device_array+=("$device")
        ((counter++))
    done <<< "$devices"
    
    while true; do
        read -rp $'\n请选择远程设备编号: ' device_choice
        
        if [[ "$device_choice" =~ ^[0-9]+$ ]] && \
           [[ "$device_choice" -ge 1 ]] && \
           [[ "$device_choice" -le ${#device_array[@]} ]]; then
            selected_device="${device_array[$((device_choice-1))]}"
            echo -e "✅ 已选择设备: $selected_device"
            return 0
        else
            echo -e "❌ 无效选择，请输入 1-${#device_array[@]} 之间的数字"
        fi
    done
}

# 模式1：临时推送模式
mode_temporary_push() {
    local folders
    folders=$(get_folders)
    
    if [[ -z "$folders" ]]; then
        echo -e "❌ 未发现同步文件夹"
        return 1
    fi
    
    echo -e "\n🚀 启动临时推送模式..."
    echo -e "⚠️  本地文件将覆盖所有远程端（临时操作）\n"
    
    for folder in $folders; do
        echo -e "📁 处理文件夹: $folder"
        if syncthing cli config folders set "$folder" --type sendonly 2>/dev/null; then
            echo -e "✅ 已设置为仅发送模式"
        else
            echo -e "❌ 设置失败"
        fi
    done
    
    echo -e "\n🎉 临时推送模式配置完成！"
    echo -e "💡 提示: 此为临时设置，如需永久效果请使用其他模式"
}

# 模式2：临时拉取模式
mode_temporary_pull() {
    if ! select_remote_device; then
        return 1
    fi
    
    local folders
    folders=$(get_folders)
    
    if [[ -z "$folders" ]]; then
        echo -e "❌ 未发现同步文件夹"
        return 1
    fi
    
    echo -e "\n🔄 启动临时拉取模式..."
    echo -e "⚠️  远程端 '$selected_device' 将覆盖本地文件\n"
    
    for folder in $folders; do
        echo -e "📁 处理文件夹: $folder"
        
        # 设置为仅接收模式
        if syncthing cli config folders set "$folder" --type receiveonly 2>/dev/null; then
            echo -e "✅ 已设置为仅接收模式"
            
            # 强制还原到远程状态
            echo -e "🔄 正在同步远程状态..."
            if syncthing cli folder revert --folder "$folder" 2>/dev/null; then
                echo -e "✅ 同步完成"
            else
                echo -e "❌ 同步失败"
            fi
        else
            echo -e "❌ 设置失败"
        fi
    done
    
    echo -e "\n🎉 临时拉取模式执行完成！"
}

# 模式3：安全双向同步
mode_safe_bidirectional() {
    local folders
    folders=$(get_folders)
    
    if [[ -z "$folders" ]]; then
        echo -e "❌ 未发现同步文件夹"
        return 1
    fi
    
    echo -e "\n🛡️  启动安全双向同步模式..."
    echo -e "📋 特性: 双向同步 + 文件删除保护\n"
    
    for folder in $folders; do
        echo -e "📁 配置文件夹: $folder"
        
        # 设置为双向同步且忽略删除
        if syncthing cli config folders set "$folder" --type sendreceive --ignore-delete 2>/dev/null; then
            echo -e "✅ 已启用安全双向同步（保护删除）"
        else
            echo -e "❌ 配置失败"
        fi
    done
    
    echo -e "\n🎉 安全双向同步配置完成！"
    echo -e "💡 文件将在各端间同步，但删除操作不会传播"
}

# 模式4：完全双向同步
mode_full_bidirectional() {
    echo -e "\n🔍 检查同步文件夹..."
    
    local folders
    folders=$(get_folders)
    local get_folders_result=$?
    
    # 处理无文件夹的情况
    if [[ $get_folders_result -eq 2 ]]; then
        if ! handle_no_folders; then
            return 1
        fi
        # 重新获取文件夹列表
        folders=$(get_folders)
        get_folders_result=$?
    fi
    
    # 检查是否成功获取文件夹
    if [[ $get_folders_result -ne 0 ]] || [[ -z "$folders" ]]; then
        echo -e "❌ 无法获取同步文件夹"
        echo -e "💡 请确保 Syncthing 服务正在运行且已配置文件夹"
        return 1
    fi
    
    echo -e "📋 发现 $(echo "$folders" | wc -l) 个同步文件夹"
    
    echo -e "\n⚡ 启动完全双向同步模式..."
    echo -e "⚠️  包含强对称性删除操作 - 一端删除，全端删除"
    echo -e "⚠️  此操作具有风险性，请仔细考虑\n"
    
    # 显示即将影响的文件夹
    echo -e "将要配置的文件夹："
    while IFS= read -r folder; do
        echo -e "  📁 $folder"
    done <<< "$folders"
    echo
    
    local confirm
    while true; do
        read -rp "确认启用完全双向同步？[y/N]: " confirm
        case "$confirm" in
            [Yy]|[Yy][Ee][Ss])
                break
                ;;
            [Nn]|[Nn][Oo]|"")
                echo -e "🚫 操作已取消"
                return 0
                ;;
            *)
                echo -e "❌ 请输入 y 或 n"
                ;;
        esac
    done
    
    echo -e "\n🔄 正在配置文件夹..."
    local success_count=0
    local total_count=0
    
    while IFS= read -r folder; do
        echo -e "📁 配置文件夹: $folder"
        ((total_count++))
        
        # 设置为完全双向同步
        if syncthing cli config folders set "$folder" --type sendreceive 2>/dev/null; then
            echo -e "✅ 已启用完全双向同步"
            ((success_count++))
        else
            echo -e "❌ 配置失败 - 请检查文件夹状态"
        fi
    done <<< "$folders"
    
    echo -e "\n========================================"
    if [[ $success_count -eq $total_count ]]; then
        echo -e "🎉 完全双向同步配置完成！"
        echo -e "✅ 成功配置 $success_count/$total_count 个文件夹"
        echo -e "⚠️  注意: 任一端的删除操作将同步到所有设备"
    else
        echo -e "⚠️  部分配置完成"
        echo -e "✅ 成功: $success_count/$total_count 个文件夹"
        echo -e "❌ 失败: $((total_count - success_count)) 个文件夹"
    fi
    echo -e "========================================"
}


# 主程序
main() {
# 极简健壮 Syncthing 管理工具
# 0-4 菜单 + 各模式入口

# ========== 用户需填写 ===========
# ===== Syncthing 多目标配置 =====
# API 地址配置
LOCAL_API_URL="http://127.0.0.1:8384"
REMOTE_API_URL="http://192.168.1.100:8384"   # 请根据需要修改远程IP

# 配置文件路径
CONFIG_FILE="$HOME/.syncthing_shell_config"

# 运行时变量
SYNCTHING_API=""
SYNCTHING_API_KEY=""

# 保存配置到文件
function save_config() {
    local target_type="$1"
    local api_url="$2"
    local api_key="$3"
    
    cat > "$CONFIG_FILE" << EOF
# Syncthing Shell 配置文件
# 自动生成，请勿手动修改
TARGET_TYPE="$target_type"
API_URL="$api_url"
API_KEY="$api_key"
SAVE_TIME="$(date)"
EOF
    
    chmod 600 "$CONFIG_FILE"  # 保护配置文件权限
    echo "配置已保存到: $CONFIG_FILE"
}

# 加载保存的配置
function load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
        if [[ -n "$TARGET_TYPE" && -n "$API_URL" && -n "$API_KEY" ]]; then
            SYNCTHING_API="$API_URL"
            SYNCTHING_API_KEY="$API_KEY"
            echo "已加载保存的配置: $TARGET_TYPE -> $API_URL"
            echo "保存时间: $SAVE_TIME"
            return 0
        fi
    fi
    return 1
}

# 启动时选择目标并输入API密钥
function select_syncthing_target() {
    # 先尝试加载保存的配置
    if load_config; then
        echo ""
        read -rp "是否使用保存的配置? [Y/n]: " use_saved
        if [[ "$use_saved" =~ ^[Nn]$ ]]; then
            echo "将重新配置..."
        else
            echo "使用保存的配置: $SYNCTHING_API"
            return 0
        fi
    fi
    
    # 新配置流程
    echo -e "请选择操作目标："
    echo "1) 本机 Syncthing (http://127.0.0.1:8384)"
    echo "2) 远程 Windows Syncthing"
    
    local target_type=""
    while true; do
        read -rp "请输入选项 [1-2]：" target_choice
        case "$target_choice" in
            1)
                SYNCTHING_API="$LOCAL_API_URL"
                target_type="本机"
                echo -e "已选择本机 Syncthing"
                echo "请输入本机 Syncthing 的 API 密钥："
                echo "(可在 http://127.0.0.1:8384 -> 操作 -> 设置 -> GUI 中找到)"
                read -rp "API 密钥: " SYNCTHING_API_KEY
                break
                ;;
            2)
                target_type="远程"
                echo "请输入远程 Windows Syncthing 的 IP 地址 (默认: 192.168.1.100):"
                read -rp "IP 地址: " remote_ip
                if [[ -z "$remote_ip" ]]; then
                    remote_ip="192.168.1.100"
                fi
                SYNCTHING_API="http://$remote_ip:8384"
                echo -e "已选择远程 Windows Syncthing: $SYNCTHING_API"
                echo "请输入远程 Syncthing 的 API 密钥："
                read -rp "API 密钥: " SYNCTHING_API_KEY
                break
                ;;
            *)
                echo -e "无效选项，请输入 1 或 2"
                ;;
        esac
    done
    
    # 验证API密钥不为空
    if [[ -z "$SYNCTHING_API_KEY" ]]; then
        echo "错误：API 密钥不能为空！"
        exit 1
    fi
    
    # 保存配置
    save_config "$target_type" "$SYNCTHING_API" "$SYNCTHING_API_KEY"
    echo "配置完成：$SYNCTHING_API"
}

# 启动时调用目标选择
select_syncthing_target

# 彩色输出
STH_RED='\033[0;31m'
STH_GREEN='\033[0;32m'
STH_YELLOW='\033[1;33m'
STH_BLUE='\033[0;34m'
STH_CYAN='\033[0;36m'
STH_NC='\033[0m'

# 日志文件
LOG_FILE="syncthing_shell.log"

# 日志函数
function log_info() {
    echo "[INFO] $(date '+%F %T') $1" | tee -a "$LOG_FILE"
}
function log_warn() {
    echo "[WARN] $(date '+%F %T') $1" | tee -a "$LOG_FILE" >&2
}
function log_error() {
    echo "[ERROR] $(date '+%F %T') $1" | tee -a "$LOG_FILE" >&2
}


# 检查依赖
function check_dependencies() {
    for cmd in curl jq; do
        if ! command -v $cmd &>/dev/null; then
            echo -e "❌ 缺少依赖: $cmd，请先安装！"
            exit 1
        fi
    done
}

# 菜单
function show_menu() {
    echo -e "\n========= Syncthing 管理 ========="
    echo "0) 退出程序"
    echo "1) 临时推送模式 - 本地覆盖所有远程端（一次性）"
    echo "2) 临时拉取模式 - 指定远程端覆盖本地（一次性）"
    echo "3) 安全双向同步 - 恢复双向同步且保护文件不被删除（永久策略）"
    echo "4) 完全双向同步 - 强对称性同步包含删除操作（永久策略）"
}

# 通用API请求（带重试和错误处理）
function syncthing_api_get() {
    local endpoint="$1"
    local retries=3
    local delay=2
    local resp
    for ((i=1;i<=retries;i++)); do
        resp=$(curl -s -H "X-API-Key: $SYNCTHING_API_KEY" "$SYNCTHING_API$endpoint")
        if [[ $? -eq 0 && -n "$resp" ]]; then
            echo "$resp"
            return 0
        fi
        sleep $delay
    done
    echo -e "❌ 网络/API请求失败: $endpoint"
    return 1
}

# 获取本地所有同步文件夹ID列表
function get_all_folder_ids() {
    local config
    config=$(syncthing_api_get "/rest/config") || return 1

    echo "$config" | jq -r '.folders[].id' 2>/dev/null
}

# 获取所有远程设备ID列表
function get_all_device_ids() {
    local resp
    resp=$(syncthing_api_get "/rest/config") || return 1
    echo "$resp" | jq -r '.devices[].deviceID'
}

# 设置文件夹为Send Only模式
function set_folder_sendonly() {
    local folder_id="$1"
    local config resp
    config=$(syncthing_api_get "/rest/config") || return 1
    # 修改指定文件夹type为sendonly
    config=$(echo "$config" | jq --arg fid "$folder_id" '(.folders[] | select(.id==$fid) | .type) |= "sendonly"')
    resp=$(curl -s -X POST -H "X-API-Key: $SYNCTHING_API_KEY" -H "Content-Type: application/json" -d "$config" "$SYNCTHING_API/rest/config")
    if [[ $? -ne 0 ]]; then
        echo -e "❌ 设置Send Only失败: $folder_id"
        return 1
    fi
}

# 触发一次同步
function rescan_folder() {
    local folder_id="$1"
    curl -s -X POST -H "X-API-Key: $SYNCTHING_API_KEY" "$SYNCTHING_API/rest/db/scan?folder=$folder_id" >/dev/null
}

# 1) 临时推送模式
function mode_temporary_push() {
    echo -e "执行：临时推送模式..."
    echo -e "警告：本操作将导致本地数据覆盖所有远程端，远程数据可能无法恢复！"
    read -rp "你确定要继续吗？[y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "操作已取消。"
        log_warn "[临时推送] 用户取消操作"
        return 1
    fi
    local folders
    folders=($(get_all_folder_ids))
    if [[ ${#folders[@]} -eq 0 ]]; then
        echo -e "未检测到同步文件夹！"
        return 1
    fi
    log_info "[临时推送] 开始，检测到文件夹数量：${#folders[@]}"
    for fid in "${folders[@]}"; do
        log_info "[临时推送] 设置 $fid 为Send Only并推送"
        echo -e "设置 $fid 为Send Only并推送..."
        set_folder_sendonly "$fid" || log_error "[临时推送] 设置Send Only失败: $fid"
        rescan_folder "$fid"
    done
    log_info "[临时推送] 完成。"
    echo -e "本地已覆盖所有远程端（Send Only），请确认远程端已同步！"
}

# 2) 临时拉取模式
function mode_temporary_pull() {
    echo -e "执行：临时拉取模式..."
    echo -e "警告：本操作将导致本地数据被远程端覆盖，原本地数据可能无法恢复！"
    read -rp "你确定要继续吗？[y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "操作已取消。"
        log_warn "[临时拉取] 用户取消操作"
        return 1
    fi
    local devices device_ids device_names i selected_id selected_name folders
    # 获取所有远程设备ID和名称
    devices=$(syncthing_api_get "/rest/config") || return 1
    mapfile -t device_ids < <(echo "$devices" | jq -r '.devices[].deviceID')
    mapfile -t device_names < <(echo "$devices" | jq -r '.devices[].name')
    if [[ ${#device_ids[@]} -eq 0 ]]; then
        echo -e "未检测到远程设备！"
        return 1
    fi
    echo -e "请选择要拉取的远程端："
    for i in "${!device_ids[@]}"; do
        echo "$i) ${device_names[$i]} [${device_ids[$i]}]"
    done
    read -rp "输入编号: " idx
    if ! [[ "$idx" =~ ^[0-9]+$ ]] || (( idx < 0 || idx >= ${#device_ids[@]} )); then
        echo -e "无效编号"
        return 1
    fi
    selected_id="${device_ids[$idx]}"
    selected_name="${device_names[$idx]}"
    echo -e "将从 $selected_name [$selected_id] 拉取所有数据覆盖本地..."
    # 设置所有文件夹为Receive Only
    folders=($(get_all_folder_ids))
    log_info "[临时拉取] 用户选择拉取设备 $selected_name [$selected_id]，文件夹数量：${#folders[@]}"
    for fid in "${folders[@]}"; do
        log_info "[临时拉取] 设置 $fid 为Receive Only"
        set_folder_receiveonly "$fid" || log_error "[临时拉取] 设置Receive Only失败: $fid"
        rescan_folder "$fid"
    done
    log_info "[临时拉取] 完成。"
    echo -e "已从指定远程端拉取数据覆盖本地（Receive Only），请确认本地已同步！"
}

# 设置文件夹为Receive Only模式
function set_folder_receiveonly() {
    local folder_id="$1"
    local config resp
    config=$(syncthing_api_get "/rest/config") || return 1
    config=$(echo "$config" | jq --arg fid "$folder_id" '(.folders[] | select(.id==$fid) | .type) |= "receiveonly"')
    resp=$(curl -s -X POST -H "X-API-Key: $SYNCTHING_API_KEY" -H "Content-Type: application/json" -d "$config" "$SYNCTHING_API/rest/config")
    if [[ $? -ne 0 ]]; then
        echo -e "❌ 设置Receive Only失败: $folder_id"
        return 1
    fi
}

# 3) 安全双向同步
function mode_safe_bidirectional() {
    echo -e "执行：安全双向同步..."
    local folders fid config resp
    folders=($(get_all_folder_ids))
    if [[ ${#folders[@]} -eq 0 ]]; then
        echo -e "未检测到同步文件夹！"
        return 1
    fi
    log_info "[安全双向] 开始，检测到文件夹数量：${#folders[@]}"
    for fid in "${folders[@]}"; do
        log_info "[安全双向] 设置 $fid 为 sendreceive + ignoreDelete=true"
        config=$(syncthing_api_get "/rest/config") || { log_error "[安全双向] 获取配置失败: $fid"; continue; }
        # 修改为 sendreceive 并设置 ignoreDelete=true
        config=$(echo "$config" | jq --arg fid "$fid" '(.folders[] | select(.id==$fid) | .type) |= "sendreceive" | (.folders[] | select(.id==$fid) | .ignoreDelete) |= true')
        resp=$(curl -s -X POST -H "X-API-Key: $SYNCTHING_API_KEY" -H "Content-Type: application/json" -d "$config" "$SYNCTHING_API/rest/config")
        if [[ $? -ne 0 ]]; then
            log_error "[安全双向] 设置失败: $fid"
            echo -e "❌ 设置安全双向同步失败: $fid"
        else
            echo -e "文件夹 $fid 已保护本地文件不被删除（安全双向）"
            rescan_folder "$fid"
        fi
    done
    log_info "[安全双向] 完成。"
    echo -e "所有文件夹已设置为安全双向同步（保护本地文件不被删除）！"
}

# 4) 完全双向同步
function mode_full_bidirectional() {
    echo -e "执行：完全双向同步..."
    echo -e "警告：本操作将允许所有端的删除操作，数据删除后不可恢复！"
    

    
    read -rp "你确定要继续吗？[y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "操作已取消。"
        log_warn "[完全双向] 用户取消操作"
        return 1
    fi
    local folders fid config resp
    folders=($(get_all_folder_ids))
    if [[ ${#folders[@]} -eq 0 ]]; then
        echo -e "未检测到同步文件夹！"
        return 1
    fi
    log_info "[完全双向] 开始，检测到文件夹数量：${#folders[@]}"
    for fid in "${folders[@]}"; do
        log_info "[完全双向] 设置 $fid 为 sendreceive + ignoreDelete=false"
        config=$(syncthing_api_get "/rest/config") || continue
        # 健壮性校验
        if [[ -z "$config" ]] || ! echo "$config" | jq empty 2>/dev/null; then
            echo -e "❌ 获取配置失败，API 返回内容异常！请检查 Syncthing 服务和 API 配置。"
            log_error "[完全双向] 获取配置失败，返回内容：$config"
            continue
        fi
        config=$(echo "$config" | jq --arg fid "$fid" '(.folders[] | select(.id==$fid) | .type) |= "sendreceive" | (.folders[] | select(.id==$fid) | .ignoreDelete) |= false')
        resp=$(curl -s -X POST -H "X-API-Key: $SYNCTHING_API_KEY" -H "Content-Type: application/json" -d "$config" "$SYNCTHING_API/rest/config")
        if [[ $? -ne 0 ]]; then
            log_error "[完全双向] 设置失败: $fid"
            echo -e "❌ 设置完全双向同步失败: $fid"
        else
            echo -e "文件夹 $fid 已设置为完全双向同步（允许删除）"
            rescan_folder "$fid"
        fi
    done
    log_info "[完全双向] 完成。"
    echo -e "所有文件夹已设置为完全双向同步（允许删除操作）！"
}

# 主流程
check_dependencies
while true; do
    show_menu
    read -rp $'\n请输入选项 [0-4]: ' choice
    case "$choice" in
        0)
            echo -e "\n👋 感谢使用 Syncthing 管理工具！"
            exit 0
            ;;
        1)
            mode_temporary_push
            ;;
        2)
            mode_temporary_pull
            ;;
        3)
            mode_safe_bidirectional
            ;;
        4)
            mode_full_bidirectional
            ;;
        *)
            echo -e "\n❌ 无效选项，请输入 0-4 之间的数字"
            ;;
    esac
    echo -e "\n按 Enter 键继续..."
    read -r
done
}

# 脚本入口
main "$@"
