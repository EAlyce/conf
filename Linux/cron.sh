#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 检查root权限
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}请使用root权限运行此脚本${NC}"
        exit 1
    fi
}

# 查找系统定时任务目录
find_system_cron() {
    echo -e "\n${GREEN}=== 系统定时任务目录 ===${NC}"
    
    # /etc/crontab
    echo -e "\n${YELLOW}1. /etc/crontab 内容：${NC}"
    if [ -f /etc/crontab ]; then
        grep -v '^#' /etc/crontab | grep -v '^$'
    fi

    # /etc/cron.d/
    echo -e "\n${YELLOW}2. /etc/cron.d/ 目录下的定时任务：${NC}"
    if [ -d /etc/cron.d ]; then
        for file in /etc/cron.d/*; do
            if [ -f "$file" ] && [ "$(basename "$file")" != "." ] && [ "$(basename "$file")" != ".." ]; then
                echo -e "${BLUE}文件：$file${NC}"
                grep -v '^#' "$file" | grep -v '^$'
            fi
        done
    fi

    # cron.hourly/daily/weekly/monthly
    for period in hourly daily weekly monthly; do
        echo -e "\n${YELLOW}3. /etc/cron.$period/ 目录下的脚本：${NC}"
        if [ -d "/etc/cron.$period" ]; then
            ls -l "/etc/cron.$period"
        fi
    done
}

# 查找systemd timer单元
find_systemd_timers() {
    echo -e "\n${GREEN}=== Systemd Timer单元 ===${NC}"
    echo -e "${YELLOW}1. 活跃的timer单元：${NC}"
    systemctl list-timers --all

    echo -e "\n${YELLOW}2. 所有timer单元文件：${NC}"
    find /etc/systemd/system /usr/lib/systemd/system -name "*.timer" -type f -exec echo -e "${BLUE}Timer文件：${NC}{}" \; -exec cat {} \;
}

# 查找anacron任务
find_anacron() {
    echo -e "\n${GREEN}=== Anacron任务 ===${NC}"
    if [ -f /etc/anacrontab ]; then
        echo -e "${YELLOW}/etc/anacrontab 内容：${NC}"
        grep -v '^#' /etc/anacrontab | grep -v '^$'
    fi
}

# 查找所有用户的crontab
find_user_crontabs() {
    echo -e "\n${GREEN}=== 用户Crontab ===${NC}"
    for user in $(cut -d: -f1 /etc/passwd); do
        crontab_content=$(crontab -l -u "$user" 2>/dev/null)
        if [ -n "$crontab_content" ]; then
            echo -e "${YELLOW}用户 $user 的crontab：${NC}"
            echo "$crontab_content" | grep -v '^#' | grep -v '^$'
        fi
    done
}

# 查找at任务
find_at_jobs() {
    echo -e "\n${GREEN}=== At任务 ===${NC}"
    if command -v atq >/dev/null 2>&1; then
        echo -e "${YELLOW}当前的at任务队列：${NC}"
        atq
    fi
}

# 检查特殊位置
check_special_locations() {
    echo -e "\n${GREEN}=== 其他可能的定时任务位置 ===${NC}"
    
    # check /var/spool/cron/
    if [ -d /var/spool/cron ]; then
        echo -e "${YELLOW}1. /var/spool/cron/ 目录内容：${NC}"
        ls -la /var/spool/cron/
    fi
    
    # check /var/spool/anacron/
    if [ -d /var/spool/anacron ]; then
        echo -e "\n${YELLOW}2. /var/spool/anacron/ 目录内容：${NC}"
        ls -la /var/spool/anacron/
    fi
}

# 生成报告
generate_report() {
    local report_file="/tmp/cron_report_$(date +%Y%m%d_%H%M%S).txt"
    {
        echo "=== 系统定时任务报告 ==="
        echo "生成时间：$(date)"
        echo "主机名：$(hostname)"
        echo "系统信息：$(uname -a)"
        echo
        
        # 重定向所有查找函数的输出
        find_system_cron
        find_systemd_timers
        find_anacron
        find_user_crontabs
        find_at_jobs
        check_special_locations
        
    } | tee "$report_file"
    
    echo -e "\n${GREEN}报告已保存到：$report_file${NC}"
}

# 主程序
main() {
    check_root
    echo -e "${GREEN}开始查找系统中的所有定时任务...${NC}"
    generate_report
}

# 运行主程序
main "$@"
