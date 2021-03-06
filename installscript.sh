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
deb-src http://nginx.org/packages/debian/ wheezy nginx ">> /etc/apt/sources.list

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
$packetg install -y htop openssl python build-essential libssl-dev pkg-config whois  libcurl4-openssl-dev libsigc++-2.0-dev libncurses5-dev nginx vim nano screen subversion apache2-utils curl php5 php5-cli php5-fpm php5-curl php5-geoip git unzip unrar rar zip ffmpeg buildtorrent curl mediainfo

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
su $user -c 'mkdir -p ~/watch ~/torrents ~/.session '
mkdir /var/www

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

#Configuration du plugin create
sed -i "s#$useExternal = false;#$useExternal = 'buildtorrent';#" /var/www/rutorrent/plugins/create/conf.php
sed -i "s#$pathToCreatetorrent = '';#$pathToCreatetorrent = '/usr/bin/buildtorrent';#" /var/www/rutorrent/plugins/create/conf.php

##########################################################
##              Instalation des Plugins  FIN            ##
##########################################################

# liens symboliques et les permissions
ldconfig
chown -R www-data:www-data /var/www/rutorrent

##php.ini

sed -i.bak "s/2m/10m/g;" /etc/php5/fpm/php.ini
sed -i.bak "s/expose_php = On/expose_php = Off/g;" /etc/php5/fpm/php.ini


service php5-fpm restart

mkdir -p /etc/nginx/passwd /etc/nginx/ssl 
touch /etc/nginx/passwd/rutorrent_passwd
chmod 640 /etc/nginx/passwd/rutorrent_passwd

###########################################################
##              Configuration serveur web                ##
###########################################################


#########################################
##            nginx.conf               ##
#########################################
cat <<'EOF' >  /etc/nginx/nginx.conf
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
#########################################
##        nginx.conf Fin               ##
#########################################

##php
cat <<'EOF' >  /etc/nginx/conf.d/php
location ~ \.php$ {
	fastcgi_index index.php;
	fastcgi_pass unix:/var/run/php5-fpm.sock;
	fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
	include /etc/nginx/fastcgi_params;
}
EOF

##cache
cat <<'EOF' >  /etc/nginx/conf.d/cache
location ~* \.(jpg|jpeg|gif|css|png|js|woff|ttf|svg|eot)$ {
    expires 7d;
    access_log off;
}

location ~* \.(eot|ttf|woff|svg)$ {
    add_header Acccess-Control-Allow-Origin *;
}
EOF

##Configuration du vhost

mkdir /etc/nginx/sites-enabled
touch /etc/nginx/sites-enabled/rutorrent.conf

#########################################
##         rutorrent.conf              ##
#########################################
cat <<'EOF' >  /etc/nginx/sites-enabled/rutorrent.conf
server {
    listen 80 default_server;
    listen 443 default_server ssl;
    server_name _;
    index index.html index.php;
    charset utf-8;

    ssl_certificate /etc/nginx/ssl/server.crt;
    ssl_certificate_key /etc/nginx/ssl/server.key;

    access_log /var/log/nginx/rutorrent-access.log combined;
    error_log /var/log/nginx/rutorrent-error.log error;
    
    error_page 500 502 503 504 /50x.html;
    location = /50x.html { root /var/www/; }

    auth_basic "seedbox";
    auth_basic_user_file "/etc/nginx/passwd/rutorrent_passwd";
    
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

EOF
#########################################
##     rutorrent.conf Fin              ##
#########################################

###########################################################
##             SSL Configuration                         ##
###########################################################

#!/bin/bash

openssl req -new -x509 -days 3658 -nodes -newkey rsa:2048 -out /etc/nginx/ssl/server.crt -keyout /etc/nginx/ssl/server.key<<EOF
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

service nginx restart
rm /etc/logrotate.d/nginx && touch /etc/logrotate.d/nginx

##logrotate

cat <<'EOF' >  /etc/logrotate.d/nginx
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

##SSH config
sed -i.bak "s/Subsystem sftp/#Subsystem sftp/g;" /etc/ssh/sshd_config
sed -i.bak "s/UsePAM/#UsePAM/g;" /etc/php5/fpm/php.ini
sed -i.old -e "78i\Subsystem sftp internal-sftp" /etc/ssh/sshd_config

service ssh restart
#########################################
##     .rtorrent.rc conf               ##
#########################################
cat <<'EOF' >  /home/$user/.rtorrent.rc
scgi_port = 127.0.0.1:5001
encoding_list = UTF-8
port_range = 45000-65000
port_random = no
check_hash = no
directory = /home/@user@/torrents
session = /home/@user@/.session
encryption = allow_incoming, try_outgoing, enable_retry
schedule = watch_directory,1,1,"load_start=/home/@user@/watch/*.torrent"
schedule = untied_directory,5,5,"stop_untied=/home/@user@/watch/*.torrent"
use_udp_trackers = yes
dht = off
peer_exchange = no
min_peers = 40
max_peers = 100
min_peers_seed = 10
max_peers_seed = 50
max_uploads = 15
execute = {sh,-c,/usr/bin/php /var/www/rutorrent/php/initplugins.php @user@ &}
schedule = espace_disque_insuffisant,1,30,close_low_diskspace=500M
EOF
sed -i.bak "s/@user@/$user/g;" /home/$user/.rtorrent.rc
#########################################
##     .rtorrent.rc conf Fin           ##
#########################################

##permissions
chown -R $user:$user /home/$user
chown root:$user /home/$user
chmod 755 /home/$user
##user rtorrent.conf config
echo "## user configuration
location /usr01 {
        include scgi_params;
        scgi_pass 127.0.0.1:5001; #ou socket : unix:/home/username/.session/username.socket
        auth_basic seedbox;
        auth_basic_user_file /etc/nginx/passwd/rutorrent_passwd_$user;
    }
}
">> /etc/nginx/sites-enabled/rutorrent.conf

