#!/bin/bash
# Check if user is root
if [ $(id -u) != "0" ]; then
    echo "Error: You must be root to run this script"
    exit 1
fi

#以下列表从这里获取的https://github.com/aploium/zmirror/tree/master/more_configs
cat >&2 <<-'EOF'
	######################################################
	which site do you want to mirror? input the number. 
	If you want to add more than one, you can rerun this script
	------------------------------------------------------
	1. archive_org
	2. dropbox
	3. duckduckgo
	4. economist
	5. facebook
	6. google_and_zhwikipedia
	7. instagram
	8. thepiratebay
	9. thumblr
	10.twitter_mobile
	11.twitter_pc
	12.youtube_mobile
	13.youtube
	------------------------------------------------------
	a. not in this list, customize it.
	------------------------------------------------------
	EOF
read num

case "$num" in
1)  	NAME=archive_org;;
2)  	NAME=dropbox;;
3)  	NAME=duckduckgo;;
4)  	NAME=economist;;
5)  	NAME=facebook;;
6)  	NAME=google_and_zhwikipedia;;
7)  	NAME=instagram;;
8)  	NAME=thepiratebay;;
9)  	NAME=thumblr;;
10) 	NAME=twitter_mobile;;
11) 	NAME=twitter_pc;;
12) 	NAME=youtube_mobile;;
13) 	NAME=youtube;;
a) 	NAME=boilerplate ;;
*) 	echo "Wrong choice,exiting" && exit 1;;
esac

if [ "${NAME}" = "boilerplate" ]; then
	read -t 60 -p "(Input a name for your mirror site, such as: t66y ):" MIRROR_NAME
		if [ -z $MIRROR_NAME ]; then
			echo "mirror_name is not set, exiting"
			exit 1
		fi
    else
	MIRROR_NAME=${NAME}
fi

if [ -d "/var/www/${MIRROR_NAME}" ]; then
	echo "Mirror_name is already existing, please choose another name and run this script again"
	exit 1
fi

read -t 60 -p "(Input your Domain, such as: g.zmirrordemo.com):" DOMAIN
if [ -z $DOMAIN ]; then
	echo "Domain is not set, exiting"
	exit 1
fi

echo "You are ready to mirror \"${MIRROR_NAME}\" with the domain \"${DOMAIN}\""
read -p "Press [Enter] key to continue, Press \"Ctrl + C\" to Quit..."

export LC_ALL=C.UTF-8
\cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

#python3-dev build-essential必须安装，要不然cchardet fastcache lru-dict三者都会安装失败。
apt-get -y update
apt-get -y install python3 python3-dev wget git curl openssl cron build-essential
wget --no-check-certificate https://bootstrap.pypa.io/get-pip.py -O - | python3
pip3 install -U flask requests distro chardet cchardet fastcache lru-dict

apt-get -y install software-properties-common python-software-properties
LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/apache2 && apt-key update
apt-get -y update
apt-get -y install apache2
apt-get -y install libapache2-mod-wsgi-py3
a2enmod rewrite mime include headers filter expires deflate autoindex setenvif ssl http2

rm -rf /etc/apache2/sites-enabled/000-default.conf
rm -rf /etc/apache2/conf-enabled/apache2-doc.conf
rm -rf /etc/apache2/conf-enabled/security.conf
wget --no-check-certificate -O /etc/apache2/conf-enabled/apache2-boilerplate.conf https://github.com/aploium/zmirror-onekey/raw/master/configs/apache2-boilerplate.conf
wget --no-check-certificate -O /etc/apache2/sites-enabled/zmirror-http-redirection.conf https://github.com/aploium/zmirror-onekey/raw/master/configs/apache2-http.conf
wget --no-check-certificate -O /etc/apache2/sites-enabled/apache2-https.conf.sample  https://github.com/aploium/zmirror-onekey/raw/master/configs/apache2-https.conf


#开始安装zmirror
echo "zmirror start installation"
cd /var/www
git clone https://github.com/aploium/zmirror ${MIRROR_NAME} --depth=1
chown -R www-data.www-data ${MIRROR_NAME}

