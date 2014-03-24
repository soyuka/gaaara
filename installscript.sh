#!/bin/bash

  clear
 
    if [ $(id -u) -ne 0 ]
    then
       echo
       echo "This script must be run as root." 1>&2
       echo
       exit 1
    fi
 
    # demander nom et mot de passe
    read -p "Adding user now, please type your user name: " user
    read -s -p "Enter password: " pwd
    echo
 
    # ajout utilisateur
    useradd -m  -s /bin/bash "$user"
 
    # creation du mot de passe pour cet utilisateur
    echo "${user}:${pwd}" | chpasswd

 # gestionnaire de paquet
if [ "`dpkg --status aptitude | grep Status:`" == "Status: install ok installed" ]
then
        packetg="aptitude"
else
        packetg="apt-get"
fi


ip=$(ip addr | grep eth0 | grep inet | awk '{print $2}' | cut -d/ -f1)

##Log de l'instalation
exec 2>/home/$user/log

# Ajoute des dépots non-free
echo "#dépôt paquet propriétaire
deb http://ftp2.fr.debian.org/debian/ wheezy main non-free
deb-src http://ftp2.fr.debian.org/debian/ wheezy main non-free

# dépôt dotdeb php 5.5
deb http://packages.dotdeb.org wheezy-php55 all
deb-src http://packages.dotdeb.org wheezy-php55 all

# dépôt nginx
deb http://nginx.org/packages/debian/ wheezy nginx
deb-src http://nginx.org/packages/debian/ wheezy nginx" >> /etc/apt/sources.list

#Ajout des clée

##dotdeb
cd /tmp
wget http://www.dotdeb.org/dotdeb.gpg
apt-key add dotdeb.gpg

##nginx
cd /tmp
wget http://nginx.org/keys/nginx_signing.key
apt-key add nginx_signing.key

# Installation des paquets vitaux
$packetg update
$packetg safe-upgrade -y
$packetg install -y htop python build-essential pkg-config libcurl4-openssl-dev libsigc++-2.0-dev libncurses5-dev nginx vim nano screen subversion apache2-utils curl php5 php5-cli php5-fpm php5-curl php5-geoip git unzip unrar rar zip ffmpeg buildtorrent curl mediainfo


##Working directory##
cd gaaara
###########################################################
##     Installation XMLRPC Libtorrent Rtorrent           ##
###########################################################

svn checkout http://svn.code.sf.net/p/xmlrpc-c/code/stable xmlrpc-c
cd xmlrpc-c
./configure --disable-cplusplus
make
make install
cd ..
rm -rv xmlrpc-c


#clone rtorrent et libtorrent
wget --no-check-certificate http://libtorrent.rakshasa.no/downloads/libtorrent-0.13.2.tar.gz
tar -xf libtorrent-0.13.2.tar.gz

wget --no-check-certificate http://libtorrent.rakshasa.no/downloads/rtorrent-0.9.2.tar.gz
tar -xzf rtorrent-0.9.2.tar.gz

# libtorrent compilation
cd libtorrent-0.13.2
./autogen.sh
./configure
make
make install

# rtorrent compilation
cd ../rtorrent-0.9.2
./autogen.sh
./configure --with-xmlrpc-c
make
make install
###########################################################
##              Fin Instalation                          ##
###########################################################

#Creation des dossier
mkdir /var/www
su $user -c 'mkdir -p ~/downloads ~/uploads ~/incomplete ~/rtorrent ~/rtorrent/session'
mkdir -p /usr/local/nginx /usr/local/nginx/ssl /usr/local/nginx/pw /etc/nginx/sites-enabled
touch /etc/nginx/sites-enabled/rutorrent.conf
touch /usr/local/nginx/pw/rutorrent_passwd


