#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# Constants
readonly PRIMARY_COUNTRY_URL="https://github.com/P3TERX/GeoLite.mmdb/raw/download/GeoLite2-Country.mmdb"
readonly PRIMARY_ASN_URL="https://github.com/P3TERX/GeoLite.mmdb/raw/download/GeoLite2-ASN.mmdb"
readonly BACKUP_COUNTRY_URL="https://raw.githubusercontent.com/Loyalsoldier/geoip/release/GeoLite2-Country.mmdb"
readonly BACKUP_ASN_URL="https://raw.githubusercontent.com/Loyalsoldier/geoip/release/GeoLite2-ASN.mmdb"
readonly DATA_DIR="/root/sub-store-data"
readonly MMDB_DIR="/opt/mmdb"
readonly LOG_FILE="/var/log/sub-store-setup.log"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

error() {
    log "错误: $*" >&2
    exit 1
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "此脚本需要 root 权限运行"
    fi
}

install_dependencies() {
    local missing_deps=()
    
    for cmd in curl cron docker docker-compose; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log "安装缺失的依赖: ${missing_deps[*]}"
        apt-get update -qq || error "更新软件包列表失败"
        
        for dep in "${missing_deps[@]}"; do
            case "$dep" in
                docker|docker-compose)
                    log "请手动安装 $dep"
                    error "$dep 未找到，请先安装它"
                    ;;
                *)
                    apt-get install -y "$dep" || error "安装 $dep 失败"
                    ;;
            esac
        done
    else
        log "所有必要的依赖已安装"
    fi
    
    systemctl is-active --quiet cron || systemctl start cron
    systemctl is-active --quiet docker || systemctl start docker
}

download_file() {
    local dest="$1"
    local primary_url="$2"
    local backup_url="$3"
    local max_retries=3
    local retry=0
    
    while [[ $retry -lt $max_retries ]]; do
        if curl -sSL --connect-timeout 10 --retry 3 -o "$dest" "$primary_url"; then
            return 0
        fi
        log "从主源下载失败，尝试备用源..."
        if curl -sSL --connect-timeout 10 --retry 3 -o "$dest" "$backup_url"; then
            return 0
        fi
        ((retry++))
        sleep 2
    done
    error "下载文件失败: $dest"
}

setup_mmdb() {
    log "设置 MMDB 文件..."
    
    mkdir -p "$MMDB_DIR"
    
    download_file "$MMDB_DIR/GeoLite2-Country.mmdb" "$PRIMARY_COUNTRY_URL" "$BACKUP_COUNTRY_URL"
    download_file "$MMDB_DIR/GeoLite2-ASN.mmdb" "$PRIMARY_ASN_URL" "$BACKUP_ASN_URL"
    
    local update_cmd="0 */6 * * * /usr/bin/curl -sSL -o $MMDB_DIR/GeoLite2-Country.mmdb $PRIMARY_COUNTRY_URL || /usr/bin/curl -sSL -o $MMDB_DIR/GeoLite2-Country.mmdb $BACKUP_COUNTRY_URL; /usr/bin/curl -sSL -o $MMDB_DIR/GeoLite2-ASN.mmdb $PRIMARY_ASN_URL || /usr/bin/curl -sSL -o $MMDB_DIR/GeoLite2-ASN.mmdb $BACKUP_ASN_URL"
    
    (crontab -l 2>/dev/null | grep -v "GeoLite2"; echo "$update_cmd") | sort -u | crontab -
}

get_public_ip() {
    local ip_services=("https://ifconfig.me" "https://ipinfo.io/ip" "https://icanhazip.com")
    local timeout=5
    
    for service in "${ip_services[@]}"; do
        if public_ip=$(curl -sSf --connect-timeout "$timeout" "$service"); then
            if [[ $public_ip =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]; then
                echo "$public_ip"
                return 0
            fi
        fi
        sleep 1
    done
    
    error "无法获取公共 IP 地址"
}

setup_docker() {
    log "配置 Docker 服务..."
    
    local secret_key
    secret_key=$(openssl rand -hex 32)
    
    mkdir -p "$DATA_DIR"
    
    docker rm -f sub-store >/dev/null 2>&1 || true
    docker compose -p sub-store down >/dev/null 2>&1 || true
    
    cat > docker-compose.yml <<EOF
name: sub-store
services:
  sub-store:
    image: xream/sub-store:http-meta
    container_name: sub-store
    restart: always
    environment:
      SUB_STORE_BACKEND_UPLOAD_CRON: "55 23 * * *"
      SUB_STORE_FRONTEND_BACKEND_PATH: "/$secret_key"
      SUB_STORE_MMDB_COUNTRY_PATH: "$MMDB_DIR/GeoLite2-Country.mmdb"
      SUB_STORE_MMDB_ASN_PATH: "$MMDB_DIR/GeoLite2-ASN.mmdb"
    ports:
      - "3001:3001"
    volumes:
      - $DATA_DIR:/opt/app/data
      - $MMDB_DIR:$MMDB_DIR:ro
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3001"]
      interval: 30s
      timeout: 10s
      retries: 3
EOF
    
    log "启动 Docker 服务..."
    docker compose -p sub-store pull
    docker compose -p sub-store up -d
    
    local update_cmd="0 3 * * * cd $(pwd) && docker compose -p sub-store pull && docker compose -p sub-store up -d"
    (crontab -l 2>/dev/null | grep -v "sub-store"; echo "$update_cmd") | sort -u | crontab -
    
    local max_wait=30
    local count=0
    while [[ $count -lt $max_wait ]]; do
        if curl -s "http://127.0.0.1:3001" >/dev/null; then
            print_success_info "$secret_key"
            return 0
        fi
        ((count++))
        sleep 1
    done
    
    log "警告: 服务启动超时，但可能仍在进行中"
    print_success_info "$secret_key"
}

print_success_info() {
    local secret_key="$1"
    local public_ip
    public_ip=$(get_public_ip)
    
    cat <<EOF

部署完成！您的 Sub-Store 信息如下：

面板地址: http://${public_ip}:3001
后端地址: http://${public_ip}:3001/${secret_key}

请保存好以上信息！
EOF
}

main() {
    check_root
    install_dependencies
    setup_mmdb
    setup_docker
}

trap 'error "脚本执行失败，行号: $LINENO"' ERR

main
