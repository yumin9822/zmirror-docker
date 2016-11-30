#!/bin/bash
#源项目地址https://github.com/aploium/zmirror
#Maintainer yumin9822@gmail.com
#本项目https://github.com/yumin9822/zmirror-docker
#############################################
#部分配置都是从ubuntu系统转过来的，CentOS配置有以下几点不同
#1. python3.5和apache2.4.18都是通过repo来安装的
#2. apache2安装的路径是/opt/rh/httpd24/root/usr/sbin/httpd
#3. CentOS的站点默认是user:group是"apache.apache"
#4. 还要通过repo安装httpd24-mod_ssl，这个会自动添加module加载配置文件中
#5. 需要pip3安装mod_wsgi及手动创建conf加载
#6. Zmirror的新加站点Apache站点配置，必须修改www-data为apache，还要修改变量APACHE_LOG_DIR为常量"/var/log/httpd24"
#7. 手动添加了一个port.conf
#
#
#
#############################################
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
# Check if it is x86_64
if [ "$(getconf LONG_BIT)" = "32" ]; then
	echo "This script is only can run in x86_64 due to lacking support of Apache 2.4.18 in x86"
	exit 1
fi

# Check if user is root
if [ $(id -u) != "0" ]; then
    echo "Error: You must be root to run this script"
    exit 1
fi

#以下列表从这里获取的https://github.com/aploium/zmirror/tree/master/more_configs
#列表9中原作者有一处拼写错误，thumblr，脚本仅在前面手动选择处改为tumblr。后续还是保持和原作者一直。
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
	9. tumblr
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


\cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
yum install -y epel-release

#python35u-devel Development tools必须安装，要不然cchardet fastcache lru-dict三者都会安装失败。
#Packages List  https://ius.io/Packages/
type pip3 >/dev/null 2>&1
if [ $? -ne 0 ]; then
	echo "pip3 is not installed, start to install python3 and pip3"
	rpm -Uvh https://centos6.iuscommunity.org/ius-release.rpm
	yum install -y python35u python35u-devel wget git curl openssl
	yum groupinstall "Development tools" -y
	wget --no-check-certificate https://bootstrap.pypa.io/get-pip.py -O - | python3.5
fi

pip3 list| grep Flask >/dev/null 2>&1 && pip3 list| grep requests >/dev/null 2>&1
if [ $? -ne 0 ]; then
	echo "Python dependencies are not installed, start to install"
	#pip3 install -U flask requests distro chardet cchardet fastcache lru-dict
	pip3 install -r https://github.com/aploium/zmirror/raw/master/requirements.txt
fi

#http://unix.stackexchange.com/questions/138899/centos-install-using-yum-apache-2-4
#HTTP/2 protocol only supported over Apache version >=2.4.17
#config files are in: /opt/rh/httpd24/root/etc/httpd
#httpd2.4.18 installed as /opt/rh/httpd24/root/usr/sbin/httpd
#mod for httpd24 http://serverfault.com/questions/56394/how-do-i-enable-apache-modules-from-the-command-line-in-redhat

#httpd24-httpd-devel必须安装，后续为pip3安装mode_wsgi提供'apxs' command
#Packages List  http://mirror.centos.org/centos/6/sclo/x86_64/rh/
if [ ! -f "/opt/rh/httpd24/root/usr/sbin/httpd" ]; then
	yum install -y centos-release-scl
	yum install -y httpd24 httpd24-httpd-devel httpd24-mod_ssl
	chkconfig httpd off
	chkconfig httpd24-httpd on
	service httpd stop
fi

if [ ! -f /usr/lib64/python3.5/site-packages/mod_wsgi/server/mod_wsgi*.so ]; then
	#必须手动添加下面一行，要不然找不到报错找不到apxs
	export PATH=$PATH:/opt/rh/httpd24/root/usr/bin:/opt/rh/httpd24/root/usr/sbin
	pip3 install mod_wsgi
	touch /opt/rh/httpd24/root/etc/httpd/conf.modules.d/00-wsgi.conf
	echo "LoadModule wsgi_module /usr/lib64/python3.5/site-packages/mod_wsgi/server/mod_wsgi-py35.cpython-35m-x86_64-linux-gnu.so" > /opt/rh/httpd24/root/etc/httpd/conf.modules.d/00-wsgi.conf
fi