###########################################################
##                    htpasswd                           ##
###########################################################
python /root/gaaara/htpasswd.py -b /etc/nginx/passwd/rutorrent_passwd $user ${pwd}
chmod 640 /etc/nginx/passwd/*
chown -c nginx:nginx /etc/nginx/passwd/*
service nginx restart
###########################################################
##                    htpasswd                           ##
###########################################################
mkdir /var/www/rutorrent/conf/users/$user
##config.php
cat <<'EOF' >   /var/www/rutorrent/conf/users/$user/config.php
<?php
$topDirectory = '/home/@user@';
$scgi_port = 5001;
$scgi_host = '127.0.0.1';
$XMLRPCMountPoint = '/usr01';
$topDirectory = '/home/@user@/torrents';
$pathToExternals = array(
                "php"  => '/usr/bin/php',                       // Something like /usr/bin/php. If empty, will be found in PATH.
                "curl" => '/usr/bin/curl',                      // Something like /usr/bin/curl. If empty, will be found in PATH.
                "gzip" => '/bin/gzip',                  // Something like /usr/bin/gzip. If empty, will be found in PATH.
                "id"   => '/usr/bin/id',                        // Something like /usr/bin/id. If empty, will be found in PATH.
                "stat" => '/usr/bin/stat',                      // Something like /usr/bin/stat. If empty, will be found in PATH.
                "bzip2" => '/bin/bzip2',

        );
?>
EOF
sed -i.bak "s/@user@/$user/g;" /var/www/rutorrent/conf/users/$user/config.php
#########################################
##     rtorrent demon                  ##
#########################################

cat <<'EOF' >  /etc/init.d/$user-rtorrent
#!/bin/bash
 
### BEGIN INIT INFO
# Provides:                rtorrent
# Required-Start:       
# Required-Stop:       
# Default-Start:          2 3 4 5
# Default-Stop:          0 1 6
# Short-Description:  Start daemon at boot time
# Description:           Start-Stop rtorrent user session
### END INIT INFO
 
user="@user@"
 
# the full path to the filename where you store your rtorrent configuration
config="/home/@user@/.rtorrent.rc"
 
# set of options to run with
options=""
 
# default directory for screen, needs to be an absolute path
base="/home/@user@"
 
# name of screen session
srnname="rtorrent"
 
# file to log to (makes for easier debugging if something goes wrong)
logfile="/var/log/rtorrentInit.log"
#######################
###END CONFIGURATION###
#######################
PATH=/usr/bin:/usr/local/bin:/usr/local/sbin:/sbin:/bin:/usr/sbin
DESC="rtorrent"
NAME=rtorrent
DAEMON=$NAME
SCRIPTNAME=/etc/init.d/$NAME
 
checkcnfg() {
    exists=0
    for i in `echo "$PATH" | tr ':' '\n'` ; do
        if [ -f $i/$NAME ] ; then
            exists=1
            break
        fi
    done
    if [ $exists -eq 0 ] ; then
        echo "cannot find rtorrent binary in PATH $PATH" | tee -a "$logfile" >&2
        exit 3
    fi
    if ! [ -r "${config}" ] ; then
        echo "cannot find readable config ${config}. check that it is there and permissions are appropriate" | tee -a "$logfile" >&2
        exit 3
    fi
    session=`getsession "$config"`
    if ! [ -d "${session}" ] ; then
        echo "cannot find readable session directory ${session} from config ${config}. check permissions" | tee -a "$logfile" >&2
        exit 3
 
        fi
 
}
 
d_start() {
 
  [ -d "${base}" ] && cd "${base}"
 
  stty stop undef && stty start undef
  su -c "screen -ls | grep -sq "\.${srnname}[[:space:]]" " ${user} || su -c "screen -dm -S ${srnname} 2>&1 1>/dev/null" ${user} | tee -a "$logfile" >&2
  su -c "screen -S "${srnname}" -X screen rtorrent ${options} 2>&1 1>/dev/null" ${user} | tee -a "$logfile" >&2
}
 
d_stop() {
    session=`getsession "$config"`
    if ! [ -s ${session}/rtorrent.lock ] ; then
        return
    fi
    pid=`cat ${session}/rtorrent.lock | awk -F: '{print($2)}' | sed "s/[^0-9]//g"`
    if ps -A | grep -sq ${pid}.*rtorrent ; then # make sure the pid doesn't belong to another process
        kill -s INT ${pid}
    fi
}
 
getsession() {
    session=`cat "$1" | grep "^[[:space:]]*session[[:space:]]*=" | sed "s/^[[:space:]]*session[[:space:]]*=[[:space:]]*//" `
    echo $session
}
 
checkcnfg
 
case "$1" in
  start)
    echo -n "Starting $DESC: $NAME"
    d_start
    echo "."
    ;;
  stop)
    echo -n "Stopping $DESC: $NAME"
    d_stop
    echo "."
    ;;
  restart|force-reload)
    echo -n "Restarting $DESC: $NAME"
    d_stop
    sleep 1
    d_start
    echo "."
    ;;
  *)
    echo "Usage: $SCRIPTNAME {start|stop|restart|force-reload}" >&2
    exit 1
    ;;
esac
 
exit 0
EOF
sed -i.bak "s/@user@/$user/g;" /etc/init.d/$user-rtorrent
chmod +x /etc/init.d/$user-rtorrent
crontab -e
* * * * * if ! ( ps -U $user | grep rtorrent > /dev/null ); then /etc/init.d/$user-rtorrent start; fi
#########################################
##     rtorrent demon fin              ##
#########################################
