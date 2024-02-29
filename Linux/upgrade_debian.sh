#!/bin/bash
RELEASE=$(cat /etc/issue)

__do_apt_update(){
    apt update || exit 1
}

__do_apt_upgrade(){
    __do_apt_update
    apt upgrade
    apt dist-upgrade
    apt full-upgrade || exit 1
}

__sed_replace(){
    local FROM="$1"
    local TO="$2"
    sed -i "s/$FROM/$TO/g" /etc/apt/sources.list
    sed -i "s/$FROM/$TO/g" /etc/apt/sources.list.d/*.list
}

__do_upgrade(){
    local FROM="$1"
    local TO="$2"
    local SEC="$3"
    echo "[INFO] Doing debian upgrade from $FROM to $TO..."
    __do_apt_upgrade
    __sed_replace "$FROM" "$TO"
    [ -n "$SEC" ] && __sed_replace "$FROM-updates" "$SEC"
    __do_apt_upgrade
    echo "[INFO] Please reboot"
}

case $RELEASE in
    *' 9 '*) __do_upgrade "stretch" "buster" ;;
    *' 10 '*) __do_upgrade "buster" "bullseye" "bullseye-security" ;;
    *' 11 '*) __do_upgrade "bullseye" "bookworm" "bullseye-bookworm" ;;
    *) echo "[ERROR] Unsupported version"; exit 1 ;;
esac