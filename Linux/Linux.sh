#!/bin/bash

function rename_nproc_conf() {
  [ -e /etc/security/limits.d/*nproc.conf ] && rename nproc.conf nproc.conf_bk /etc/security/limits.d/*nproc.conf
}

function update_common_session() {
  local common_session="/etc/pam.d/common-session"
  if [ -f "$common_session" ] && ! grep -q 'session required pam_limits.so' "$common_session"; then
    echo "session required pam_limits.so" >> "$common_session"
  fi
}

function update_limits_conf() {
  cat <<EOF > /etc/security/limits.conf
# End of file
*     soft   nofile    1048576
*     hard   nofile    1048576
*     soft   nproc     1048576
*     hard   nproc     1048576
*     soft   core      1048576
*     hard   core      1048576
*     hard   memlock   unlimited
*     soft   memlock   unlimited
root  soft   nofile    1048576
root  hard   nofile    1048576
root  soft   nproc     1048576
root  hard   nproc     1048576
root  soft   core      1048576
root  hard   core      1048576
root  hard   memlock   unlimited
root  soft   memlock   unlimited
EOF
}

function remove_unneeded_parameters() {
  local unneeded_parameters=(
    fs.file-max
    fs.inotify.max_user_instances
    net.core.somaxconn
    net.core.netdev_max_backlog
    net.core.rmem_max
    net.core.wmem_max
    net.ipv4.udp_rmem_min
    net.ipv4.udp_wmem_min
    net.ipv4.tcp_rmem
    net.ipv4.tcp_wmem
    net.ipv4.tcp_mem
    net.ipv4.udp_mem
    net.ipv4.tcp_syncookies
    net.ipv4.tcp_fin_timeout
    net.ipv4.tcp_tw_reuse
    net.ipv4.ip_local_port_range
    net.ipv4.tcp_max_syn_backlog
    net.ipv4.tcp_max_tw_buckets
    net.ipv4.route.gc_timeout
    net.ipv4.tcp_syn_retries
    net.ipv4.tcp_synack_retries
    net.ipv4.tcp_timestamps
    net.ipv4.tcp_max_orphans
    net.ipv4.tcp_no_metrics_save
    net.ipv4.tcp_ecn
    net.ipv4.tcp_frto
    net.ipv4.tcp_mtu_probing
    net.ipv4.tcp_rfc1337
    net.ipv4.tcp_sack
    net.ipv4.tcp_fack
    net.ipv4.tcp_window_scaling
    net.ipv4.tcp_adv_win_scale
    net.ipv4.tcp_moderate_rcvbuf
    net.ipv4.tcp_keepalive_time
    net.ipv4.tcp_notsent_lowat
    net.ipv4.conf.all.route_localnet
    net.ipv4.ip_forward
    net.ipv4.conf.all.forwarding
    net.ipv4.conf.default.forwarding
    net.core.default_qdisc
    net.ipv4.tcp_congestion_control
  )
  sed -i '/^\('$(IFS='|'; echo "${unneeded_parameters[*]}")'\)\s*=/d' /etc/sysctl.conf
}

function add_new_parameters() {
  cat <<EOF >> /etc/sysctl.conf
fs.file-max = 1048576
fs.inotify.max_user_instances = 8192
net.core.somaxconn = 32768
net.core.netdev_max_backlog = 32768
net.core.rmem_max = 33554432
net.core.wmem_max = 33554432
net.ipv4.udp_rmem_min = 16384
net.ipv4.udp_wmem_min = 16384
net.ipv4.tcp_rmem = 4096 87380 33554432
net.ipv4.tcp_wmem = 4096 16384 33554432
net.ipv4.tcp_mem = 786432 1048576 26777216
net.ipv4.udp_mem = 65536 131072 262144
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_tw_reuse = 1
net.ipv4.ip_local_port_range = 1024 65000
net.ipv4.tcp_max_syn_backlog = 16384
net.ipv4.tcp_max_tw_buckets = 6000
net.ipv4.route.gc_timeout = 100
net.ipv4.tcp_syn_retries = 1
net.ipv4.tcp_synack_retries = 1
net.ipv4.tcp_timestamps = 0
net.ipv4.tcp_max_orphans = 131072
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_ecn = 1
net.ipv4.tcp_frto = 0
net.ipv4.tcp_mtu_probing = 0
net.ipv4.tcp_rfc1337 = 0
net.ipv4.tcp_sack = 1
net.ipv4.tcp_fack = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_adv_win_scale = 1
net.ipv4.tcp_moderate_rcvbuf = 1
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_notsent_lowat = 16384
net.ipv4.conf.all.route_localnet = 1
net.ipv4.ip_forward = 0
net.ipv4.conf.all.forwarding = 0
net.ipv4.conf.default.forwarding = 0
net.core.default_qdisc = fq_codel
net.ipv4.tcp_congestion_control = bbr

# SSR 对于会出现突发空闲的长周期 TLS 连接有很大影响，所以关闭
net.ipv4.tcp_slow_start_after_idle = 0

#设置为1，当检测到 ICMP 黑洞时启用
net.ipv4.tcp_mtu_probing = 1

#Socket缓存配置
net.ipv4.tcp_rmem = 8192 262144 536870912
net.ipv4.tcp_wmem = 4096 16384 536870912

#TCP窗口大小，接收缓冲区可用buffer
net.ipv4.tcp_adv_win_scale = -2

#限制写入队列中未发送字节的大小
net.ipv4.tcp_notsent_lowat = 131072

#关闭IPv6
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF
}

function reload_sysctl_settings() {
  /sbin/sysctl -p
}

# 调用函数
rename_nproc_conf
update_common_session
update_limits_conf
remove_unneeded_parameters
add_new_parameters
reload_sysctl_settings