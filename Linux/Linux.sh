#!/bin/bash

function rename_nproc_conf() {
  [ -e /etc/security/limits.d/*nproc.conf ] && rename nproc.conf nproc.conf_bk /etc/security/limits.d/*nproc.conf
}

function update_common_session() {
  if [ -f /etc/pam.d/common-session ] && [ -z "$(grep 'session required pam_limits.so' /etc/pam.d/common-session)" ]; then
    echo "session required pam_limits.so" >> /etc/pam.d/common-session
  fi
}

function update_limits_conf() {
  sed -i '/^# End of file/,$d' /etc/security/limits.conf
  cat >> /etc/security/limits.conf <<EOF
# End of file
*     soft   nofile    1048576
*     hard   nofile    1048576
*     soft   nproc     1048576
*     hard   nproc     1048576
*     soft   core      1048576
*     hard   core      1048576
*     hard   memlock   unlimited
*     soft   memlock   unlimited
root     soft   nofile    1048576
root     hard   nofile    1048576
root     soft   nproc     1048576
root     hard   nproc     1048576
root     soft   core      1048576
root     hard   core      1048576
root     hard   memlock   unlimited
root     soft   memlock   unlimited
EOF
}

function remove_unneeded_parameters() {
  sed -i '/fs.file-max/d; /fs.inotify.max_user_instances/d; /net.core.somaxconn/d; /net.core.netdev_max_backlog/d; /net.core.rmem_max/d; /net.core.wmem_max/d; /net.ipv4.udp_rmem_min/d; /net.ipv4.udp_wmem_min/d; /net.ipv4.tcp_rmem/d; /net.ipv4.tcp_wmem/d; /net.ipv4.tcp_mem/d; /net.ipv4.udp_mem/d; /net.ipv4.tcp_syncookies/d; /net.ipv4.tcp_fin_timeout/d; /net.ipv4.tcp_tw_reuse/d; /net.ipv4.ip_local_port_range/d; /net.ipv4.tcp_max_syn_backlog/d; /net.ipv4.tcp_max_tw_buckets/d; /net.ipv4.route.gc_timeout/d; /net.ipv4.tcp_syn_retries/d; /net.ipv4.tcp_synack_retries/d; /net.ipv4.tcp_timestamps/d; /net.ipv4.tcp_max_orphans/d; /net.ipv4.tcp_no_metrics_save/d; /net.ipv4.tcp_ecn/d; /net.ipv4.tcp_frto/d; /net.ipv4.tcp_mtu_probing/d; /net.ipv4.tcp_rfc1337/d; /net.ipv4.tcp_sack/d; /net.ipv4.tcp_fack/d; /net.ipv4.tcp_window_scaling/d; /net.ipv4.tcp_adv_win_scale/d; /net.ipv4.tcp_moderate_rcvbuf/d; /net.ipv4.tcp_keepalive_time/d; /net.ipv4.tcp_notsent_lowat/d; /net.ipv4.conf.all.route_localnet/d; /net.ipv4.ip_forward/d; /net.ipv4.conf.all.forwarding/d; /net.ipv4.conf.default.forwarding/d; /net.core.default_qdisc/d; /net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
}

function add_new_parameters() {
  cat >> /etc/sysctl.conf << EOF
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

#SSR 对于会出现突发空闲的长周期 TLS 连接有很大影响，所以关闭
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
