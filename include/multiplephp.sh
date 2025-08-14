#!/usr/bin/env bash

Install_Multiplephp()
{
    Get_Dist_Name
    Check_DB
    Check_Stack
    Get_Dist_Version
    . include/upgrade_php.sh

    if [ "${Get_Stack}" != "lnmp" ]; then
        echo "Multiple PHP Versions ONLY for LNMP Stack!"
        exit 1
    fi

#which PHP Version do you want to install?
    echo "==========================="

    PHPSelect=""
    Echo_Yellow "You have 10 options for your PHP install."
    echo "1: Install ${PHP_Info[0]}"
    echo "2: Install ${PHP_Info[1]}"
    echo "3: Install ${PHP_Info[2]}"
    echo "4: Install ${PHP_Info[3]}"
    echo "5: Install ${PHP_Info[4]}"
    echo "6: Install ${PHP_Info[5]}"
    echo "7: Install ${PHP_Info[6]}"
    echo "8: Install ${PHP_Info[7]}"
    echo "9: Install ${PHP_Info[8]}"
    echo "10: Install ${PHP_Info[9]}"
    read -p "Enter your choice (1, 2, 3, 4, 5, 6, 7, 8, 9, 10): " PHPSelect

    case "${PHPSelect}" in
        1)
        echo "You will install ${PHP_Info[0]}"
        MPHP_Path='/usr/local/php7.0'
        Install_MPHP7.0
        ;;
        2)
        echo "You will install ${PHP_Info[1]}"
        MPHP_Path='/usr/local/php7.1'
        Install_MPHP7.1
        ;;
        3)
        echo "You will install ${PHP_Info[2]}"
        MPHP_Path='/usr/local/php7.2'
        Install_MPHP7.2
        ;;
        4)
        echo "You will install ${PHP_Info[3]}"
        MPHP_Path='/usr/local/php7.3'
        Install_MPHP7.3
        ;;
        5)
        echo "You will install ${PHP_Info[4]}"
        MPHP_Path='/usr/local/php7.4'
        Install_MPHP7.4
        ;;
        6)
        echo "You will install ${PHP_Info[5]}"
        MPHP_Path='/usr/local/php8.0'
        Install_MPHP8.0
        ;;
        7)
        echo "You will install ${PHP_Info[6]}"
        MPHP_Path='/usr/local/php8.1'
        Install_MPHP8.1
        ;;
        8)
        echo "You will install ${PHP_Info[7]}"
        MPHP_Path='/usr/local/php8.2'
        Install_MPHP8.2
        ;;
        9)
        echo "You will install ${PHP_Info[8]}"
        MPHP_Path='/usr/local/php8.3'
        Install_MPHP8.3
        ;;
        10)
        echo "You will install ${PHP_Info[9]}"
        MPHP_Path='/usr/local/php8.4'
        Install_MPHP8.4
        ;;
        *)
        Echo_Red "Input error! Please only input 1,2,3,4,5,6,7,8,9,10"
        exit 1
        ;;
    esac
}

Install_MPHP7.0()
{
    lnmp stop

    cd ${cur_dir}/src
    Download_Files ${Download_Mirror}/web/php/${Php_Ver}.tar.bz2 ${Php_Ver}.tar.bz2
    Echo_Blue "[+] Installing ${Php_Ver}"
    Tar_Cd ${Php_Ver}.tar.bz2 ${Php_Ver}
    if command -v pkg-config >/dev/null 2>&1 && pkg-config --modversion icu-i18n | grep -Eqi '^6[1-9]|[7-9][0-9]'; then
        patch -p1 < ${cur_dir}/src/patch/php-7.0-intl.patch
    fi
    ./configure --prefix=${MPHP_Path} --with-config-file-path=${MPHP_Path}/etc --with-config-file-scan-dir=${MPHP_Path}/conf.d --enable-fpm --with-fpm-user=www --with-fpm-group=www --enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-iconv-dir --with-freetype-dir=/usr/local/freetype --with-jpeg-dir --with-png-dir --with-zlib --with-libxml-dir=/usr --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --with-mcrypt --enable-ftp --with-gd --enable-gd-native-ttf ${with_openssl} --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-zip --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --with-xsl ${PHP_Buildin_Option} ${PHP_Modules_Options}

    PHP_Make_Install

    echo "Copy new php configure file..."
    mkdir -p ${MPHP_Path}/{etc,conf.d}
    \cp php.ini-production ${MPHP_Path}/etc/php.ini

    # php extensions
    echo "Modify php.ini......"
    sed -i 's/post_max_size =.*/post_max_size = 50M/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/upload_max_filesize =.*/upload_max_filesize = 50M/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/;date.timezone =.*/date.timezone = PRC/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/short_open_tag =.*/short_open_tag = On/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/;cgi.fix_pathinfo=.*/cgi.fix_pathinfo=0/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/max_execution_time =.*/max_execution_time = 300/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/disable_functions =.*/disable_functions = passthru,exec,system,chroot,chgrp,chown,shell_exec,proc_open,proc_get_status,popen,ini_alter,ini_restore,dl,openlog,syslog,readlink,symlink,popepassthru,stream_socket_server/g' ${MPHP_Path}/etc/php.ini

    cd ${cur_dir}/src
    echo "Install ZendGuardLoader for PHP 7..."
    echo "unavailable now."

    echo "Creating new php-fpm configure file..."
    cat >${MPHP_Path}/etc/php-fpm.conf<<EOF
[global]
pid = ${MPHP_Path}/var/run/php-fpm.pid
error_log = ${MPHP_Path}/var/log/php-fpm.log
log_level = notice

[www]
listen = /tmp/php-cgi7.0.sock
listen.backlog = -1
listen.allowed_clients = 127.0.0.1
listen.owner = www
listen.group = www
listen.mode = 0666
user = www
group = www
pm = dynamic
pm.max_children = 10
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 6
request_terminate_timeout = 100
request_slowlog_timeout = 0
slowlog = var/log/slow.log
EOF

    echo "Copy php-fpm init.d file..."
    \cp ${cur_dir}/src/${Php_Ver}/sapi/fpm/init.d.php-fpm /etc/init.d/php-fpm7.0
    chmod +x /etc/init.d/php-fpm7.0
    sed -i 's@# Provides:          php-fpm@# Provides:          php-fpm7.0@g' /etc/init.d/php-fpm7.0

    StartUp php-fpm7.0

    \cp ${cur_dir}/conf/enable-php7.0.conf /usr/local/nginx/conf/enable-php7.0.conf

    sleep 2

    lnmp start

    rm -rf ${cur_dir}/src/${Php_Ver}

    if [ -s ${MPHP_Path}/sbin/php-fpm ] && [ -s ${MPHP_Path}/etc/php.ini ] && [ -s ${MPHP_Path}/bin/php ]; then
        echo "==========================================="
        Echo_Green "You have successfully install ${Php_Ver} "
        echo "==========================================="
    else
        rm -rf ${MPHP_Path}
        Echo_Red "Failed to install ${Php_Ver}, you can download /root/install-mphp7.0.log from your server, and upload install-mphp7.0.log to LNMP Forum."
    fi
}

