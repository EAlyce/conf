#!/usr/bin/env bash
# One-click installer for PagerMaid-Modify (Debian/Ubuntu)
# Features:
# 1) Install dependencies and clone/update repo
# 2) Interactive input for api_id and api_hash
# 3) Write values into config.yml
# 4) Optional systemd service creation and start
set -euo pipefail

APP_DIR="/root/PagerMaid-Modify"
REPO_URL="https://github.com/TeamPGM/PagerMaid-Modify.git"
PY_VER_DEFAULT="3.13.1"  # default Python to build if system one is too old
PY_BIN="python3"         # will be set to the detected/built python
VENV_DIR="/root/PagerMaid-Modify/.venv"
START_TIMEOUT="180"      # 最长等待启动日志秒数（可用环境变量覆盖）
# 启动成功日志匹配（可用环境变量覆盖），包含中英文常见形式
START_REGEX="PagerMaid-Modify 已启动|已启动.*-help|PagerMaid-Modify (has )?started|Started PagerMaid-Modify|Bot started"

green() { echo -e "\033[32m$*\033[0m"; }

# 仅保留最新的备份目录，删除其余（默认匹配 /root/PMM_backup_*）
prune_old_backups()
{
  local keep=${1:-1}
  local pattern=${2:-"/root/PMM_backup_*"}
  # 收集备份目录，按修改时间倒序
  # shellcheck disable=SC2206
  local dirs=( $(ls -1dt ${pattern} 2>/dev/null || true) )
  (( ${#dirs[@]} <= keep )) && return 0
  local to_delete=( "${dirs[@]:keep}" )
  for d in "${to_delete[@]}"; do
    [[ -d "$d" ]] || continue
    yellow "清理旧备份目录：$d"
    rm -rf -- "$d" 2>/dev/null || true
  done
}
yellow() { echo -e "\033[33m$*\033[0m"; }
red() { echo -e "\033[31m$*\033[0m"; }

require_root() {
  if [[ "$EUID" -ne 0 ]]; then
    red "请使用 root 权限运行：sudo bash $0"; exit 1;
  fi
}

ask_api()
{
  echo
  yellow "请输入你的 Telegram API 凭据（可在 https://my.telegram.org 获取）："
  while true; do
    read -rp "api_id（仅数字）：" API_ID
    [[ -n "${API_ID}" && "${API_ID}" =~ ^[0-9]+$ ]] && break || yellow "api_id 必须为非空数字"
  done
  while true; do
    read -rp "api_hash（来自 my.telegram.org）：" API_HASH
    [[ -n "${API_HASH}" ]] && break || yellow "api_hash 不能为空"
  done
}

install_deps()
{
  yellow "正在更新 apt 并安装依赖..."
  apt update -y
  apt install -y git curl wget ca-certificates python3 python3-pip python3-venv \
                 build-essential libssl-dev zlib1g-dev libncurses5-dev libffi-dev \
                 libreadline-dev libsqlite3-dev libbz2-dev liblzma-dev tk-dev \
                 imagemagick libwebp-dev neofetch libzbar-dev libxml2-dev libxslt-dev \
                 sqlite3 \
                 tesseract-ocr tesseract-ocr-all
}

version_ge() { [ "$(printf '%s\n' "$2" "$1" | sort -V | head -n1)" = "$2" ]; }

ensure_python()
{
  yellow "正在检查 Python..."
  local want="${PY_VER_DEFAULT}"
  local have=""
  if command -v python3 >/dev/null 2>&1; then
    have=$(python3 -c 'import sys;print("%d.%d.%d"%sys.version_info[:3])') || true
  fi
  if [[ -n "$have" ]] && version_ge "$have" "3.13.0"; then
    PY_BIN="python3"
    green "使用系统自带的 python3（${have}）"
  else
    yellow "系统 python3 缺失或版本过旧（${have:-none}）。将从源码构建 Python ${want}..."
    local tgz="Python-${want}.tgz"
    local url="https://www.python.org/ftp/python/${want}/Python-${want}.tgz"
    cd /usr/src || cd /tmp
    rm -rf "Python-${want}" "$tgz" 2>/dev/null || true
    if ! curl -fsSLo "$tgz" "$url"; then
      red "下载失败：$url"; exit 1;
    fi
    tar -xzf "$tgz"
    cd "Python-${want}"
    ./configure --enable-optimizations --with-ensurepip=install
    make -j"$(nproc)"
    make altinstall
    PY_BIN="python3.${want#3.}"
    if ! command -v "$PY_BIN" >/dev/null 2>&1; then
      # Fallback to the exact minor path
      PY_BIN="/usr/local/bin/python${want%.*}"
    fi
    green "构建完成并选择 ${PY_BIN}"
  fi
  # Upgrade pip and essentials
  "$PY_BIN" -m pip install --upgrade pip || true
  "$PY_BIN" -m pip install -U coloredlogs || true
}

create_venv()
{
  yellow "正在创建 Python 虚拟环境..."
  # Ensure app dir exists before venv
  mkdir -p "${APP_DIR}"
  if [[ ! -d "${VENV_DIR}" ]]; then
    "$PY_BIN" -m venv "${VENV_DIR}"
  fi
  if [[ -x "${VENV_DIR}/bin/python" ]]; then
    PY_BIN="${VENV_DIR}/bin/python"
  elif [[ -x "${VENV_DIR}/Scripts/python" ]]; then
    PY_BIN="${VENV_DIR}/Scripts/python"
  fi
  "$PY_BIN" -m pip install --upgrade pip setuptools wheel || true
}

clone_or_update_repo()
{
  if [[ -d "${APP_DIR}/.git" ]]; then
    yellow "检测到已存在的 PagerMaid-Modify 目录。"

    # If service is running, stop it first
    if systemctl is-active --quiet PagerMaid-Modify; then
      yellow "检测到 systemd 服务正在运行，正在尝试停止..."
      systemctl stop PagerMaid-Modify || true
    fi

    # Backup critical files
    TS=$(date +%Y%m%d_%H%M%S)
    BK_DIR="/root/PMM_backup_${TS}"
    yellow "将当前目录备份到：${BK_DIR}"
    mkdir -p "${BK_DIR}"
    # Backup config/session/plugins/data if present
    cp -af "${APP_DIR}/config.yml" "${BK_DIR}/" 2>/dev/null || true
    cp -af "${APP_DIR}"/*.session "${BK_DIR}/" 2>/dev/null || true
    cp -af "${APP_DIR}/plugins" "${BK_DIR}/" 2>/dev/null || true
    cp -af "${APP_DIR}/data" "${BK_DIR}/" 2>/dev/null || true

    # 清理旧备份，仅保留最新一个
    prune_old_backups 1 "/root/PMM_backup_*"

    # 询问是否重置数据库文件（当数据库损坏/无法登录时有用）
    echo
    yellow "发现现有数据文件。是否重置数据库以避免潜在错误？"
    echo "说明：仅在启动报错（如数据库损坏/版本不兼容）时才建议重置。"
    echo "将会删除常见数据库文件 (*.db, *.sqlite, *.sqlite3)，并已备份到：${BK_DIR}"
    echo "默认：N（不重置，保留现有数据）。输入 y 才会执行重置。"
    read -rp "是否重置数据库文件？[y/N]: " resetdb
    resetdb=${resetdb:-N}

    yellow "正在更新仓库代码..."
    git -C "${APP_DIR}" reset --hard HEAD || true
    git -C "${APP_DIR}" pull --ff-only || git -C "${APP_DIR}" pull || true

    # 可选的数据库清理
    if [[ "${resetdb}" =~ ^[Yy]$ ]]; then
      yellow "正在清理常见数据库文件...（已备份到 ${BK_DIR}）"
      find "${APP_DIR}" -maxdepth 2 -type f \( -name "*.db" -o -name "*.sqlite" -o -name "*.sqlite3" \) -print -delete 2>/dev/null || true
      # Extra common paths
      rm -f "${APP_DIR}/pagermaid.db" 2>/dev/null || true
      rm -f "${APP_DIR}/data/pagermaid.db" 2>/dev/null || true
      rm -f "${APP_DIR}/pagermaid.sqlite" 2>/dev/null || true
      rm -f "${APP_DIR}/data/pagermaid.sqlite" 2>/dev/null || true
    fi

    # 询问是否保留 .session 会话文件（推荐，避免重新登录）
    read -rp "是否保留现有 .session 会话文件（推荐）？[Y/n]: " keepss
    keepss=${keepss:-Y}
    if [[ ! "${keepss}" =~ ^[Yy]$ ]]; then
      yellow "将删除会话文件（已备份到 ${BK_DIR}）。删除后需要重新登录。"
      rm -f "${APP_DIR}"/*.session 2>/dev/null || true
    fi

  else
    # If APP_DIR exists but is not a git repo, move it aside (keep .venv if present)
    if [[ -d "${APP_DIR}" && ! -d "${APP_DIR}/.git" ]]; then
      TS=$(date +%Y%m%d_%H%M%S)
      local OLD_DIR="${APP_DIR}_nongit_${TS}"
      yellow "检测到目录存在但不是 Git 仓库，将其移动到 ${OLD_DIR} 并重新克隆..."
      mv "${APP_DIR}" "${OLD_DIR}"
    fi
    yellow "正在克隆仓库..."
    mkdir -p "${APP_DIR%/*}"
    git clone "${REPO_URL}" "${APP_DIR}"
    # If we moved an old dir that had a venv, move it back
    if [[ -n "${OLD_DIR:-}" && -d "${OLD_DIR}/.venv" && ! -d "${APP_DIR}/.venv" ]]; then
      yellow "检测到旧环境，正在将现有虚拟环境迁移至新的克隆目录..."
      mv "${OLD_DIR}/.venv" "${APP_DIR}/.venv" || true
    fi
  fi
}

install_requirements()
{
  yellow "正在安装项目依赖..."
  cd "${APP_DIR}"
  if [[ ! -f requirements.txt ]]; then
    red "未找到 requirements.txt，仓库可能不完整。"; exit 1;
  fi
  "$PY_BIN" -m pip install -r requirements.txt --root-user-action=ignore || \
  "$PY_BIN" -m pip install -r requirements.txt
}

prepare_config()
{
  cd "${APP_DIR}"
  if [[ ! -f config.yml ]]; then
    if [[ -f config.gen.yml ]]; then
      cp config.gen.yml config.yml
    else
      red "未找到 config.gen.yml，无法生成 config.yml。"; exit 1;
    fi
  fi

  # Write api_id / api_hash
  sed -i -E "s/^(\s*api_id:\s*).*/\1${API_ID}/" config.yml
  sed -i -E "s/^(\s*api_hash:\s*).*/\1\"${API_HASH}\"/" config.yml

  green "已写入 api_id 与 api_hash -> ${APP_DIR}/config.yml"
}


install_pm2()
{
  yellow "正在安装 pm2..."
  if ! command -v node >/dev/null 2>&1; then
    yellow "正在安装 Node.js（NodeSource 20.x）..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y nodejs || true
  fi
  if ! command -v npm >/dev/null 2>&1; then
    red "安装 Node.js 后未发现 npm，请检查系统发行版环境。"; return 1;
  fi
  if ! command -v pm2 >/dev/null 2>&1; then
    npm i -g pm2 || { red "通过 npm 安装 pm2 失败"; return 1; }
  fi
}

create_pm2_process()
{
  yellow "正在创建 pm2 进程..."
  local py_path
  py_path="$(command -v "$PY_BIN" || echo /usr/bin/python3)"
  cd "${APP_DIR}"
  # Remove existing process with the same name to prevent duplicates
  pm2 delete PagerMaid-Modify >/dev/null 2>&1 || true
  # Start python interpreter with module argument passed after --
  pm2 start "${py_path}" --name PagerMaid-Modify --time --cwd "${APP_DIR}" -- -m pagermaid
  pm2 save
  # Optional: auto-start on boot
  pm2 startup systemd -u root --hp /root >/dev/null 2>&1 || true
}

has_session()
{
  shopt -s nullglob
  local sessions=("${APP_DIR}"/*.session)
  if (( ${#sessions[@]} > 0 )); then
    return 0
  else
    return 1
  fi
}

stop_daemons()
{
  # stop systemd service if active
  if systemctl is-active --quiet PagerMaid-Modify; then
    yellow "正在停止已运行的 systemd 服务..."
    systemctl stop PagerMaid-Modify || true
  fi
  # stop pm2 process if exists
  if command -v pm2 >/dev/null 2>&1; then
    pm2 delete PagerMaid-Modify >/dev/null 2>&1 || true
  fi
}

backup_and_remove_files()
{
  local pattern
  pattern="${1:-}"
  # If no pattern provided, do nothing (be safe under set -u)
  [[ -z "$pattern" ]] && return 0
  shopt -s nullglob
  local files=( $pattern )
  (( ${#files[@]} == 0 )) && return 0
  local TS BK_DIR
  TS=$(date +%Y%m%d_%H%M%S)
  BK_DIR="/root/PMM_session_bak_${TS}"
  yellow "检测到可能损坏的会话/数据库文件，正在备份到：${BK_DIR}"
  mkdir -p "${BK_DIR}"
  for f in "${files[@]}"; do
    cp -af "$f" "${BK_DIR}/" 2>/dev/null || true
    rm -f "$f" 2>/dev/null || true
  done
}

check_and_clean_corruption()
{
  # Require sqlite3 to check integrity; if missing, skip silently.
  if ! command -v sqlite3 >/dev/null 2>&1; then
    return 0
  fi
  local f out rc bad=false
  shopt -s nullglob
  # Telethon sessions (*.session) are SQLite files
  for f in "${APP_DIR}"/pagermaid.session "${APP_DIR}"/*.session; do
    [[ -e "$f" ]] || continue
    out=$(sqlite3 "$f" 'PRAGMA integrity_check;' 2>&1) || rc=$?
    # treat any non-'ok' output or sqlite error as corruption
    if [[ "$out" != "ok" ]]; then
      bad=true
    fi
  done
  # Project data DBs (sqlite/db)
  for f in "${APP_DIR}/data"/*.sqlite "${APP_DIR}/data"/*.db; do
    [[ -e "$f" ]] || continue
    out=$(sqlite3 "$f" 'PRAGMA integrity_check;' 2>&1) || rc=$?
    if [[ "$out" != "ok" ]]; then
      bad=true
    fi
  done
  if [[ "$bad" == true ]]; then
    yellow "检测到损坏的会话/数据库文件，将自动备份并清理。"
    backup_and_remove_files "${APP_DIR}/pagermaid.session*"
    backup_and_remove_files "${APP_DIR}/"*.session*
    backup_and_remove_files "${APP_DIR}/data/"*.session*
    backup_and_remove_files "${APP_DIR}/data/"*.sqlite*
    backup_and_remove_files "${APP_DIR}/data/"*.db*
  fi
}

first_login_if_needed()
{
  check_and_clean_corruption
  if has_session; then
    yellow "检测到已存在的 .session，会话文件。跳过首次登录步骤。"
    return 0
  fi
  stop_daemons
  echo
  yellow "未检测到 .session 会话文件。将前台运行 PagerMaid-Modify 以创建会话。"
  cd "${APP_DIR}"
  # Run once in foreground and capture output to detect malformed DB
  set +e
  local out_file
  out_file=$(mktemp)
  # 后台启动并实时写入日志文件，便于模式匹配
  "$PY_BIN" -m pagermaid 2>&1 | tee "$out_file" &
  local run_pid=$!
  local ec=0 detected_start=false
  # 使用可配置的启动成功匹配与等待时间（可通过环境变量覆盖）
  local start_regex="${START_REGEX}"
  local start_timeout="${START_TIMEOUT}"
  # 最长等待指定秒数检测启动日志
  for i in $(seq 1 "$start_timeout"); do
    if grep -E -m1 -q "$start_regex" "$out_file"; then
      detected_start=true
      yellow "检测到启动成功日志，发送 Ctrl+C 以结束前台运行并继续安装..."
      # 向整个进程组发送 SIGINT（管道包含 python 与 tee），避免 tee 挂住
      kill -INT -"$run_pid" 2>/dev/null || true
      # 等待优雅退出，若未退出则升级为 TERM，再 KILL
      for j in $(seq 1 10); do
        if ! kill -0 "$run_pid" 2>/dev/null; then
          break
        fi
        sleep 0.5
      done
      if kill -0 "$run_pid" 2>/dev/null; then
        yellow "进程未按预期退出，发送 SIGTERM..."
        kill -TERM -"$run_pid" 2>/dev/null || true
      fi
      for j in $(seq 1 10); do
        if ! kill -0 "$run_pid" 2>/dev/null; then
          break
        fi
        sleep 0.5
      done
      if kill -0 "$run_pid" 2>/dev/null; then
        yellow "进程仍未退出，发送 SIGKILL..."
        kill -KILL -"$run_pid" 2>/dev/null || true
      fi
      break
    fi
    # 若进程已退出则跳出
    if ! kill -0 "$run_pid" 2>/dev/null; then
      break
    fi
    sleep 1
  done
  # 等待进程退出
  wait "$run_pid" 2>/dev/null; ec=$?
  set -e
  if grep -q "database disk image is malformed" "$out_file"; then
    yellow "启动过程中检测到数据库损坏，将自动清理并重试一次..."
    backup_and_remove_files "${APP_DIR}/pagermaid.session*"
    backup_and_remove_files "${APP_DIR}/"*.session*
    backup_and_remove_files "${APP_DIR}/data/"*.session*
    # retry once
    "$PY_BIN" -m pagermaid || true
  fi
  # 若已检测到正常启动，则自动选择 pm2 保活
  if [[ "$detected_start" == true ]]; then
    AUTO_CHOOSE_PM2=1
  fi
  rm -f "$out_file" 2>/dev/null || true
}

main()
{
  require_root
  ask_api
  install_deps
  ensure_python
  # Clone/update repo BEFORE creating venv to avoid creating APP_DIR prior to git clone
  clone_or_update_repo
  create_venv
  install_requirements
  prepare_config
  first_login_if_needed

  # 仅使用 pm2 作为保活方式
  echo
  yellow "将使用 pm2 进行保活与管理..."
  install_pm2
  create_pm2_process
  green "安装完成。已由 pm2 管理：pm2 status"
}

main "$@"
