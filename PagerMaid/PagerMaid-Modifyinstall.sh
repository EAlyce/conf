#!/usr/bin/env bash
# One-click installer for PagerMaid-Modify (Debian/Ubuntu)
# Features:
# 1) Install dependencies and clone/update repo
# 2) Interactive input for api_id and api_hash
# 3) Write values into config.yml
# 4) Optional systemd service creation and start
set -euo pipefail

APP_DIR="/root/PagerMaid-Modify"
SERVICE_FILE="/etc/systemd/system/PagerMaid-Modify.service"
REPO_URL="https://github.com/TeamPGM/PagerMaid-Modify.git"
PY_VER_DEFAULT="3.13.1"  # default Python to build if system one is too old
PY_BIN="python3"         # will be set to the detected/built python
VENV_DIR="/root/PagerMaid-Modify/.venv"

green() { echo -e "\033[32m$*\033[0m"; }
yellow() { echo -e "\033[33m$*\033[0m"; }
red() { echo -e "\033[31m$*\033[0m"; }

require_root() {
  if [[ "$EUID" -ne 0 ]]; then
    red "Please run as root: sudo bash $0"; exit 1;
  fi
}

ask_api()
{
  echo
  yellow "Enter your Telegram API credentials (get them at https://my.telegram.org):"
  while true; do
    read -rp "api_id (digits only): " API_ID
    [[ -n "${API_ID}" && "${API_ID}" =~ ^[0-9]+$ ]] && break || yellow "api_id must be numeric and not empty"
  done
  while true; do
    read -rp "api_hash (string from my.telegram.org): " API_HASH
    [[ -n "${API_HASH}" ]] && break || yellow "api_hash must not be empty"
  done
}

install_deps()
{
  yellow "Updating apt and installing dependencies..."
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
  yellow "Checking Python..."
  local want="${PY_VER_DEFAULT}"
  local have=""
  if command -v python3 >/dev/null 2>&1; then
    have=$(python3 -c 'import sys;print("%d.%d.%d"%sys.version_info[:3])') || true
  fi
  if [[ -n "$have" ]] && version_ge "$have" "3.13.0"; then
    PY_BIN="python3"
    green "Using system python3 (${have})"
  else
    yellow "System python3 is missing or too old (${have:-none}). Building Python ${want} from source..."
    local tgz="Python-${want}.tgz"
    local url="https://www.python.org/ftp/python/${want}/Python-${want}.tgz"
    cd /usr/src || cd /tmp
    rm -rf "Python-${want}" "$tgz" 2>/dev/null || true
    if ! curl -fsSLo "$tgz" "$url"; then
      red "Failed to download $url"; exit 1;
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
    green "Built and selected ${PY_BIN}"
  fi
  # Upgrade pip and essentials
  "$PY_BIN" -m pip install --upgrade pip || true
  "$PY_BIN" -m pip install -U coloredlogs || true
}

create_venv()
{
  yellow "Creating Python virtual environment..."
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
    yellow "Detected existing PagerMaid-Modify directory."

    # If service is running, stop it first
    if systemctl is-active --quiet PagerMaid-Modify; then
      yellow "Detected running systemd service, trying to stop it..."
      systemctl stop PagerMaid-Modify || true
    fi

    # Backup critical files
    TS=$(date +%Y%m%d_%H%M%S)
    BK_DIR="/root/PMM_backup_${TS}"
    yellow "Backup current directory to: ${BK_DIR}"
    mkdir -p "${BK_DIR}"
    # Backup config/session/plugins/data if present
    cp -af "${APP_DIR}/config.yml" "${BK_DIR}/" 2>/dev/null || true
    cp -af "${APP_DIR}"/*.session "${BK_DIR}/" 2>/dev/null || true
    cp -af "${APP_DIR}/plugins" "${BK_DIR}/" 2>/dev/null || true
    cp -af "${APP_DIR}/data" "${BK_DIR}/" 2>/dev/null || true

    # Ask whether to reset database files (useful if DB is corrupted / login fails)
    echo
    read -rp "Detected existing data. Reset database files to avoid errors? [y/N]: " resetdb
    resetdb=${resetdb:-N}

    yellow "Updating repository code..."
    git -C "${APP_DIR}" reset --hard HEAD || true
    git -C "${APP_DIR}" pull --ff-only || git -C "${APP_DIR}" pull || true

    # Optional DB cleanup
    if [[ "${resetdb}" =~ ^[Yy]$ ]]; then
      yellow "Cleaning common database files... (backup at ${BK_DIR})"
      find "${APP_DIR}" -maxdepth 2 -type f \( -name "*.db" -o -name "*.sqlite" -o -name "*.sqlite3" \) -print -delete 2>/dev/null || true
      # Extra common paths
      rm -f "${APP_DIR}/pagermaid.db" 2>/dev/null || true
      rm -f "${APP_DIR}/data/pagermaid.db" 2>/dev/null || true
      rm -f "${APP_DIR}/pagermaid.sqlite" 2>/dev/null || true
      rm -f "${APP_DIR}/data/pagermaid.sqlite" 2>/dev/null || true
    fi

    # Ask whether to keep session files (recommended to avoid re-login)
    read -rp "Keep existing .session files (recommended)? [Y/n]: " keepss
    keepss=${keepss:-Y}
    if [[ ! "${keepss}" =~ ^[Yy]$ ]]; then
      yellow "Deleting session files (backup at ${BK_DIR})"
      rm -f "${APP_DIR}"/*.session 2>/dev/null || true
    fi

  else
    # If APP_DIR exists but is not a git repo, move it aside (keep .venv if present)
    if [[ -d "${APP_DIR}" && ! -d "${APP_DIR}/.git" ]]; then
      TS=$(date +%Y%m%d_%H%M%S)
      local OLD_DIR="${APP_DIR}_nongit_${TS}"
      yellow "Directory exists but is not a git repo. Moving it to ${OLD_DIR} and recloning..."
      mv "${APP_DIR}" "${OLD_DIR}"
    fi
    yellow "Cloning repository..."
    mkdir -p "${APP_DIR%/*}"
    git clone "${REPO_URL}" "${APP_DIR}"
    # If we moved an old dir that had a venv, move it back
    if [[ -n "${OLD_DIR:-}" && -d "${OLD_DIR}/.venv" && ! -d "${APP_DIR}/.venv" ]]; then
      yellow "Restoring existing virtual environment to new clone..."
      mv "${OLD_DIR}/.venv" "${APP_DIR}/.venv" || true
    fi
  fi
}

install_requirements()
{
  yellow "Installing project dependencies..."
  cd "${APP_DIR}"
  if [[ ! -f requirements.txt ]]; then
    red "requirements.txt not found. Repository may be incomplete."; exit 1;
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
      red "config.gen.yml not found, cannot create config.yml."; exit 1;
    fi
  fi

  # Write api_id / api_hash
  sed -i -E "s/^(\s*api_id:\s*).*/\1${API_ID}/" config.yml
  sed -i -E "s/^(\s*api_hash:\s*).*/\1\"${API_HASH}\"/" config.yml

  green "Wrote api_id and api_hash -> ${APP_DIR}/config.yml"
}