Install_MPHP7.1()
{
    lnmp stop

    cd ${cur_dir}/src
    Download_Files ${Download_Mirror}/web/php/${Php_Ver}.tar.bz2 ${Php_Ver}.tar.bz2
    Echo_Blue "[+] Installing ${Php_Ver}"
    Tar_Cd ${Php_Ver}.tar.bz2 ${Php_Ver}
    PHP_Openssl3_Patch
    PHP_ICU70_Patch
    ./configure --prefix=${MPHP_Path} --with-config-file-path=${MPHP_Path}/etc --with-config-file-scan-dir=${MPHP_Path}/conf.d --enable-fpm --with-fpm-user=www --with-fpm-group=www --enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-iconv-dir --with-freetype-dir=/usr/local/freetype --with-jpeg-dir --with-png-dir --with-zlib --with-libxml-dir=/usr --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --with-mcrypt --enable-ftp --with-gd --enable-gd-native-ttf ${with_openssl} --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-zip --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --with-xsl ${PHP_Buildin_Option} ${PHP_Modules_Options}

    PHP_Make_Install

    echo "Copy new php configure file..."
    mkdir -p ${MPHP_Path}/{etc,conf.d}
    \cp php.ini-production ${MPHP_Path}/etc/php.ini

    # php extensions
    echo "Modify php.ini......"
    sed -i 's/post_max_size =.*/post_max_size = 50M/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/upload_max_filesize =.*/upload_max_filesize = 50M/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/;date.timezone =.*/date.timezone = PRC/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/short_open_tag =.*/short_open_tag = On/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/;cgi.fix_pathinfo=.*/cgi.fix_pathinfo=0/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/max_execution_time =.*/max_execution_time = 300/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/disable_functions =.*/disable_functions = passthru,exec,system,chroot,chgrp,chown,shell_exec,proc_open,proc_get_status,popen,ini_alter,ini_restore,dl,openlog,syslog,readlink,symlink,popepassthru,stream_socket_server/g' ${MPHP_Path}/etc/php.ini

    cd ${cur_dir}/src
    echo "Install ZendGuardLoader for PHP 7.1..."
    echo "unavailable now."

    echo "Creating new php-fpm configure file..."
    cat >${MPHP_Path}/etc/php-fpm.conf<<EOF
[global]
pid = ${MPHP_Path}/var/run/php-fpm.pid
error_log = ${MPHP_Path}/var/log/php-fpm.log
log_level = notice

[www]
listen = /tmp/php-cgi7.1.sock
listen.backlog = -1
listen.allowed_clients = 127.0.0.1
listen.owner = www
listen.group = www
listen.mode = 0666
user = www
group = www
pm = dynamic
pm.max_children = 10
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 6
request_terminate_timeout = 100
request_slowlog_timeout = 0
slowlog = var/log/slow.log
EOF

    echo "Copy php-fpm init.d file..."
    \cp ${cur_dir}/src/${Php_Ver}/sapi/fpm/init.d.php-fpm /etc/init.d/php-fpm7.1
    chmod +x /etc/init.d/php-fpm7.1
    sed -i 's@# Provides:          php-fpm@# Provides:          php-fpm7.1@g' /etc/init.d/php-fpm7.1

    StartUp php-fpm7.1

    \cp ${cur_dir}/conf/enable-php7.1.conf /usr/local/nginx/conf/enable-php7.1.conf

    sleep 2

    lnmp start

    rm -rf ${cur_dir}/src/${Php_Ver}

    if [ -s ${MPHP_Path}/sbin/php-fpm ] && [ -s ${MPHP_Path}/etc/php.ini ] && [ -s ${MPHP_Path}/bin/php ]; then
        echo "==========================================="
        Echo_Green "You have successfully install ${Php_Ver} "
        echo "==========================================="
    else
        rm -rf ${MPHP_Path}
        Echo_Red "Failed to install ${Php_Ver}, you can download /root/install-mphp7.1.log from your server, and upload install-mphp7.1.log to LNMP Forum."
    fi
}

