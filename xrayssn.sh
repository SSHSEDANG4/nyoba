#!/bin/bash
# Auth: happylife YES
# Desc: xray installation script
# 	    ws+vless,ws+trojan,ws+socks,ws+shadowsocks
#	      grpc+vless,grpc+trojan,grpc+socks,grpc+shadowsocks
# Plat: ubuntu 18.04+
# Eg  : bash xray_installation_ws+grpc_vless+trojan+socks+shadowsocks.sh "你的域名"

if [ -z "$1" ];then
	echo "Domain Tidak Boleh Kosong"
	exit
fi

# Konfigurasikan zona waktu sistem sebagai Jakarta/Indonesia.
ln -fs /usr/share/zoneinfo/Asia/Jakarta /etc/localtime

# Perbarui sumber resmi Ubuntu, instal nginx dan paket dependen menggunakan sumber resmi ubuntu dan atur boot untuk memulai, tutup firewall ufw.
apt clean all && apt update
apt install nginx curl pwgen openssl netcat cron -y
systemctl enable nginx
ufw disable


# Sebelum memulai penerapan, mari kita konfigurasikan parameter yang perlu digunakan, sebagai berikut:
# "域名，uuid，ws和grpc路径，domainSock目录，ssl证书目录"

# 1.Siapkan nama domain Anda yang telah diselesaikan.
domainName=$(cat /etc/xray/domain)
host=$(cat /etc/xray/domain)

# 2.Secara acak menghasilkan uuid.
uuid="`uuidgen`"

# 3.Buat port layanan secara acak yang perlu digunakan oleh socks dan shadowsocks.
socks_ws_port="`shuf -i 20000-30000 -n 1`"
shadowsocks_ws_port="`shuf -i 30001-40000 -n 1`"
socks_grpc_port="`shuf -i 40001-50000 -n 1`"
shadowsocks_grpc_port="`shuf -i 50001-60000 -n 1`"

# 4.分别随机生成trojan,socks和shadowsocks用户密码
trojan_passwd="$(pwgen -1cnys -r "'\";:$\\" 16)"
socks_user="$(pwgen -1cns 9)"
socks_passwd="$(pwgen -1cnys -r "'\";:$\\" 16)"
shadowsocks_passwd="$(pwgen -1cnys -r "'\";:$\\" 16)"

# 5.Gunakan WS untuk mengonfigurasi protokol vless, trojan, socks, shadowsocks
# 分别随机生成vless,trojan,socks,shadowsocks需要使用的ws的path
vless_ws_path="/vlesswsssn"
trojan_ws_path="/trojanwsssn"
socks_ws_path="/`pwgen -csn 6 8 | xargs |sed 's/ /\//g'`"
shadowsocks_ws_path="/`pwgen -csn 6 8 | xargs |sed 's/ /\//g'`"

# 6.Gunakan GRPC untuk mengonfigurasi protokol vless, trojan, socks, shadowsocks
# 分别随机生成vless,trojan,socks,shadowsocks需要使用的grpc的path
vless_grpc_path="/vlessgrpcssn"
trojan_grpc_path="/trojangrpcssn"
socks_grpc_path="$(pwgen -1scn 12)$(pwgen -1scny -r "\!@#$%^&*()-+={}[]|:\";',/?><\`~" 36)"
shadowsocks_grpc_path="$(pwgen -1scn 12)$(pwgen -1scny -r "\!@#$%^&*()-+={}[]|:\";',/?><\`~" 36)"

# 7.创建需要用的domainSock目录,并授权nginx用户权限
domainSock_dir="/run/xray";! [ -d $domainSock_dir ] && mkdir -pv $domainSock_dir
chown www-data.www-data $domainSock_dir

# 8.定义需要用到的domainSock文件名
vless_ws_domainSock="${domainSock_dir}/vless_ws.sock"
trojan_ws_domainSock="${domainSock_dir}/trojan_ws.sock"
vless_grpc_domainSock="${domainSock_dir}/vless_grpc.sock"
trojan_grpc_domainSock="${domainSock_dir}/trojan_grpc.sock"

# 9.Buat direktori secara acak untuk menyimpan sertifikat ssl berdasarkan waktu.
ssl_dir="$(mkdir -pv "/etc/nginx/ssl/`date +"%F-%H-%M-%S"`" |awk -F"'" END'{print $2}')"


