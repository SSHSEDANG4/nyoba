#!/bin/bash
# My Telegram : https://t.me/sshsedang
# ==========================================
# Color
RED='\033[0;31m'
NC='\033[0m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
LIGHT='\033[0;37m'
# ==========================================
clear
# Getting
MYIP=$(wget -qO- ipinfo.io/ip);
source /var/lib/ssn/ipvps.conf
if [[ "$IP" = "" ]]; then
domain=$(cat /etc/xray/domain)
else
domain=$IP
fi
uuid=$(cat /proc/sys/kernel/random/uuid)
tr="$(cat /usr/local/etc/xray/config.json | grep port | sed 's/"//g' | sed 's/port//g' | sed 's/://g' | sed 's/,//g' | sed 's/ //g')"
until [[ $user =~ ^[a-zA-Z0-9_]+$ && ${user_EXISTS} == '0' ]]; do
		read -rp "Password : " -e user
		user_EXISTS=$(grep -w $user /usr/local/etc/xray/config.json | wc -l)

		if [[ ${user_EXISTS} == '1' ]]; then
			echo ""
			echo -e "Username ${RED}${user}${NC} Already On VPS Please Choose Another"
			exit 1
		fi
	done
uuid=$(cat /proc/sys/kernel/random/uuid)
read -p "Expired (Days) : " masaaktif
read -p "SNI (bug) : " sni
read -p "Subdomain (EXP : manternet.xyz. / Press Enter If Only Using Hosts) : " sub
dom=$sub$domain
hariini=`date -d "0 days" +"%Y-%m-%d"`
exp=`date -d "$masaaktif days" +"%Y-%m-%d"`
sed -i '/#xray-trojan-grpc$/a\#&# '"$user $exp"'\
},{"password": "'""$uuid""'","email": "'""$user""'"' /usr/local/etc/xray/config.json

trojanlink1="trojan://$uuid@$dom:${tr}?mode=gun&security=tls&type=grpc&serviceName=GunService&sni=${sni}#${user}"
systemctl restart trojangrpc.service
service cron restart
clear
echo -e ""
echo -e "================================="
echo -e "        XRAY TROJAN GRPC        "
echo -e "================================="
echo -e "Remarks        : ${user}"
echo -e "IP             : ${MYIP}"
echo -e "Domain         : ${domain}"
echo -e "Subdomain      : ${dom}"
echo -e "port TCP       : ${tr}"
echo -e "Password       : ${uuid}"
echo -e "================================="
echo -e "Link TR        : ${trojanlink1}"
echo -e "================================="
echo -e "Created        : $hariini"
echo -e "Expired On     : $exp"