rm -rf /opt/rh/httpd24/root/etc/httpd/conf.d/autoindex.conf
rm -rf /opt/rh/httpd24/root/etc/httpd/conf.d/ssl.conf
rm -rf /opt/rh/httpd24/root/etc/httpd/conf.d/userdir.conf
rm -rf /opt/rh/httpd24/root/etc/httpd/conf.d/welcome.conf
if [ ! -f "/opt/rh/httpd24/root/etc/httpd/conf.d/apache2-boilerplate.conf" ]; then
	wget --no-check-certificate -O /opt/rh/httpd24/root/etc/httpd/conf.d/apache2-boilerplate.conf https://github.com/aploium/zmirror-onekey/raw/master/configs/apache2-boilerplate.conf
	wget --no-check-certificate -O /opt/rh/httpd24/root/etc/httpd/conf.d/zmirror-http-redirection.conf https://github.com/aploium/zmirror-onekey/raw/master/configs/apache2-http.conf
	wget --no-check-certificate -O /opt/rh/httpd24/root/etc/httpd/conf.d/apache2-https.conf.sample  https://github.com/aploium/zmirror-onekey/raw/master/configs/apache2-https.conf
	sed -i "s/\/opt\/rh\/httpd24\/root\/var\/www\/html/\/var\/www/g" /opt/rh/httpd24/root/etc/httpd/conf/httpd.conf
	sed -i 's/${APACHE_LOG_DIR}/\/var\/log\/httpd24/g' /opt/rh/httpd24/root/etc/httpd/conf.d/apache2-https.conf.sample
	sed -i 's/${APACHE_LOG_DIR}/\/var\/log\/httpd24/g' /opt/rh/httpd24/root/etc/httpd/conf.d/zmirror-http-redirection.conf
	sed -i "s/www-data/apache/g" /opt/rh/httpd24/root/etc/httpd/conf.d/apache2-https.conf.sample
	cat > /opt/rh/httpd24/root/etc/httpd/conf.d/port.conf<<-EOF
		Listen 80
		<IfModule ssl_module>
		        Listen 443
		</IfModule>
		<IfModule mod_gnutls.c>
		        Listen 443
		</IfModule>
		EOF
fi

#开始安装zmirror
echo "zmirror start installation"
mkdir /var/www
cd /var/www
git clone https://github.com/aploium/zmirror ${MIRROR_NAME}
chown -R apache.apache ${MIRROR_NAME}

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
	yum install -y augeas-libs dialog libffi-devel mod_ssl openssl-devel python-devel python-pip python-tools python-virtualenv
	git clone https://github.com/certbot/certbot.git --depth=1 /etc/certbot
	iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport 443 -j ACCEPT
	iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport 80 -j ACCEPT
	service iptables save && service iptables restart
fi
service httpd24-httpd stop
service httpd stop
/etc/certbot/certbot-auto certonly -t --agree-tos --standalone -m your@gmail.com -d ${DOMAIN}

#SSL certification weekly renew script
if [ ! -f "/etc/cron.weekly/zmirror-letsencrypt-renew.sh" ]; then
	cat > /etc/cron.weekly/zmirror-letsencrypt-renew.sh<<-EOF
	#!/bin/bash
	cd /etc/certbot
	/etc/certbot/certbot-auto renew -n --agree-tos --standalone --pre-hook "/usr/sbin/service httpd24-httpd stop" --post-hook "/usr/sbin/service httpd24-httpd start"
	exit 0
	EOF
	chmod a+x /etc/cron.weekly/zmirror-letsencrypt-renew.sh
fi

cp /opt/rh/httpd24/root/etc/httpd/conf.d/apache2-https.conf.sample /opt/rh/httpd24/root/etc/httpd/conf.d/zmirror-${MIRROR_NAME}-https.conf
sed -i "s/{{mirror_name}}/${MIRROR_NAME}/g" /opt/rh/httpd24/root/etc/httpd/conf.d/zmirror-${MIRROR_NAME}-https.conf
sed -i "s/{{domain}}/${DOMAIN}/g" /opt/rh/httpd24/root/etc/httpd/conf.d/zmirror-${MIRROR_NAME}-https.conf
sed -i "s/{{path_to_wsgi_py}}/\/var\/www\/${MIRROR_NAME}\/wsgi.py/g" /opt/rh/httpd24/root/etc/httpd/conf.d/zmirror-${MIRROR_NAME}-https.conf
sed -i "s/{{this_mirror_folder}}/\/var\/www\/${MIRROR_NAME}/g" /opt/rh/httpd24/root/etc/httpd/conf.d/zmirror-${MIRROR_NAME}-https.conf
sed -i "s/{{cert_file}}/\/etc\/letsencrypt\/live\/${DOMAIN}\/cert.pem/g" /opt/rh/httpd24/root/etc/httpd/conf.d/zmirror-${MIRROR_NAME}-https.conf
sed -i "s/{{private_key_file}}/\/etc\/letsencrypt\/live\/${DOMAIN}\/privkey.pem/g" /opt/rh/httpd24/root/etc/httpd/conf.d/zmirror-${MIRROR_NAME}-https.conf
sed -i "s/{{cert_chain_file}}/\/etc\/letsencrypt\/live\/${DOMAIN}\/chain.pem/g" /opt/rh/httpd24/root/etc/httpd/conf.d/zmirror-${MIRROR_NAME}-https.conf
#以下两项是不同于ubuntu的地方
sed -i "s/www-data/apache/g" /opt/rh/httpd24/root/etc/httpd/conf.d/zmirror-${MIRROR_NAME}-https.conf
sed -i 's/${APACHE_LOG_DIR}/\/var\/log\/httpd24/g' /opt/rh/httpd24/root/etc/httpd/conf.d/zmirror-${MIRROR_NAME}-https.conf

if [ "${MIRROR_NAME}" != "${NAME}" ]; then
	echo "Please manually edit the following file, then start the apache2 by \"service httpd24-httpd start\""
	echo "/var/www/${MIRROR_NAME}/config.py"
	exit 0
fi

service httpd24-httpd start
