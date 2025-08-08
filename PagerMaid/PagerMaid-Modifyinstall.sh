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
                 sqlite3 libjpeg-dev libtiff5-dev libopenjp2-7 libharfbuzz-dev libfribidi-dev \
                 lsb-release gnupg software-properties-common expect \
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

    # 自动选择：重置数据库（不再询问）
    echo
    yellow "发现现有数据文件。已自动选择：重置数据库（会先备份到：${BK_DIR}）。"
    local resetdb="Y"

    yellow "正在更新仓库代码..."
    git -C "${APP_DIR}" reset --hard HEAD || true
    git -C "${APP_DIR}" pull --ff-only || git -C "${APP_DIR}" pull || true

    # 数据库清理（已自动选择重置）
    if [[ "${resetdb}" =~ ^[Yy]$ ]]; then
      yellow "正在清理常见数据库文件...（已备份到 ${BK_DIR}）"
      find "${APP_DIR}" -maxdepth 2 -type f \( -name "*.db" -o -name "*.sqlite" -o -name "*.sqlite3" \) -print -delete 2>/dev/null || true
      # Extra common paths
      rm -f "${APP_DIR}/pagermaid.db" 2>/dev/null || true
      rm -f "${APP_DIR}/data/pagermaid.db" 2>/dev/null || true
      rm -f "${APP_DIR}/pagermaid.sqlite" 2>/dev/null || true
      rm -f "${APP_DIR}/data/pagermaid.sqlite" 2>/dev/null || true
    fi

    # 自动选择：不保留 .session（不再询问）
    yellow "已自动选择：不保留现有 .session 会话文件（已备份到 ${BK_DIR}）。删除后需要重新登录。"
    rm -f "${APP_DIR}"/*.session 2>/dev/null || true

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
  yellow "未检测到 .session 会话文件。将使用自动交互模式引导你完成登录（手机号/验证码/二次密码）。"
  cd "${APP_DIR}"
  # 采集用户输入（不回显二次密码）
  read -rp "请输入手机号码（含国家区号，如 +86xxxxxxxxxxx）：" USER_PHONE
  while [[ -z "${USER_PHONE}" ]]; do read -rp "手机号码不能为空，请重新输入：" USER_PHONE; done
  # 不再预先询问验证码；仅在真正提示输入验证码时再向你索取
  read -rsp "若账号设置了二次密码，请输入（可留空回车跳过）：" USER_2FA; echo
  # 输出日志文件，供后续匹配校验
  local out_file
  out_file=$(mktemp)
  # 导出环境变量供 expect 使用
  export PY_BIN APP_DIR USER_PHONE USER_2FA
  export OUT_FILE="$out_file"
  local start_regex="${START_REGEX}"
  local start_timeout="${START_TIMEOUT}"
  yellow "正在启动并自动化登录流程...（最长等待 ${start_timeout} 秒）"
  expect <<'EOEXP'
    log_user 1
    set timeout -1
    # 从环境读取变量
    set py_bin $env(PY_BIN)
    set app_dir $env(APP_DIR)
    set phone $env(USER_PHONE)
    set pwd $env(USER_2FA)
    set outfile $env(OUT_FILE)
    spawn -noecho $py_bin -m pagermaid
    # 将输出同步到日志文件
    set fout [open $outfile "w"]
    proc logline {f s} { puts $f $s; flush $f }
    # 安全发送封装
    proc safe_send {s} { catch {send -- $s} }
    # 1) 等待手机号提示并发送
    expect -re {(?i)phone|手机号|电话|number|请输入.*手机}
    logline $fout "PROMPT_PHONE"
    safe_send "$phone\r"
    # 2) 等待验证码提示；若子进程提前退出则友好提示
    expect {
      -re {(?i)code|验证码|输入.*验证码} {
        logline $fout "PROMPT_CODE"
        # 通过 /dev/tty 直接读取用户输入，避免 expect_user 在非交互管道中的问题
        set code ""
        set tty_path "/dev/tty"
        if {[file readable $tty_path]} {
          set tty [open $tty_path "r+"]
          fconfigure $tty -buffering line -blocking 1 -translation auto
          puts $tty ""
          puts -nonewline $tty "请在 Telegram 或短信中查收验证码，输入后回车："
          flush $tty
          while {[string length $code] == 0} {
            if {[catch {gets $tty code}]} { set code "" }
            if {[string length $code] == 0} {
              puts -nonewline $tty "\n验证码不能为空，请重新输入："
              flush $tty
            }
          }
          close $tty
        } else {
          send_user "\n检测到当前环境无交互终端(/dev/tty 不可用)。请先手动完成首次登录：\n  source ${app_dir}/.venv/bin/activate && python -m pagermaid\n完成后再次运行安装脚本。\n"
          close $fout
          exit 1
        }
        safe_send "$code\r"
      }
      eof {
        logline $fout "EOF_BEFORE_CODE"
        send_user "\n登录进程已退出，可能是网络/限制导致。请稍后重试，或手动运行：\n  source ${app_dir}/.venv/bin/activate && python -m pagermaid\n完成首次登录后再重新执行安装脚本。\n"
        close $fout
        exit 1
      }
    }
    # 3) 可能出现二次密码或直接启动
    expect {
      -re {(?i)password|two[- ]?step|二步|两步|密码|输入.*密码} {
        logline $fout "PROMPT_2FA"
        if {[string length $pwd] == 0} {
          send_user "\n请输入二次密码（留空直接回车跳过）："; stty -echo; expect_user -re "(.*)\n"; stty echo; set pwd $expect_out(1,string)
        }
        if {[string length $pwd] > 0} { safe_send "$pwd\r" }
        exp_continue
      }
      -re {已启动|has started|Started PagerMaid} {
        logline $fout "STARTED"; after 500; safe_send \003
      }
      eof {
        # 子进程结束
      }
    }
    close $fout
EOEXP
  # 简单校验：是否在日志中看到 STARTED 记录
  if [[ -f "$out_file" ]] && grep -q "STARTED" "$out_file"; then
    yellow "登录并启动成功，已自动发送 Ctrl+C 结束前台。"
    export AUTO_CHOOSE_PM2=1
  else
    yellow "未确认到启动成功标记，请检查输出或稍后用 pm2 logs 观察。"
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
