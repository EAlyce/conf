# Surge 最精简配置
来源 https://community.nssurge.com/d/1214

[General]
skip-proxy = 192.168.0.0/24, 10.0.0.0/8, 172.16.0.0/12, 127.0.0.1, localhost, *.local

exclude-simple-hostnames = true
internet-test-url = http://taobao.com/

proxy-test-url = http://www.apple.com/

test-timeout = 2

dns-server = 223.5.5.5, 114.114.114.114

wifi-assist = true

ipv6 = false 

[Rule]
RULE-SET,https://github.com/Blankwonder/surge-list/raw/master/blocked.list,Proxy

RULE-SET,https://github.com/Blankwonder/surge-list/raw/master/cn.list,DIRECT

DOMAIN-SUFFIX,cn,DIRECT

DOMAIN,apps.apple.com,Proxy

DOMAIN-SUFFIX,ls.apple.com,DIRECT // Apple Maps

DOMAIN-SUFFIX,store.apple.com,DIRECT // Apple Store Online

RULE-SET,SYSTEM,Proxy

RULE-SET,https://github.com/Blankwonder/surge-list/raw/master/apple.list,Proxy

RULE-SET,LAN,DIRECT

GEOIP,CN,DIRECT

FINAL,Proxy,dns-failed
