Install_MPHP7.2()
{
    lnmp stop

    cd ${cur_dir}/src
    Download_Files ${Download_Mirror}/web/php/${Php_Ver}.tar.bz2 ${Php_Ver}.tar.bz2
    Echo_Blue "[+] Installing ${Php_Ver}"
    Tar_Cd ${Php_Ver}.tar.bz2 ${Php_Ver}
    PHP_Openssl3_Patch
    PHP_ICU70_Patch
    ./configure --prefix=${MPHP_Path} --with-config-file-path=${MPHP_Path}/etc --with-config-file-scan-dir=${MPHP_Path}/conf.d --enable-fpm --with-fpm-user=www --with-fpm-group=www --enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-iconv-dir --with-freetype-dir=/usr/local/freetype --with-jpeg-dir --with-png-dir --with-zlib --with-libxml-dir=/usr --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --with-gd ${with_openssl} --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-zip --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --with-xsl ${PHP_Buildin_Option} ${PHP_Modules_Options}

    PHP_Make_Install

    echo "Copy new php configure file..."
    mkdir -p ${MPHP_Path}/{etc,conf.d}
    \cp php.ini-production ${MPHP_Path}/etc/php.ini

    # php extensions
    echo "Modify php.ini......"
    sed -i 's/post_max_size =.*/post_max_size = 50M/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/upload_max_filesize =.*/upload_max_filesize = 50M/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/;date.timezone =.*/date.timezone = PRC/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/short_open_tag =.*/short_open_tag = On/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/;cgi.fix_pathinfo=.*/cgi.fix_pathinfo=0/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/max_execution_time =.*/max_execution_time = 300/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/disable_functions =.*/disable_functions = passthru,exec,system,chroot,chgrp,chown,shell_exec,proc_open,proc_get_status,popen,ini_alter,ini_restore,dl,openlog,syslog,readlink,symlink,popepassthru,stream_socket_server/g' ${MPHP_Path}/etc/php.ini

    cd ${cur_dir}/src
    echo "Install ZendGuardLoader for PHP 7.2..."
    echo "unavailable now."

    echo "Creating new php-fpm configure file..."
    cat >${MPHP_Path}/etc/php-fpm.conf<<EOF
[global]
pid = ${MPHP_Path}/var/run/php-fpm.pid
error_log = ${MPHP_Path}/var/log/php-fpm.log
log_level = notice

[www]
listen = /tmp/php-cgi7.2.sock
listen.backlog = -1
listen.allowed_clients = 127.0.0.1
listen.owner = www
listen.group = www
listen.mode = 0666
user = www
group = www
pm = dynamic
pm.max_children = 10
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 6
request_terminate_timeout = 100
request_slowlog_timeout = 0
slowlog = var/log/slow.log
EOF

    echo "Copy php-fpm init.d file..."
    \cp ${cur_dir}/src/${Php_Ver}/sapi/fpm/init.d.php-fpm /etc/init.d/php-fpm7.2
    chmod +x /etc/init.d/php-fpm7.2
    sed -i 's@# Provides:          php-fpm@# Provides:          php-fpm7.2@g' /etc/init.d/php-fpm7.2

    StartUp php-fpm7.2

    \cp ${cur_dir}/conf/enable-php7.2.conf /usr/local/nginx/conf/enable-php7.2.conf

    sleep 2

    lnmp start

    rm -rf ${cur_dir}/src/${Php_Ver}

    if [ -s ${MPHP_Path}/sbin/php-fpm ] && [ -s ${MPHP_Path}/etc/php.ini ] && [ -s ${MPHP_Path}/bin/php ]; then
        echo "==========================================="
        Echo_Green "You have successfully install ${Php_Ver} "
        echo "==========================================="
    else
        rm -rf ${MPHP_Path}
        Echo_Red "Failed to install ${Php_Ver}, you can download /root/install-mphp7.2.log from your server, and upload install-mphp7.2.log to LNMP Forum."
    fi
}