# 使用xray官方命令安装xray并指定www-data为运行用户
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install -u www-data


##安装acme,并申请加密证书
source ~/.bashrc
if nc -z localhost 443;then /etc/init.d/nginx stop;fi
if ! [ -d /root/.acme.sh ];then curl https://get.acme.sh | sh;fi
~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
~/.acme.sh/acme.sh --issue -d "$domainName" -k ec-256 --alpn
~/.acme.sh/acme.sh --installcert -d "$domainName" --fullchainpath $ssl_dir/xray.crt --keypath $ssl_dir/xray.key --ecc
chown www-data.www-data $ssl_dir/xray.*

## Tambahkan Perintah Perbarui Sertifikat ke Tugas Terjadwal.
echo -n '#!/bin/bash
/etc/init.d/nginx stop
"/root/.acme.sh"/acme.sh --cron --home "/root/.acme.sh" &> /root/renew_ssl.log
/etc/init.d/nginx start
' > /usr/local/bin/ssl_renew.sh
chmod +x /usr/local/bin/ssl_renew.sh
if ! grep -q 'ssl_renew.sh' /var/spool/cron/crontabs/root;then (crontab -l;echo "15 03 */3 * * /usr/local/bin/ssl_renew.sh") | crontab;fi


# 配置nginx，执行如下命令即可添加nginx配置文件
echo "
server {
	listen 80;
	server_name "$domainName";
	return 301 https://"'$host'""'$request_uri'";
}
server {
	listen 443 ssl http2;
	listen [::]:443 ssl http2;
	server_name "$domainName";
	ssl_certificate $ssl_dir/xray.crt;
	ssl_certificate_key $ssl_dir/xray.key;
	ssl_ciphers EECDH+CHACHA20:EECDH+CHACHA20-draft:EECDH+ECDSA+AES128:EECDH+aRSA+AES128:RSA+AES128:EECDH+ECDSA+AES256:EECDH+aRSA+AES256:RSA+AES256:EECDH+ECDSA+3DES:EECDH+aRSA+3DES:RSA+3DES:!MD5;
	ssl_protocols TLSv1.1 TLSv1.2 TLSv1.3;
	root /usr/share/nginx/html;
  
	# ------------------- WS配置部分开始 -------------------
	location = "$vless_ws_path" {
		proxy_redirect off;
		proxy_pass http://unix:"${vless_ws_domainSock}";
		proxy_http_version 1.1;
		proxy_set_header Upgrade "'"$http_upgrade"'";
		proxy_set_header Connection '"'upgrade'"';
    proxy_set_header Host "'"$host"'";
    proxy_set_header X-Real-IP "'"$remote_addr"'";
    proxy_set_header X-Forwarded-For "'"$proxy_add_x_forwarded_for"'";		
	}	
	
	location = "$trojan_ws_path" {
		proxy_redirect off;
		proxy_pass http://unix:"${trojan_ws_domainSock}";
		proxy_http_version 1.1;
		proxy_set_header Upgrade "'"$http_upgrade"'";
		proxy_set_header Connection '"'upgrade'"';
	  proxy_set_header Host "'"$host"'";
	  proxy_set_header X-Real-IP "'"$remote_addr"'";
	  proxy_set_header X-Forwarded-For "'"$proxy_add_x_forwarded_for"'";		
	}	
	
	location = "$socks_ws_path" {
		proxy_redirect off;
		proxy_pass http://127.0.0.1:"$socks_ws_port";
		proxy_http_version 1.1;
		proxy_set_header Upgrade "'"$http_upgrade"'";
		proxy_set_header Connection '"'upgrade'"';
	  proxy_set_header Host "'"$host"'";
	  proxy_set_header X-Real-IP "'"$remote_addr"'";
	  proxy_set_header X-Forwarded-For "'"$proxy_add_x_forwarded_for"'";		
	}
	
	location = "$shadowsocks_ws_path" {
		proxy_redirect off;
		proxy_pass http://127.0.0.1:"$shadowsocks_ws_port";
		proxy_http_version 1.1;
		proxy_set_header Upgrade "'"$http_upgrade"'";
		proxy_set_header Connection '"'upgrade'"';
	  proxy_set_header Host "'"$host"'";
	  proxy_set_header X-Real-IP "'"$remote_addr"'";
	  proxy_set_header X-Forwarded-For "'"$proxy_add_x_forwarded_for"'";	
	}	
	# ------------------- WS配置部分结束 -------------------
	
	# ------------------ gRPC配置部分开始 ------------------
	location ^~ "/$vless_grpc_path" {
		proxy_redirect off;
	  grpc_set_header Host "'"$host"'";
	  grpc_set_header X-Real-IP "'"$remote_addr"'";
	  grpc_set_header X-Forwarded-For "'"$proxy_add_x_forwarded_for"'";
		grpc_pass grpc://unix:"${vless_grpc_domainSock}";		
	}
	
	location ^~ "/$trojan_grpc_path" {
		proxy_redirect off;
	  grpc_set_header Host "'"$host"'";
	  grpc_set_header X-Real-IP "'"$remote_addr"'";
	  grpc_set_header X-Forwarded-For "'"$proxy_add_x_forwarded_for"'";
		grpc_pass grpc://unix:"${trojan_grpc_domainSock}";	
	}	
	
	location ^~ "/$socks_grpc_path" {
		proxy_redirect off;
	  grpc_set_header Host "'"$host"'";
	  grpc_set_header X-Real-IP "'"$remote_addr"'";
	  grpc_set_header X-Forwarded-For "'"$proxy_add_x_forwarded_for"'";
		grpc_pass grpc://127.0.0.1:"$socks_grpc_port";	
	}
	
	location ^~ "/$shadowsocks_grpc_path" {
		proxy_redirect off;
	  grpc_set_header Host "'"$host"'";
	  grpc_set_header X-Real-IP "'"$remote_addr"'";
	  grpc_set_header X-Forwarded-For "'"$proxy_add_x_forwarded_for"'";
		grpc_pass grpc://127.0.0.1:"$shadowsocks_grpc_port";		
	}	
	# ------------------ gRPC配置部分结束 ------------------	
	
}
" > /etc/nginx/conf.d/xray.conf