if [ "${MIRROR_NAME}" = "${NAME}" ]; then
	cp /var/www/${MIRROR_NAME}/more_configs/config_${MIRROR_NAME}.py /var/www/${MIRROR_NAME}/config.py
    else
	cp /var/www/${MIRROR_NAME}/more_configs/boilerplate.py /var/www/${MIRROR_NAME}/config.py
fi
sed -i "s/^my_host_scheme.*$/my_host_scheme = \'https:\/\/\'/g" /var/www/${MIRROR_NAME}/config.py
sed -i "s/^my_host_name.*$/my_host_name = \'${DOMAIN}\'/g" /var/www/${MIRROR_NAME}/config.py
echo "verbose_level = 2" >> /var/www/${MIRROR_NAME}/config.py
#youtube和twitter需要额外的custom_func.py配置文件
case "$num" in
	10 | 11 )  cp /var/www/${MIRROR_NAME}/more_configs/custom_func_twitter.py /var/www/${MIRROR_NAME}/custom_func.py;;
	12 | 13 )  cp /var/www/${MIRROR_NAME}/more_configs/custom_func_youtube.py /var/www/${MIRROR_NAME}/custom_func.py;;
esac

#certbot installation
if [ ! -d "/etc/certbot" ]; then
	apt-get install -y ca-certificates gcc python libpython-dev libpython2.7 libpython2.7-dev python-pkg-resources python-setuptools python2.7-dev zlib1g-dev
	apt-get install -y augeas-lenses dialog libaugeas0 libffi-dev libssl-dev python-dev python-virtualenv
	git clone https://github.com/certbot/certbot.git --depth=1 /etc/certbot
fi
service apache2 stop
/etc/certbot/certbot-auto certonly -t --agree-tos --standalone -m your@gmail.com -d ${DOMAIN}

#SSL certification weekly renew script
if [ ! -f "/etc/cron.weekly/zmirror-letsencrypt-renew.sh" ]; then
	cat > /etc/cron.weekly/zmirror-letsencrypt-renew.sh<<-EOF
	#!/bin/bash
	cd /etc/certbot
	/etc/certbot/certbot-auto renew -n --agree-tos --standalone --pre-hook "/usr/sbin/service apache2 stop" --post-hook "/usr/sbin/service apache2 start"
	exit 0
	EOF
	chmod a+x /etc/cron.weekly/zmirror-letsencrypt-renew.sh
fi

cp /etc/apache2/sites-enabled/apache2-https.conf.sample /etc/apache2/sites-enabled/zmirror-${MIRROR_NAME}-https.conf
sed -i "s/{{mirror_name}}/${MIRROR_NAME}/g" /etc/apache2/sites-enabled/zmirror-${MIRROR_NAME}-https.conf
sed -i "s/{{domain}}/${DOMAIN}/g" /etc/apache2/sites-enabled/zmirror-${MIRROR_NAME}-https.conf
sed -i "s/{{path_to_wsgi_py}}/\/var\/www\/${MIRROR_NAME}\/wsgi.py/g" /etc/apache2/sites-enabled/zmirror-${MIRROR_NAME}-https.conf
sed -i "s/{{this_mirror_folder}}/\/var\/www\/${MIRROR_NAME}/g" /etc/apache2/sites-enabled/zmirror-${MIRROR_NAME}-https.conf
sed -i "s/{{cert_file}}/\/etc\/letsencrypt\/live\/${DOMAIN}\/cert.pem/g" /etc/apache2/sites-enabled/zmirror-${MIRROR_NAME}-https.conf
sed -i "s/{{private_key_file}}/\/etc\/letsencrypt\/live\/${DOMAIN}\/privkey.pem/g" /etc/apache2/sites-enabled/zmirror-${MIRROR_NAME}-https.conf
sed -i "s/{{cert_chain_file}}/\/etc\/letsencrypt\/live\/${DOMAIN}\/chain.pem/g" /etc/apache2/sites-enabled/zmirror-${MIRROR_NAME}-https.conf

if [ "${MIRROR_NAME}" != "${NAME}" ]; then
	echo "Please manually edit the following file, then start the apache2 by \"service apache2 start\""
	echo "/var/www/${MIRROR_NAME}/config.py"
	exit 0
fi

service apache2 start