Install_MPHP7.3()
{
    lnmp stop

    cd ${cur_dir}/src
    Download_Files ${Download_Mirror}/web/php/${Php_Ver}.tar.bz2 ${Php_Ver}.tar.bz2
    Echo_Blue "[+] Installing ${Php_Ver}"
    Tar_Cd ${Php_Ver}.tar.bz2 ${Php_Ver}
    PHP_Openssl3_Patch
    PHP_ICU70_Patch
    ./configure --prefix=${MPHP_Path} --with-config-file-path=${MPHP_Path}/etc --with-config-file-scan-dir=${MPHP_Path}/conf.d --enable-fpm --with-fpm-user=www --with-fpm-group=www --enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-iconv-dir --with-freetype-dir=/usr/local/freetype --with-jpeg-dir --with-png-dir --with-zlib --with-libxml-dir=/usr --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --with-gd ${with_openssl} --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-zip --without-libzip --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --with-xsl ${PHP_Buildin_Option} ${PHP_Modules_Options}

    PHP_Make_Install

    echo "Copy new php configure file..."
    mkdir -p ${MPHP_Path}/{etc,conf.d}
    \cp php.ini-production ${MPHP_Path}/etc/php.ini

    # php extensions
    echo "Modify php.ini......"
    sed -i 's/post_max_size =.*/post_max_size = 50M/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/upload_max_filesize =.*/upload_max_filesize = 50M/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/;date.timezone =.*/date.timezone = PRC/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/short_open_tag =.*/short_open_tag = On/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/;cgi.fix_pathinfo=.*/cgi.fix_pathinfo=0/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/max_execution_time =.*/max_execution_time = 300/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/disable_functions =.*/disable_functions = passthru,exec,system,chroot,chgrp,chown,shell_exec,proc_open,proc_get_status,popen,ini_alter,ini_restore,dl,openlog,syslog,readlink,symlink,popepassthru,stream_socket_server/g' ${MPHP_Path}/etc/php.ini

    cd ${cur_dir}/src
    echo "Install ZendGuardLoader for PHP 7.3..."
    echo "unavailable now."

    echo "Creating new php-fpm configure file..."
    cat >${MPHP_Path}/etc/php-fpm.conf<<EOF
[global]
pid = ${MPHP_Path}/var/run/php-fpm.pid
error_log = ${MPHP_Path}/var/log/php-fpm.log
log_level = notice

[www]
listen = /tmp/php-cgi7.3.sock
listen.backlog = -1
listen.allowed_clients = 127.0.0.1
listen.owner = www
listen.group = www
listen.mode = 0666
user = www
group = www
pm = dynamic
pm.max_children = 10
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 6
request_terminate_timeout = 100
request_slowlog_timeout = 0
slowlog = var/log/slow.log
EOF

    echo "Copy php-fpm init.d file..."
    \cp ${cur_dir}/src/${Php_Ver}/sapi/fpm/init.d.php-fpm /etc/init.d/php-fpm7.3
    chmod +x /etc/init.d/php-fpm7.3
    sed -i 's@# Provides:          php-fpm@# Provides:          php-fpm7.3@g' /etc/init.d/php-fpm7.3

    StartUp php-fpm7.3

    \cp ${cur_dir}/conf/enable-php7.3.conf /usr/local/nginx/conf/enable-php7.3.conf

    sleep 2

    lnmp start

    rm -rf ${cur_dir}/src/${Php_Ver}

    if [ -s ${MPHP_Path}/sbin/php-fpm ] && [ -s ${MPHP_Path}/etc/php.ini ] && [ -s ${MPHP_Path}/bin/php ]; then
        echo "==========================================="
        Echo_Green "You have successfully install ${Php_Ver} "
        echo "==========================================="
    else
        rm -rf ${MPHP_Path}
        Echo_Red "Failed to install ${Php_Ver}, you can download /root/install-mphp7.3.log from your server, and upload install-mphp7.3.log to LNMP Forum."
    fi
}

Install_MPHP7.4()
{
    lnmp stop

    cd ${cur_dir}/src
    Download_Files ${Download_Mirror}/web/php/${Php_Ver}.tar.bz2 ${Php_Ver}.tar.bz2
    Install_Libzip
    Echo_Blue "[+] Installing ${Php_Ver}"
    Tar_Cd ${Php_Ver}.tar.bz2 ${Php_Ver}
    PHP_Openssl3_Patch
    ./configure --prefix=${MPHP_Path} --with-config-file-path=${MPHP_Path}/etc --with-config-file-scan-dir=${MPHP_Path}/conf.d --enable-fpm --with-fpm-user=www --with-fpm-group=www --enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-iconv-dir --with-freetype=/usr/local/freetype --with-jpeg --with-png --with-zlib --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --enable-gd ${with_openssl} --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --with-zip --without-libzip --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --with-xsl --with-pear --with-webp ${PHP_Buildin_Option} ${PHP_Modules_Options}

    PHP_Make_Install

    echo "Copy new php configure file..."
    mkdir -p ${MPHP_Path}/{etc,conf.d}
    \cp php.ini-production ${MPHP_Path}/etc/php.ini

    # php extensions
    echo "Modify php.ini......"
    sed -i 's/post_max_size =.*/post_max_size = 50M/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/upload_max_filesize =.*/upload_max_filesize = 50M/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/;date.timezone =.*/date.timezone = PRC/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/short_open_tag =.*/short_open_tag = On/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/;cgi.fix_pathinfo=.*/cgi.fix_pathinfo=0/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/max_execution_time =.*/max_execution_time = 300/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/disable_functions =.*/disable_functions = passthru,exec,system,chroot,chgrp,chown,shell_exec,proc_open,proc_get_status,popen,ini_alter,ini_restore,dl,openlog,syslog,readlink,symlink,popepassthru,stream_socket_server/g' ${MPHP_Path}/etc/php.ini

    cd ${cur_dir}/src
    echo "Install ZendGuardLoader for PHP 7.4..."
    echo "unavailable now."

    echo "Creating new php-fpm configure file..."
    cat >${MPHP_Path}/etc/php-fpm.conf<<EOF
[global]
pid = ${MPHP_Path}/var/run/php-fpm.pid
error_log = ${MPHP_Path}/var/log/php-fpm.log
log_level = notice

[www]
listen = /tmp/php-cgi7.4.sock
listen.backlog = -1
listen.allowed_clients = 127.0.0.1
listen.owner = www
listen.group = www
listen.mode = 0666
user = www
group = www
pm = dynamic
pm.max_children = 10
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 6
request_terminate_timeout = 100
request_slowlog_timeout = 0
slowlog = var/log/slow.log
EOF

    echo "Copy php-fpm init.d file..."
    \cp ${cur_dir}/src/${Php_Ver}/sapi/fpm/init.d.php-fpm /etc/init.d/php-fpm7.4
    chmod +x /etc/init.d/php-fpm7.4
    sed -i 's@# Provides:          php-fpm@# Provides:          php-fpm7.4@g' /etc/init.d/php-fpm7.4

    StartUp php-fpm7.4

    \cp ${cur_dir}/conf/enable-php7.4.conf /usr/local/nginx/conf/enable-php7.4.conf

    sleep 2

    lnmp start

    rm -rf ${cur_dir}/src/${Php_Ver}

    if [ -s ${MPHP_Path}/sbin/php-fpm ] && [ -s ${MPHP_Path}/etc/php.ini ] && [ -s ${MPHP_Path}/bin/php ]; then
        echo "==========================================="
        Echo_Green "You have successfully install ${Php_Ver} "
        echo "==========================================="
    else
        rm -rf ${MPHP_Path}
        Echo_Red "Failed to install ${Php_Ver}, you can download /root/install-mphp7.4.log from your server, and upload install-mphp7.4.log to LNMP Forum."
    fi
}