create_service()
{
  yellow "Creating systemd service..."
  local py_path
  py_path="$(command -v "$PY_BIN" || echo /usr/bin/python3)"
  tee "${SERVICE_FILE}" >/dev/null <<EOF
[Unit]
Description=PagerMaid-Modify telegram utility daemon
After=network.target

[Service]
WorkingDirectory=/root/PagerMaid-Modify
ExecStart=${py_path} -m pagermaid
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable PagerMaid-Modify
  systemctl restart PagerMaid-Modify
  systemctl status --no-pager --full PagerMaid-Modify || true
}

install_pm2()
{
  yellow "Installing pm2..."
  if ! command -v node >/dev/null 2>&1; then
    yellow "Installing Node.js (NodeSource 20.x)..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y nodejs || true
  fi
  if ! command -v npm >/dev/null 2>&1; then
    red "npm not found after Node.js installation. Please check your OS/distro."; return 1;
  fi
  if ! command -v pm2 >/dev/null 2>&1; then
    npm i -g pm2 || { red "Failed to install pm2 via npm"; return 1; }
  fi
}

create_pm2_process()
{
  yellow "Creating pm2 process..."
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
    yellow "Stopping running systemd service..."
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
  yellow "Backing up corrupted session/DB files to: ${BK_DIR}"
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
    yellow "Detected corrupted session/DB files. Auto-backup and clean."
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
    yellow "Existing .session found. Skip first-time login."
    return 0
  fi
  stop_daemons
  echo
  yellow "No existing .session found. Run PagerMaid-Modify to create one."
  cd "${APP_DIR}"
  # Run once in foreground and capture output to detect malformed DB
  set +e
  local out_file
  out_file=$(mktemp)
  "$PY_BIN" -m pagermaid 2>&1 | tee "$out_file"
  local ec=$?
  set -e
  if grep -q "database disk image is malformed" "$out_file"; then
    yellow "Detected malformed session DB during startup. Auto-clean and retry once..."
    backup_and_remove_files "${APP_DIR}/pagermaid.session*"
    backup_and_remove_files "${APP_DIR}/"*.session*
    backup_and_remove_files "${APP_DIR}/data/"*.session*
    # retry once
    "$PY_BIN" -m pagermaid || true
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

  echo
  echo "Choose run mode:"
  echo "  [1] systemd (default)"
  echo "  [2] pm2"
  echo "  [3] none (run manually)"
  read -rp "Your choice [1/2/3]: " mode
  mode=${mode:-1}
  case "$mode" in
    2)
      install_pm2
      create_pm2_process
      green "Installation complete. Managed by pm2: pm2 status"
      ;;
    3)
      yellow "Skipped creating a service. You can run manually:"
      echo "  cd ${APP_DIR} && ${PY_BIN} -m pagermaid"
      ;;
    *)
      create_service
      green "Installation complete. Service started: systemctl status PagerMaid-Modify"
      ;;
  esac
}

main "$@"