#Téléchargement + déplacement de rutorrent (web)
svn checkout http://rutorrent.googlecode.com/svn/trunk/rutorrent/
svn checkout http://rutorrent.googlecode.com/svn/trunk/plugins/
mv ./plugins/* ./rutorrent/plugins/
rm -R ./plugins
mv rutorrent/ /var/www

###########################################################
##              Instalation des Plugins                  ##
###########################################################

cd /var/www/rutorrent/plugins/

##Logoff
svn co http://rutorrent-logoff.googlecode.com/svn/trunk/ logoff

##tadd-labels
wget http://rutorrent-tadd-labels.googlecode.com/files/lbll-suite_0.8.1.tar.gz
tar zxfv lbll-suite_0.8.1.tar.gz
rm lbll-suite_0.8.1.tar.gz


##Filemanager
svn co http://svn.rutorrent.org/svn/filemanager/trunk/filemanager
sed -i "s#pathToExternals\['rar'\] = '';#pathToExternals\['rar'\] = '/usr/bin/rar';#" /var/www/rutorrent/plugins/filemanager/conf.php
sed -i "s#pathToExternals\['zip'\] = '';#pathToExternals\['zip'\] = '/usr/bin/zip';#" /var/www/rutorrent/plugins/filemanager/conf.php
sed -i "s#pathToExternals\['unzip'\] = '';#pathToExternals\['unzip'\] = '/usr/bin/unzip';#" /var/www/rutorrent/plugins/filemanager/conf.php
sed -i "s#pathToExternals\['tar'\] = '';#pathToExternals\['tar'\] = '/bin/tar';#" /var/www/rutorrent/plugins/filemanager/conf.php
sed -i "s#pathToExternals\['gzip'\] = '';#pathToExternals\['gzip'\] = '/bin/gzip';#" /var/www/rutorrent/plugins/filemanager/conf.php
sed -i "s#pathToExternals\['bzip2'\] = '';#pathToExternals\['bzip2'\] = '/bin/bzip2';#" /var/www/rutorrent/plugins/filemanager/conf.php

##FILEUPLOAD
svn co http://svn.rutorrent.org/svn/filemanager/trunk/fileupload
chmod 775 fileupload/scripts/upload
###dependance
##Plowshare
cd    /home
    git clone https://code.google.com/p/plowshare/ plowshare4
    cd plowshare4
    make install

#on met à jour les liens symboliques et les permissions
ldconfig
chown -R www-data:www-data /var/www/rutorrent

#Configuration du plugin create
sed -i "s#$useExternal = false;#$useExternal = 'buildtorrent';#" /var/www/rutorrent/plugins/create/conf.php
sed -i "s#$pathToCreatetorrent = '';#$pathToCreatetorrent = '/usr/bin/buildtorrent';#" /var/www/rutorrent/plugins/create/conf.php



###########################################################
##              Configuration de php-fpm                 ##
###########################################################

##php.ini

sed -i.bak "s/2m/10m/g;" /etc/php5/fpm/php.ini
sed -i.bak "s/expose_php = On/expose_php = Off/g;" /etc/php5/fpm/php.ini


service php5-fpm restart

###########################################################
##              Configuration serveur web                ##
###########################################################


rm /etc/nginx/nginx.conf

cat <<'EOF' > /etc/nginx/nginx.conf

user nginx;
worker_processes auto;

pid /var/run/nginx.pid;
events { worker_connections 1024; }

http {
    include /etc/nginx/mime.types;
    default_type  application/octet-stream;

    access_log /var/log/nginx/access.log combined;
    error_log /var/log/nginx/error.log error;
    
    sendfile on;
    keepalive_timeout 20;
    keepalive_disable msie6;
    keepalive_requests 100;
    tcp_nopush on;
    tcp_nodelay off;
    server_tokens off;
    
    gzip on;
    gzip_buffers 16 8k;
    gzip_comp_level 5;
    gzip_disable "msie6";
    gzip_min_length 20;
    gzip_proxied any;
    gzip_types text/plain text/css application/json  application/x-javascript text/xml application/xml application/xml+rss  text/javascript;
    gzip_vary on;

    include /etc/nginx/sites-enabled/*.conf;
}
EOF

cat <<'EOF' > /etc/nginx/sites-enabled/rutorrent.conf
server {
    listen 80 default_server;
    listen 443 default_server ssl;
    server_name _;
    index index.html index.php;
    charset utf-8;

    ssl_certificate /usr/local/nginx/ssl/serv.pem;
    ssl_certificate_key /usr/local/nginx/ssl/serv.key;

    access_log /var/log/nginx/rutorrent-access.log combined;
    error_log /var/log/nginx/rutorrent-error.log error;
    
    error_page 500 502 503 504 /50x.html;
    location = /50x.html { root /usr/share/nginx/html; }

    auth_basic "seedbox";
    auth_basic_user_file "/usr/local/nginx/pw/rutorrent_passwd";
    
    location = /favicon.ico {
        access_log off;
        return 204;
    }
    
    ## début config rutorrent ##

    location ^~ /rutorrent {
	root /var/www;
	include /etc/nginx/conf.d/php;
	include /etc/nginx/conf.d/cache;

	location ~ /\.svn {
		deny all;
	}

	location ~ /\.ht {
		deny all;
	}
    }

    location ^~ /rutorrent/conf/ {
	deny all;
    }

    location ^~ /rutorrent/share/ {
	deny all;
    }
    
    ## fin config rutorrent ##

    ## Début config cakebox 2.8 ##

#    location ^~ /cakebox {
#	root /var/www/;
#	include /etc/nginx/conf.d/php;
#	include /etc/nginx/conf.d/cache;
#    }

#    location /cakebox/downloads {
#	root /var/www;
#	satisfy any;
#	allow all;
#    }

    ## fin config cakebox 2.8 ##

    ## début config seedbox manager ##

#    location ^~ / {
#	root /var/www/manager;
#	include /etc/nginx/conf.d/php;
#	include /etc/nginx/conf.d/cache;
#    }

#    location ^~ /conf/ {
#	root /var/www/manager;
#	deny all;
#    }

    ## fin config seedbox manager ##

}
EOF



cat <<'EOF' > /etc/nginx/conf.d/php
location ~ \.php$ {
	fastcgi_index index.php;
	fastcgi_pass unix:/var/run/php5-fpm.sock;
	fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
	include /etc/nginx/fastcgi_params;
}
EOF


cat <<'EOF' > /etc/nginx/conf.d/cache
location ~* \.(jpg|jpeg|gif|css|png|js|woff|ttf|svg|eot)$ {
    expires 7d;
    access_log off;
}

location ~* \.(eot|ttf|woff|svg)$ {
    add_header Acccess-Control-Allow-Origin *;
}
EOF

rm /etc/logrotate.d/nginx && touch /etc/logrotate.d/nginx

cat <<'EOF' > /etc/logrotate.d/nginx
/var/log/nginx/*.log {
	daily
	missingok
	rotate 52
	compress
	delaycompress
	notifempty
	create 640 root
	sharedscripts
        postrotate
                [ -f /var/run/nginx.pid ] && kill -USR1 `cat /var/run/nginx.pid`
        endscript
}
EOF




###########################################################
##             SSL Configuration                         ##
###########################################################

#!/bin/bash

openssl req -new -x509 -days 3658 -nodes -newkey rsa:2048 -out /usr/local/nginx/ssl/serv.pem -keyout /usr/local/nginx/ssl/serv.key<<EOF
RU
Russia
Moskva
wrty
wrty LTD
wrty.com
contact@wrty.com
EOF

service nginx restart
###########################################################
##             SSL Configuration    Fin                  ##
###########################################################

#SSH config
sed -i.bak "s/Subsystem sftp/#Subsystem sftp/g;" /etc/ssh/sshd_config
sed -i.bak "s/UsePAM/#UsePAM/g;" /etc/php5/fpm/php.ini
sed -i.old -e "78i\Subsystem sftp internal-sftp" /etc/ssh/sshd_config
    
cat <<'EOF' >  /home/$user/.rtorrent.rc
execute = {sh,-c,rm -f /home/@user@/rtorrent/session/rpc.socket}
scgi_local = /home/@user@/rtorrent/session/rpc.socket
execute = {sh,-c,chmod 0666 /home/@user@/rtorrent/session/rpc.socket}
encoding_list = UTF-8
system.umask.set = 022
port_random = yes
check_hash = no
directory = /home/@user@/incomplete
session = /home/@user@/rtorrent/session
encryption = allow_incoming, try_outgoing, enable_retry
trackers.enable = 1
use_udp_trackers = yes
EOF
sed -i.bak "s/@user@/$user/g;" /home/$user/.rtorrent.rc

chown -R $user:$user /home/$user
chown root:$user /home/$user
chmod 755 /home/$user

###########################################################
##                    htpasswd                           ##
###########################################################
python /root/gaaara/htpasswd.py -b /usr/local/nginx/pw/rutorrent_passwd $user ${pwd}
chmod 640 /usr/local/nginx/pw/rutorrent_passwd/*
chown -c nginx:nginx /usr/local/nginx/pw/*
service nginx restart
###########################################################
##                    htpasswd                           ##
###########################################################

## répertoire de configuration de ruTorrent

mkdir /var/www/rutorrent/conf/users/$user
cat <<'EOF' >  /var/www/rutorrent/conf/users/$user/config.php
<?php
\$scgi_port = 0;
\$scgi_host = "unix:///home/@user@/rtorrent/session/rpc.socket";
\$XMLRPCMountPoint = "/RPC00001";
\$pathToExternals = array(
    "php"   => '',               
    "curl"  => '/usr/bin/curl',  
    "gzip"  => '',               
    "id"    => '',               
    "stat"  => '/usr/bin/stat',  
);
\$topDirectory = "/home/@user@";
?>
EOF
sed -i.bak "s/@user@/$user/g;" /var/www/rutorrent/conf/users/$user/config.php


cat <<'EOF' > /etc/init.d/$user-rtorrent
#!/bin/sh -e
# Start/Stop rtorrent sous forme de daemon.

NAME=@user@-rtorrent
SCRIPTNAME=/etc/init.d/$NAME
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

case $1 in
        start)
                echo "Starting rtorrent... "
                su -l @user@ -c "screen -fn -dmS rtd nice -19 rtorrent"
                echo "Terminated"
        ;;
        stop)
                if [ "$(ps aux | grep -e '.*rtorrent$' -c)" != 0  ]; then
                {
                        echo "Shutting down rtorrent... "
                        killall -r "^.*rtorrent$"
                        echo "Terminated"
                }
                else
                {
                        echo "rtorrent not yet started !"
                        echo "Terminated"
                }
                fi
        ;;
        restart)
                if [ "$(ps aux | grep -e '.*rtorrent$' -c)" != 0  ]; then
                {
                        echo "Shutting down rtorrent... "
                        killall -r "^.*rtorrent$"
                        echo "Starting rtorrent... "
                        su -l @user@ -c "screen -fn -dmS rtd nice -19 rtorrent"
                        echo "Terminated"
                }
                else
                {
                        echo "rtorrent not yet started !"
                        echo "Starting rtorrent... "
                        su -l @user@ -c "screen -fn -dmS rtd nice -19 rtorrent"
                        echo "Terminated"
                }
                fi
        ;;
        *)
                echo "Usage: $SCRIPTNAME {start|stop|restart}" >&2
                exit 2
        ;;
esac
EOF

sed -i.bak "s/@user@/$user/g;" /etc/init.d/$user-rtorrent

#Configuration rtorrent deamon
chmod +x /etc/init.d/$user-rtorrent
update-rc.d rtorrent defaults 99