Install_MPHP8.0()
{
    lnmp stop

    cd ${cur_dir}/src
    Download_Files ${Download_Mirror}/web/php/${Php_Ver}.tar.bz2 ${Php_Ver}.tar.bz2
    Install_Libzip
    Echo_Blue "[+] Installing ${Php_Ver}"
    Tar_Cd ${Php_Ver}.tar.bz2 ${Php_Ver}
    PHP_Openssl3_Patch
    ./configure --prefix=${MPHP_Path} --with-config-file-path=${MPHP_Path}/etc --with-config-file-scan-dir=${MPHP_Path}/conf.d --enable-fpm --with-fpm-user=www --with-fpm-group=www --enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-iconv=/usr/local --with-freetype=/usr/local/freetype --with-jpeg --with-zlib --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --enable-gd ${with_openssl} --with-mhash --enable-pcntl --enable-sockets --with-zip --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --with-xsl --with-pear --with-webp ${PHP_Buildin_Option} ${PHP_Modules_Options}

    PHP_Make_Install

    echo "Copy new php configure file..."
    mkdir -p ${MPHP_Path}/{etc,conf.d}
    \cp php.ini-production ${MPHP_Path}/etc/php.ini

    # php extensions
    echo "Modify php.ini......"
    sed -i 's/post_max_size =.*/post_max_size = 50M/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/upload_max_filesize =.*/upload_max_filesize = 50M/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/;date.timezone =.*/date.timezone = PRC/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/short_open_tag =.*/short_open_tag = On/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/;cgi.fix_pathinfo=.*/cgi.fix_pathinfo=0/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/max_execution_time =.*/max_execution_time = 300/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/disable_functions =.*/disable_functions = passthru,exec,system,chroot,chgrp,chown,shell_exec,proc_open,proc_get_status,popen,ini_alter,ini_restore,dl,openlog,syslog,readlink,symlink,popepassthru,stream_socket_server/g' ${MPHP_Path}/etc/php.ini

    cd ${cur_dir}/src
    echo "Install ZendGuardLoader for PHP 8.0..."
    echo "unavailable now."

    echo "Creating new php-fpm configure file..."
    cat >${MPHP_Path}/etc/php-fpm.conf<<EOF
[global]
pid = ${MPHP_Path}/var/run/php-fpm.pid
error_log = ${MPHP_Path}/var/log/php-fpm.log
log_level = notice

[www]
listen = /tmp/php-cgi8.0.sock
listen.backlog = -1
listen.allowed_clients = 127.0.0.1
listen.owner = www
listen.group = www
listen.mode = 0666
user = www
group = www
pm = dynamic
pm.max_children = 10
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 6
request_terminate_timeout = 100
request_slowlog_timeout = 0
slowlog = var/log/slow.log
EOF

    echo "Copy php-fpm init.d file..."
    \cp ${cur_dir}/src/${Php_Ver}/sapi/fpm/init.d.php-fpm /etc/init.d/php-fpm8.0
    chmod +x /etc/init.d/php-fpm8.0
    sed -i 's@# Provides:          php-fpm@# Provides:          php-fpm8.0@g' /etc/init.d/php-fpm8.0

    StartUp php-fpm8.0

    \cp ${cur_dir}/conf/enable-php8.0.conf /usr/local/nginx/conf/enable-php8.0.conf

    sleep 2

    lnmp start

    rm -rf ${cur_dir}/src/${Php_Ver}

    if [ -s ${MPHP_Path}/sbin/php-fpm ] && [ -s ${MPHP_Path}/etc/php.ini ] && [ -s ${MPHP_Path}/bin/php ]; then
        echo "==========================================="
        Echo_Green "You have successfully install ${Php_Ver} "
        echo "==========================================="
    else
        rm -rf ${MPHP_Path}
        Echo_Red "Failed to install ${Php_Ver}, you can download /root/install-mphp8.0.log from your server, and upload install-mphp8.0.log to LNMP Forum."
    fi
}