# 配置xray，执行如下命令即可添加xray配置文件
echo '
{
  "log" : {
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log",
    "loglevel": "warning"
  },
  "inbounds": [
	{
		"listen": '"\"${vless_ws_domainSock}\""',
		"protocol": "vless",
		"settings": {
			"decryption":"none",
			"clients": [
				{
          "id": '"\"$uuid\""',
          "level": 1
				}
			]
		},
		"streamSettings":{
			"network": "ws",
			"wsSettings": {
				"path": '"\"$vless_ws_path\""'
			}
		}
	},
	{
		"listen": '"\"$trojan_ws_domainSock\""',
		"protocol": "trojan",
		"settings": {
			"decryption":"none",		
			"clients": [
				{
					"password": '"\"$trojan_passwd\""',
					"email": "",
					"level": 0
				}
			],
			"udp": true
		},
		"streamSettings":{
			"network": "ws",
			"wsSettings": {
				"path": '"\"$trojan_ws_path\""'
			}
		}
	},
	{
		"listen": "127.0.0.1",
		"port": '"\"$socks_ws_port\""',
		"protocol": "socks",
		"settings": {
			"auth": "password",
			"accounts": [
				{
					"user": '"\"$socks_user\""',
					"pass": '"\"$socks_passwd\""'
				}
			],
			"level": 0,
			"udp": true
		},
		"streamSettings":{
			"network": "ws",
			"wsSettings": {
				"path": '"\"$socks_ws_path\""'
			}
		}
	},
	{
		"listen": "127.0.0.1",
		"port": '"\"$shadowsocks_ws_port\""',
		"protocol": "shadowsocks",
		"settings": {
			"decryption":"none",
			"email": "",
			"method": "AES-128-GCM",
			"password": '"\"$shadowsocks_passwd\""',
			"level": 0,
			"network": "tcp,udp",
			"ivCheck": false
		},
		"streamSettings":{
			"network": "ws",
			"wsSettings": {
				"path": '"\"$shadowsocks_ws_path\""'
			}
		}
	},	
  	{
		"listen": '"\"${vless_grpc_domainSock}\""',
		"protocol": "vless",
		"settings": {
			"decryption":"none",
			"clients": [
				{
				"id": '"\"$uuid\""',
				"level": 0
				}
			]
		},
		"streamSettings":{
			"network": "grpc",
			"grpcSettings": {
				"serviceName": '"\"$vless_grpc_path\""'
			}
		}
	},
	{
		"listen": '"\"$trojan_grpc_domainSock\""',
		"protocol": "trojan",
		"settings": {
			"decryption":"none",
			"clients": [
				{
					"password": '"\"$trojan_passwd\""',
					"email": "",
					"level": 0
				}
			]
		},
		"streamSettings":{
		"network": "grpc",
			"grpcSettings": {
				"serviceName": '"\"$trojan_grpc_path\""'
			}
		}
	},
	{
		"listen": "127.0.0.1",
		"port": '"\"$socks_grpc_port\""',
		"protocol": "socks",
		"settings": {
			"decryption":"none",
			"auth": "password",
			"accounts": [
				{
					"user": '"\"$socks_user\""',
					"pass": '"\"$socks_passwd\""'
				}
			],
			"level": 0,
			"udp": true
		},
		"streamSettings":{
		"network": "grpc",
			"grpcSettings": {
				"serviceName": '"\"$socks_grpc_path\""'
			}
		}
	},
	{
		"listen": "127.0.0.1",
		"port": '"\"$shadowsocks_grpc_port\""',
		"protocol": "shadowsocks",
		"settings": {
			"decryption":"none",
			"email": "",
			"method": "AES-128-GCM",
			"password": '"\"$shadowsocks_passwd\""',
			"network": "tcp,udp",
			"ivCheck": false,
			"level": 0
		},
		"streamSettings":{
		"network": "grpc",
			"grpcSettings": {
				"serviceName": '"\"$shadowsocks_grpc_path\""'
			}
		}
	}	
  ],
  "outbound": {
    "protocol": "freedom",
    "settings": {
      "decryption":"none"
    }
  },
  "outboundDetour": [
    {
      "protocol": "blackhole",
      "settings": {
        "decryption":"none"
      },
      "tag": "blocked"
    }
  ],
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": [
      {
        "domain": [
            "geosite:cn"
        ],
        "outboundTag": "blocked",
        "type": "field"
      },      
      {
          "ip": [
              "geoip:cn"
          ],
          "outboundTag": "blocked",
          "type": "field"
      }
    ]
  },  
  "routing": {
    "strategy": "rules",
    "settings": {
      "decryption":"none",
      "rules": [
        {
          "type": "field",
          "ip": [ "geoip:private" ],
          "outboundTag": "blocked"
        }
      ]
    }
  }
}
' > /usr/local/etc/xray/config.json

