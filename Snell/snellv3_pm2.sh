FORCE_REGEN=0
if [[ "${1:-}" == "--force" ]] || [[ "${FORCE:-}" == "1" ]]; then
  FORCE_REGEN=1
fi
#!/usr/bin/env bash

set -euo pipefail

SNELL_VERSION="3.0.1"
SNELL_DIR="/root/snell"
SNELL_BIN="/usr/local/bin/snell-server"
SNELL_CONF="${SNELL_DIR}/config.conf"

# multi-instance vars
CUSTOM_NAME=""
CUSTOM_PORT=""
SELECTED_CONF=""
SELECTED_PORT=""
SELECTED_PSK=""
SELECTED_NAME=""

parse_args() {
  while [[ ${#} -gt 0 ]]; do
    case "$1" in
      --name)
        CUSTOM_NAME="${2:-}"; shift 2;;
      --port)
        CUSTOM_PORT="${2:-}"; shift 2;;
      *)
        shift;;
    esac
  done
}

geo_label() {
  local json cc city
  json=$(curl -s --max-time 3 http://ip-api.com/json || true)
  cc=$(printf '%s' "$json" | sed -n 's/.*"countryCode"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)
  city=$(printf '%s' "$json" | sed -n 's/.*"city"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)
  if [[ -n "$cc" || -n "$city" ]]; then
    if [[ -n "$cc" && -n "$city" ]]; then
      echo "${cc}-${city}"
    elif [[ -n "$cc" ]]; then
      echo "${cc}"
    else
      echo "${city}"
    fi
  fi
}

info()  { echo "[信息] $*"; }
warn()  { echo "[注意] $*"; }
err()   { echo "[错误] $*"; }

require_root() {
  if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    err "请使用 root 运行此脚本 (sudo -i / sudo su)。"; exit 1; fi
}

get_pkg_mgr() {
  if command -v apt-get >/dev/null 2>&1; then echo apt; return; fi
  err "仅支持 Debian/Ubuntu (apt) 系统。"; exit 1
}

install_deps() {
  local pmgr="$1"
  if [[ "$pmgr" == "apt" ]]; then
    apt-get update -y
    DEBIAN_FRONTEND=noninteractive apt-get install -y curl wget unzip lsof ca-certificates iproute2
    if ! command -v node >/dev/null 2>&1 && ! command -v nodejs >/dev/null 2>&1; then
      apt-get install -y nodejs
    fi
  fi
  if ! command -v npm >/dev/null 2>&1; then
    if command -v corepack >/dev/null 2>&1; then
      corepack enable >/dev/null 2>&1 || true
      corepack prepare npm@latest --activate >/dev/null 2>&1 || true
    fi
  fi
  if ! command -v npm >/dev/null 2>&1; then
    DEBIAN_FRONTEND=noninteractive apt-get install -y npm || true
  fi
  if ! command -v pm2 >/dev/null 2>&1; then
    npm install -g pm2 --omit=dev
  fi
}

get_arch() {
  local m=$(uname -m)
  case "$m" in
    x86_64|amd64) echo linux-amd64;;
    aarch64|arm64) echo linux-aarch64;;
    armv7l|armv7) echo linux-armv7l;;
    i386|i686) echo linux-i386;;
    *) warn "未知架构: $m，尝试使用 linux-amd64"; echo linux-amd64;;
  esac
}

choose_port() {
  if [[ -n "$CUSTOM_PORT" ]]; then
    if ss -ltn 2>/dev/null | awk '{print $4}' | grep -q ":${CUSTOM_PORT}$"; then
      err "端口已被占用: ${CUSTOM_PORT}"; exit 1
    fi
    echo "$CUSTOM_PORT"; return 0
  fi
  local p
  while true; do
    p=$(( (RANDOM % 45001) + 20000 ))
    if ! ss -ltn 2>/dev/null | awk '{print $4}' | grep -q ":${p}$"; then
      echo "$p"
      return 0
    fi
  done
}

rand_psk() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 16
  else
    # 备用: 读取 /dev/urandom
    head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n'
  fi
}

install_snell() {
  local arch=$(get_arch)
  local url="https://github.com/surge-networks/snell/releases/download/v${SNELL_VERSION}/snell-server-v${SNELL_VERSION}-${arch}.zip"
  local tmpd
  tmpd=$(mktemp -d)
  info "下载 Snell v${SNELL_VERSION}: ${url}"
  if ! curl -fL "$url" -o "$tmpd/snell.zip"; then
    err "下载失败，请检查网络或更换架构/版本。"; exit 1
  fi
  unzip -o "$tmpd/snell.zip" -d "$tmpd" >/dev/null
  install -m 0755 "$tmpd/snell-server" "$SNELL_BIN"
  rm -rf "$tmpd"
  info "Snell 已安装到 ${SNELL_BIN}"
}

write_config() {
  mkdir -p "$SNELL_DIR"
  local port=$(choose_port)
  local psk=$(rand_psk)
  local conf="${SNELL_DIR}/config-${port}.conf"
  cat > "$conf" <<EOF
[snell-server]
listen = 0.0.0.0:${port}
psk = ${psk}
ipv6 = false
obfs = off
version = 3
tfo = false
EOF
  chmod 600 "$conf"
  SELECTED_CONF="$conf"
  SELECTED_PORT="$port"
  SELECTED_PSK="$psk"
  info "配置已写入 ${conf}"
}

start_pm2() {
  local name
  if [[ -n "$CUSTOM_NAME" ]]; then
    name="$CUSTOM_NAME"
  else
    local geo; geo=$(geo_label || true)
    if [[ -n "$geo" ]]; then
      name="${geo}-${SELECTED_PORT}"
    else
      name="snell-${SELECTED_PORT}"
    fi
  fi
  pm2 start "$SNELL_BIN" --name "$name" -- -c "$SELECTED_CONF" || pm2 restart "$name" -- -c "$SELECTED_CONF"
  pm2 save
  SELECTED_NAME="$name"
  if command -v systemctl >/dev/null 2>&1; then
    pm2 startup systemd -u $(whoami) --hp "${HOME:-/root}" >/dev/null || true
  else
    pm2 startup >/dev/null || true
  fi
}

print_nodes() {
  local ip; ip=$(curl -s4m 3 ifconfig.me || curl -s4m 3 ip.sb || hostname -I 2>/dev/null | awk '{print $1}')
  local port="$SELECTED_PORT"
  local psk="$SELECTED_PSK"
  local name
  if [[ -n "$SELECTED_NAME" ]]; then
    name="$SELECTED_NAME"
  else
    name="snell-${port}"
  fi
  echo "proxies:"
  echo "  - {\"name\":\"${name}\",\"server\":\"${ip}\",\"port\":${port},\"psk\":\"${psk}\",\"version\":3,\"tfo\":false,\"reuse\":true,\"type\":\"snell\"}"
}

main() {
  parse_args "$@"
  require_root
  local pmgr; pmgr=$(get_pkg_mgr)
  info "使用包管理器: ${pmgr}"
  install_deps "$pmgr"

  if [[ ! -x "$SNELL_BIN" ]]; then
    install_snell
  else
    info "检测到已安装 snell-server，跳过安装"
  fi

  write_config
  
  start_pm2
  print_nodes
  info "完成！使用 'pm2 logs ${SELECTED_NAME}' 查看运行日志。"
}

main "$@"