Install_MPHP8.1()
{
    lnmp stop

    cd ${cur_dir}/src
    Download_Files ${Download_Mirror}/web/php/${Php_Ver}.tar.bz2 ${Php_Ver}.tar.bz2
    Install_Libzip
    Echo_Blue "[+] Installing ${Php_Ver}"
    Tar_Cd ${Php_Ver}.tar.bz2 ${Php_Ver}
    ./configure --prefix=${MPHP_Path} --with-config-file-path=${MPHP_Path}/etc --with-config-file-scan-dir=${MPHP_Path}/conf.d --enable-fpm --with-fpm-user=www --with-fpm-group=www --enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-iconv=/usr/local --with-freetype=/usr/local/freetype --with-jpeg --with-zlib --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --enable-gd ${with_openssl} --with-mhash --enable-pcntl --enable-sockets --with-zip --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --with-xsl --with-pear --with-webp ${PHP_Buildin_Option} ${PHP_Modules_Options}

    PHP_Make_Install

    echo "Copy new php configure file..."
    mkdir -p ${MPHP_Path}/{etc,conf.d}
    \cp php.ini-production ${MPHP_Path}/etc/php.ini

    # php extensions
    echo "Modify php.ini......"
    sed -i 's/post_max_size =.*/post_max_size = 50M/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/upload_max_filesize =.*/upload_max_filesize = 50M/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/;date.timezone =.*/date.timezone = PRC/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/short_open_tag =.*/short_open_tag = On/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/;cgi.fix_pathinfo=.*/cgi.fix_pathinfo=0/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/max_execution_time =.*/max_execution_time = 300/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/disable_functions =.*/disable_functions = passthru,exec,system,chroot,chgrp,chown,shell_exec,proc_open,proc_get_status,popen,ini_alter,ini_restore,dl,openlog,syslog,readlink,symlink,popepassthru,stream_socket_server/g' ${MPHP_Path}/etc/php.ini

    cd ${cur_dir}/src
    echo "Install ZendGuardLoader for PHP 8.1..."
    echo "unavailable now."

    echo "Creating new php-fpm configure file..."
    cat >${MPHP_Path}/etc/php-fpm.conf<<EOF
[global]
pid = ${MPHP_Path}/var/run/php-fpm.pid
error_log = ${MPHP_Path}/var/log/php-fpm.log
log_level = notice

[www]
listen = /tmp/php-cgi8.1.sock
listen.backlog = -1
listen.allowed_clients = 127.0.0.1
listen.owner = www
listen.group = www
listen.mode = 0666
user = www
group = www
pm = dynamic
pm.max_children = 10
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 6
request_terminate_timeout = 100
request_slowlog_timeout = 0
slowlog = var/log/slow.log
EOF

    echo "Copy php-fpm init.d file..."
    \cp ${cur_dir}/src/${Php_Ver}/sapi/fpm/init.d.php-fpm /etc/init.d/php-fpm8.1
    chmod +x /etc/init.d/php-fpm8.1
    sed -i 's@# Provides:          php-fpm@# Provides:          php-fpm8.1@g' /etc/init.d/php-fpm8.1

    StartUp php-fpm8.1

    \cp ${cur_dir}/conf/enable-php8.1.conf /usr/local/nginx/conf/enable-php8.1.conf

    sleep 2

    lnmp start

    rm -rf ${cur_dir}/src/${Php_Ver}

    if [ -s ${MPHP_Path}/sbin/php-fpm ] && [ -s ${MPHP_Path}/etc/php.ini ] && [ -s ${MPHP_Path}/bin/php ]; then
        echo "==========================================="
        Echo_Green "You have successfully install ${Php_Ver} "
        echo "==========================================="
    else
        rm -rf ${MPHP_Path}
        Echo_Red "Failed to install ${Php_Ver}, you can download /root/install-mphp8.1.log from your server, and upload install-mphp8.1.log to LNMP Forum."
    fi
}