# 重启xray和nginx
systemctl restart xray
systemctl status xray
/usr/sbin/nginx -t && systemctl restart nginx


# Keluarkan informasi konfigurasi dan simpan ke file
xray_config_info="/root/xray_config.info"
echo "
----------- Nama domain dan port terpadu untuk semua metode koneksi -----------
Domain	 : $domainName
Port	 : 443
------------- WS传输 ------------
-----------1. vless+ws -----------
Protokol : vless
UUID	 : $uuid
Path	 : $vless_ws_path
-----------2. trojan+ws -----------
Protokol : trojan
Password : $trojan_passwd
Path     : $trojan_ws_path
-----------3. socks+ws ------------
Protokol : socks
Username ：$socks_user	
Password : $socks_passwd
Path	 : $socks_ws_path
-------- 4. shadowsocks+ws ---------
Protokol : shadowsocks
Password : $shadowsocks_passwd
Enkripsi ：AES-128-GCM
Path	 : $shadowsocks_ws_path

------------ gRPC传输 -----------
------------5. vless+grpc -----------
Protokol : vless
UUID	 : $uuid
Path	 : $vless_grpc_path
-----------6. trojan+grpc -----------
Protokol : trojan
Password : $trojan_passwd
Path	 : $trojan_grpc_path
-----------7. socks+grpc ------------
Protokol : socks
Username ：$socks_user
Password : $socks_passwd
Path	 : $socks_grpc_path
--------8. shadowsocks+grpc ---------
Protokol : shadowsocks
Password : $shadowsocks_passwd
Enkripsi ：AES-128-GCM
Path	 : $shadowsocks_grpc_path
" | tee $xray_config_info
