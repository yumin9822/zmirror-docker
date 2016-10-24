#!/bin/bash
#set -e

if [ "${DOMAIN}" == "**None**" ]; then
    echo "Please specify DOMAIN"
    exit 1
fi


#echo -e "${SSLCert}" > /ssl/cert.pem
#echo -e "${SSLKEY}" > /ssl/privkey.pem
#echo -e "${SSLChain}" > /ssl/chain.pem
/bin/cp /etc/apache2/sites-enabled/apache2-https.conf.sample /etc/apache2/sites-enabled/zmirror-${MIRROR_NAME}-https.conf
/bin/sed -i "s/{{mirror_name}}/${MIRROR_NAME}/g" /etc/apache2/sites-enabled/zmirror-${MIRROR_NAME}-https.conf
/bin/sed -i "s/{{domain}}/${DOMAIN}/g" /etc/apache2/sites-enabled/zmirror-${MIRROR_NAME}-https.conf
/bin/sed -i "s/{{path_to_wsgi_py}}/\/var\/www\/${MIRROR_NAME}\/wsgi.py/g" /etc/apache2/sites-enabled/zmirror-${MIRROR_NAME}-https.conf
/bin/sed -i "s/{{this_mirror_folder}}/\/var\/www\/${MIRROR_NAME}/g" /etc/apache2/sites-enabled/zmirror-${MIRROR_NAME}-https.conf
/bin/sed -i "s/{{cert_file}}/\/etc\/letsencrypt\/live\/${DOMAIN}\/cert.pem/g" /etc/apache2/sites-enabled/zmirror-${MIRROR_NAME}-https.conf
/bin/sed -i "s/{{private_key_file}}/\/etc\/letsencrypt\/live\/${DOMAIN}\/privkey.pem/g" /etc/apache2/sites-enabled/zmirror-${MIRROR_NAME}-https.conf
/bin/sed -i "s/{{cert_chain_file}}/\/etc\/letsencrypt\/live\/${DOMAIN}\/chain.pem/g" /etc/apache2/sites-enabled/zmirror-${MIRROR_NAME}-https.conf


case "$1" in
start)
	exec /usr/sbin/apache2ctl -D FOREGROUND
	;;
bash)
	exec /bin/bash
	;;
*)
	echo "Wrong parameters, try bash"
	;;
esac