Install_MPHP8.2()
{
    lnmp stop

    cd ${cur_dir}/src
    Download_Files ${Download_Mirror}/web/php/${Php_Ver}.tar.bz2 ${Php_Ver}.tar.bz2
    Install_Libzip
    Echo_Blue "[+] Installing ${Php_Ver}"
    Tar_Cd ${Php_Ver}.tar.bz2 ${Php_Ver}
    ./configure --prefix=${MPHP_Path} --with-config-file-path=${MPHP_Path}/etc --with-config-file-scan-dir=${MPHP_Path}/conf.d --enable-fpm --with-fpm-user=www --with-fpm-group=www --enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-iconv=/usr/local --with-freetype=/usr/local/freetype --with-jpeg --with-zlib --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --enable-gd ${with_openssl} --enable-pcntl --enable-sockets --with-zip --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --with-xsl --with-pear --with-webp ${PHP_Buildin_Option} ${PHP_Modules_Options}

    PHP_Make_Install

    echo "Copy new php configure file..."
    mkdir -p ${MPHP_Path}/{etc,conf.d}
    \cp php.ini-production ${MPHP_Path}/etc/php.ini

    # php extensions
    echo "Modify php.ini......"
    sed -i 's/post_max_size =.*/post_max_size = 50M/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/upload_max_filesize =.*/upload_max_filesize = 50M/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/;date.timezone =.*/date.timezone = PRC/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/short_open_tag =.*/short_open_tag = On/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/;cgi.fix_pathinfo=.*/cgi.fix_pathinfo=0/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/max_execution_time =.*/max_execution_time = 300/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/disable_functions =.*/disable_functions = passthru,exec,system,chroot,chgrp,chown,shell_exec,proc_open,proc_get_status,popen,ini_alter,ini_restore,dl,openlog,syslog,readlink,symlink,popepassthru,stream_socket_server/g' ${MPHP_Path}/etc/php.ini

    cd ${cur_dir}/src
    echo "Install ZendGuardLoader for PHP 8.2..."
    echo "unavailable now."

    echo "Creating new php-fpm configure file..."
    cat >${MPHP_Path}/etc/php-fpm.conf<<EOF
[global]
pid = ${MPHP_Path}/var/run/php-fpm.pid
error_log = ${MPHP_Path}/var/log/php-fpm.log
log_level = notice

[www]
listen = /tmp/php-cgi8.2.sock
listen.backlog = -1
listen.allowed_clients = 127.0.0.1
listen.owner = www
listen.group = www
listen.mode = 0666
user = www
group = www
pm = dynamic
pm.max_children = 10
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 6
request_terminate_timeout = 100
request_slowlog_timeout = 0
slowlog = var/log/slow.log
EOF

    echo "Copy php-fpm init.d file..."
    \cp ${cur_dir}/src/${Php_Ver}/sapi/fpm/init.d.php-fpm /etc/init.d/php-fpm8.2
    chmod +x /etc/init.d/php-fpm8.2
    sed -i 's@# Provides:          php-fpm@# Provides:          php-fpm8.2@g' /etc/init.d/php-fpm8.2

    StartUp php-fpm8.2

    \cp ${cur_dir}/conf/enable-php8.2.conf /usr/local/nginx/conf/enable-php8.2.conf

    sleep 2

    lnmp start

    rm -rf ${cur_dir}/src/${Php_Ver}

    if [ -s ${MPHP_Path}/sbin/php-fpm ] && [ -s ${MPHP_Path}/etc/php.ini ] && [ -s ${MPHP_Path}/bin/php ]; then
        echo "==========================================="
        Echo_Green "You have successfully install ${Php_Ver} "
        echo "==========================================="
    else
        rm -rf ${MPHP_Path}
        Echo_Red "Failed to install ${Php_Ver}, you can download /root/install-mphp8.2.log from your server, and upload install-mphp8.2.log to LNMP Forum."
    fi
}

Install_MPHP8.3()
{
    lnmp stop

    cd ${cur_dir}/src
    Download_Files ${Download_Mirror}/web/php/${Php_Ver}.tar.bz2 ${Php_Ver}.tar.bz2
    Install_Libzip
    Echo_Blue "[+] Installing ${Php_Ver}"
    Tar_Cd ${Php_Ver}.tar.bz2 ${Php_Ver}
    ./configure --prefix=${MPHP_Path} --with-config-file-path=${MPHP_Path}/etc --with-config-file-scan-dir=${MPHP_Path}/conf.d --enable-fpm --with-fpm-user=www --with-fpm-group=www --enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-iconv=/usr/local --with-freetype=/usr/local/freetype --with-jpeg --with-zlib --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --enable-gd ${with_openssl} --enable-pcntl --enable-sockets --with-zip --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --with-xsl --with-pear --with-webp ${PHP_Buildin_Option} ${PHP_Modules_Options}

    PHP_Make_Install

    echo "Copy new php configure file..."
    mkdir -p ${MPHP_Path}/{etc,conf.d}
    \cp php.ini-production ${MPHP_Path}/etc/php.ini

    # php extensions
    echo "Modify php.ini......"
    sed -i 's/post_max_size =.*/post_max_size = 50M/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/upload_max_filesize =.*/upload_max_filesize = 50M/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/;date.timezone =.*/date.timezone = PRC/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/short_open_tag =.*/short_open_tag = On/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/;cgi.fix_pathinfo=.*/cgi.fix_pathinfo=0/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/max_execution_time =.*/max_execution_time = 300/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/disable_functions =.*/disable_functions = passthru,exec,system,chroot,chgrp,chown,shell_exec,proc_open,proc_get_status,popen,ini_alter,ini_restore,dl,openlog,syslog,readlink,symlink,popepassthru,stream_socket_server/g' ${MPHP_Path}/etc/php.ini

    cd ${cur_dir}/src
    echo "Install ZendGuardLoader for PHP 8.3..."
    echo "unavailable now."

    echo "Creating new php-fpm configure file..."
    cat >${MPHP_Path}/etc/php-fpm.conf<<EOF
[global]
pid = ${MPHP_Path}/var/run/php-fpm.pid
error_log = ${MPHP_Path}/var/log/php-fpm.log
log_level = notice

[www]
listen = /tmp/php-cgi8.3.sock
listen.backlog = -1
listen.allowed_clients = 127.0.0.1
listen.owner = www
listen.group = www
listen.mode = 0666
user = www
group = www
pm = dynamic
pm.max_children = 10
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 6
request_terminate_timeout = 100
request_slowlog_timeout = 0
slowlog = var/log/slow.log
EOF

    echo "Copy php-fpm init.d file..."
    \cp ${cur_dir}/src/${Php_Ver}/sapi/fpm/init.d.php-fpm /etc/init.d/php-fpm8.3
    chmod +x /etc/init.d/php-fpm8.3
    sed -i 's@# Provides:          php-fpm@# Provides:          php-fpm8.3@g' /etc/init.d/php-fpm8.3

    StartUp php-fpm8.3

    \cp ${cur_dir}/conf/enable-php8.3.conf /usr/local/nginx/conf/enable-php8.3.conf

    sleep 2

    lnmp start

    rm -rf ${cur_dir}/src/${Php_Ver}

    if [ -s ${MPHP_Path}/sbin/php-fpm ] && [ -s ${MPHP_Path}/etc/php.ini ] && [ -s ${MPHP_Path}/bin/php ]; then
        echo "==========================================="
        Echo_Green "You have successfully install ${Php_Ver} "
        echo "==========================================="
    else
        rm -rf ${MPHP_Path}
        Echo_Red "Failed to install ${Php_Ver}, you can download /root/install-mphp8.3.log from your server, and upload install-mphp8.3.log to LNMP Forum."
    fi
}

