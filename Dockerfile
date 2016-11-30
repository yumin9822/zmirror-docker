FROM ubuntu:16.04
MAINTAINER Min Yu <yumin9822@gmail.com>

#Please make sure the DOMAIN has A record which is same with your server ip. Or the SSL certifications will not be issued by letsencrypt

ENV DOMAIN **None**
ENV MIRROR_NAME google
#ENV SSLCert **None**
#ENV SSLKEY **None**
#ENV SSLChain **None**

#python3 and flask requests cchardet fastcache dependencies installation
#cron可选安装。
RUN apt-get update && \cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    apt-get install -y build-essential patch binutils make devscripts nano libtool libssl-dev libxml2 \
                       libxml2-dev software-properties-common python-software-properties dnsutils \
                       git wget curl python3 python3-dev iftop cron && \
    wget --no-check-certificate https://bootstrap.pypa.io/get-pip.py -O - | python3

#推荐安装的cChardet fastcache需要安装python3-dev和build-essential
#RUN pip3 install -U flask requests distro chardet cchardet fastcache lru-dict
RUN pip3 install -r https://raw.githubusercontent.com/aploium/zmirror/master/requirements.txt

#Apache2 installation。 "LC_ALL=C.UTF-8"必须添加，要不然apt-key获取失败会导致后续很多错误。
RUN LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/apache2 && \
    apt-key update && apt-get update && apt-get upgrade -y && \
    apt-get install -y apache2 && \
    a2enmod rewrite mime include headers filter expires deflate autoindex setenvif ssl http2 && \
    apt-get install -y libapache2-mod-wsgi-py3

#Zmirror installation,如果要安装另外的例如YouTube镜像，请修改此段。
#Reference https://github.com/aploium/zmirror/wiki/%E5%9C%A8%E4%B8%80%E5%8F%B0VPS%E9%83%A8%E7%BD%B2%E5%A4%9A%E4%B8%AAzmirror%E9%95%9C%E5%83%8F
RUN cd /var/www && \
    git clone https://github.com/aploium/zmirror ${MIRROR_NAME} && chown -R www-data.www-data ${MIRROR_NAME} && \
    cp /var/www/${MIRROR_NAME}/more_configs/config_google_and_zhwikipedia.py /var/www/${MIRROR_NAME}/config.py && \
    sed -i "s/^my_host_scheme.*$/my_host_scheme = \'https:\/\/\'/g" /var/www/${MIRROR_NAME}/config.py && \
    echo "verbose_level = 2" >> /var/www/${MIRROR_NAME}/config.py

#Apache2 conf cleaning according to https://github.com/aploium/zmirror-onekey/blob/master/deploy.py
RUN rm -rf /etc/apache2/sites-enabled/000-default.conf && \
    rm -rf /etc/apache2/conf-enabled/apache2-doc.conf && \
    rm -rf /etc/apache2/conf-enabled/security.conf

#zmirror-apache-boilerplate.conf is the h5.conf
ADD zmirror-apache-boilerplate.conf /etc/apache2/conf-enabled/zmirror-apache-boilerplate.conf

#zmirror-http-redirection.conf is to let *:80 automatically redirects *:443
#apache2-https.conf and apache2-http.conf are two virtual host templates from zmirror-onekey
#ADD zmirror-http-redirection.conf /etc/apache2/sites-enabled/zmirror-http-redirection.conf
ADD apache2-https.conf /etc/apache2/sites-enabled/apache2-https.conf.sample
ADD apache2-http.conf /etc/apache2/sites-enabled/zmirror-http-redirection.conf
#ADD no-ip-access.conf /etc/apache2/sites-enabled/no-ip-access.conf


ADD ENTRY.sh /
RUN chmod a+x /ENTRY.sh

VOLUME ["/etc/letsencrypt"]

# PORTS
EXPOSE 80
EXPOSE 443

ENTRYPOINT ["/ENTRY.sh"]

CMD ["start"]
#CMD ["apache2ctl", "-D", "FOREGROUND"]
