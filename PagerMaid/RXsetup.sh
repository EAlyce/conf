cd /var/lib
sudo find /var/lib/ -type f -name "Pagermaid.sh*" -exec rm -f {} \;
curl -O https://raw.githubusercontent.com/EAlyce/conf/main/PagerMaid/Pagermaid.sh && chmod +x Pagermaid.sh && ./Pagermaid.sh