Install_MPHP8.4()
{
    lnmp stop

    cd ${cur_dir}/src
    Download_Files ${Download_Mirror}/web/php/${Php_Ver}.tar.bz2 ${Php_Ver}.tar.bz2
    Install_Libzip
    Echo_Blue "[+] Installing ${Php_Ver}"
    Tar_Cd ${Php_Ver}.tar.bz2 ${Php_Ver}
    ./configure --prefix=${MPHP_Path} --with-config-file-path=${MPHP_Path}/etc --with-config-file-scan-dir=${MPHP_Path}/conf.d --enable-fpm --with-fpm-user=www --with-fpm-group=www --enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-iconv=/usr/local --with-freetype=/usr/local/freetype --with-jpeg --with-zlib --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --enable-gd ${with_openssl} --enable-pcntl --enable-sockets --with-zip --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --with-xsl --with-pear --with-webp ${PHP_Buildin_Option} ${PHP_Modules_Options}

    PHP_Make_Install

    echo "Copy new php configure file..."
    mkdir -p ${MPHP_Path}/{etc,conf.d}
    \cp php.ini-production ${MPHP_Path}/etc/php.ini

    # php extensions
    echo "Modify php.ini......"
    sed -i 's/post_max_size =.*/post_max_size = 50M/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/upload_max_filesize =.*/upload_max_filesize = 50M/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/;date.timezone =.*/date.timezone = PRC/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/short_open_tag =.*/short_open_tag = On/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/;cgi.fix_pathinfo=.*/cgi.fix_pathinfo=0/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/max_execution_time =.*/max_execution_time = 300/g' ${MPHP_Path}/etc/php.ini
    sed -i 's/disable_functions =.*/disable_functions = passthru,exec,system,chroot,chgrp,chown,shell_exec,proc_open,proc_get_status,popen,ini_alter,ini_restore,dl,openlog,syslog,readlink,symlink,popepassthru,stream_socket_server/g' ${MPHP_Path}/etc/php.ini

    cd ${cur_dir}/src
    echo "Install ZendGuardLoader for PHP 8.4..."
    echo "unavailable now."

    echo "Creating new php-fpm configure file..."
    cat >${MPHP_Path}/etc/php-fpm.conf<<EOF
[global]
pid = ${MPHP_Path}/var/run/php-fpm.pid
error_log = ${MPHP_Path}/var/log/php-fpm.log
log_level = notice

[www]
listen = /tmp/php-cgi8.4.sock
listen.backlog = -1
listen.allowed_clients = 127.0.0.1
listen.owner = www
listen.group = www
listen.mode = 0666
user = www
group = www
pm = dynamic
pm.max_children = 10
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 6
request_terminate_timeout = 100
request_slowlog_timeout = 0
slowlog = var/log/slow.log
EOF

    echo "Copy php-fpm init.d file..."
    \cp ${cur_dir}/src/${Php_Ver}/sapi/fpm/init.d.php-fpm /etc/init.d/php-fpm8.4
    chmod +x /etc/init.d/php-fpm8.4
    sed -i 's@# Provides:          php-fpm@# Provides:          php-fpm8.4@g' /etc/init.d/php-fpm8.4

    StartUp php-fpm8.4

    \cp ${cur_dir}/conf/enable-php8.4.conf /usr/local/nginx/conf/enable-php8.4.conf

    sleep 2

    lnmp start

    rm -rf ${cur_dir}/src/${Php_Ver}

    if [ -s ${MPHP_Path}/sbin/php-fpm ] && [ -s ${MPHP_Path}/etc/php.ini ] && [ -s ${MPHP_Path}/bin/php ]; then
        echo "==========================================="
        Echo_Green "You have successfully install ${Php_Ver} "
        echo "==========================================="
    else
        rm -rf ${MPHP_Path}
        Echo_Red "Failed to install ${Php_Ver}, you can download /root/install-mphp8.4.log from your server, and upload install-mphp8.4.log to LNMP Forum."
    fi
}