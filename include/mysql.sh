#!/usr/bin/env bash

MySQL_ARM_Patch()
{
    if [ "${Is_ARM}" = "y" ]; then
        patch -p1 < ${cur_dir}/src/patch/mysql-5.5-fix-arm-client_plugin.patch
    fi
}

MySQL_Gcc7_Patch()
{
    if gcc -dumpversion|grep -Eq "^[7-9]|10"; then
        echo "gcc version: 7+"
        if [ "${DBSelect}" = "1" ] || echo "${mysql_version}" | grep -Eqi '^5.1.'; then
            patch -p1 < ${cur_dir}/src/patch/mysql-5.1-mysql-gcc7.patch
        fi
    fi
}

Check_MySQL_Dependencies()
{
    Echo_Blue "[+] Checking MySQL runtime dependencies for Debian 13..."
    if [ "${DISTRO}" = "Debian" ] && echo "${Debian_Version}" | grep -Eqi "^13"; then
        echo "Detected Debian 13 Trixie, checking MySQL dependencies..."
        local libdir
        for libdir in /lib/*-linux-gnu /usr/lib/*-linux-gnu; do
            [ -d "${libdir}" ] || continue
            if [ ! -e "${libdir}/libaio.so.1" ] && [ -f "${libdir}/libaio.so.1t64" ]; then
                echo "Creating libaio compatibility link for MySQL..."
                ln -sf "${libdir}/libaio.so.1t64" "${libdir}/libaio.so.1"
            fi
            if [ ! -e "${libdir}/libncurses.so.5" ] && [ -f "${libdir}/libncurses.so.6" ]; then
                ln -sf "${libdir}/libncurses.so.6" "${libdir}/libncurses.so.5"
            fi
            if [ ! -e "${libdir}/libtinfo.so.5" ] && [ -f "${libdir}/libtinfo.so.6" ]; then
                ln -sf "${libdir}/libtinfo.so.6" "${libdir}/libtinfo.so.5"
            fi
        done
        ldconfig
    fi
}

MySQL_Sec_Setting()
{
    if [ -d "/proc/vz" ]; then
        ulimit -s unlimited
    fi

    if [ -d "/etc/mysql" ]; then
        mv /etc/mysql "/etc/mysql.backup.$(date +%Y%m%d%H%M%S)"
    fi

    # Check and fix MySQL dependencies before starting
    Check_MySQL_Dependencies || return 1

    if command -v systemctl >/dev/null 2>&1; then
        systemctl enable mysql.service || return 1
    fi
    /etc/init.d/mysql start || return 1

    ln -sf /usr/local/mysql/bin/mysql /usr/bin/mysql
    ln -sf /usr/local/mysql/bin/mysqldump /usr/bin/mysqldump
    ln -sf /usr/local/mysql/bin/myisamchk /usr/bin/myisamchk
    ln -sf /usr/local/mysql/bin/mysqld_safe /usr/bin/mysqld_safe
    ln -sf /usr/local/mysql/bin/mysqlcheck /usr/bin/mysqlcheck

    /etc/init.d/mysql restart || return 1
    sleep 2

    if Is_Modern_MySQL_DB || Is_Modern_MySQL_Version; then
        local -a mysql_root_cmd
        local sql_password temporary_password_cnf=""
        sql_password=$(Escape_SQL_String "${DB_Root_Password}")
        if [ -n "${MySQL_Temporary_Password:-}" ]; then
            temporary_password_cnf=$(Make_Temporary_DB_Option_File "${MySQL_Temporary_Password}") || return 1
            mysql_root_cmd=(/usr/local/mysql/bin/mysql "--defaults-file=${temporary_password_cnf}" --connect-expired-password --protocol=socket -u root)
        else
            mysql_root_cmd=(/usr/local/mysql/bin/mysql --protocol=socket -u root)
        fi
        if ! Run_DB_Query "ALTER USER 'root'@'localhost' IDENTIFIED BY '${sql_password}';" "${mysql_root_cmd[@]}"; then
            echo "failed, try other way..."
            if ! /etc/init.d/mysql restart; then
                [ -n "${temporary_password_cnf}" ] && rm -f -- "${temporary_password_cnf}"
                return 1
            fi
            if ! Run_DB_Query "SET PASSWORD FOR 'root'@'localhost' = '${sql_password}';" "${mysql_root_cmd[@]}"; then
                [ -n "${temporary_password_cnf}" ] && rm -f -- "${temporary_password_cnf}"
                return 1
            fi
        fi
        [ -n "${temporary_password_cnf}" ] && rm -f -- "${temporary_password_cnf}"
    elif ! printf '%s\n%s\n' "${DB_Root_Password}" "${DB_Root_Password}" | /usr/local/mysql/bin/mysqladmin -u root password; then
        echo "failed, try other way..."
        /etc/init.d/mysql restart || return 1
        local empty_mysql_cnf
        empty_mysql_cnf=$(Make_Empty_TempMycnf) || return 1
        sql_password=$(Escape_SQL_String "${DB_Root_Password}")
        if [ "${DBSelect}" = "4" ] || echo "${mysql_version}" | grep -Eqi '^5.7.'; then
            Run_DB_Query "SET PASSWORD FOR 'root'@'localhost' = PASSWORD('${sql_password}');" /usr/local/mysql/bin/mysql "--defaults-file=${empty_mysql_cnf}" || {
                rm -f -- "${empty_mysql_cnf}"
                return 1
            }
        elif Is_Modern_MySQL_DB || Is_Modern_MySQL_Version; then
            Run_DB_Query "SET PASSWORD FOR 'root'@'localhost' = '${sql_password}';" /usr/local/mysql/bin/mysql "--defaults-file=${empty_mysql_cnf}" || {
                rm -f -- "${empty_mysql_cnf}"
                return 1
            }
        else
            Run_DB_Query "UPDATE mysql.user SET Password=PASSWORD('${sql_password}') WHERE User='root';" /usr/local/mysql/bin/mysql "--defaults-file=${empty_mysql_cnf}" || {
                rm -f -- "${empty_mysql_cnf}"
                return 1
            }
            Run_DB_Query "FLUSH PRIVILEGES;" /usr/local/mysql/bin/mysql "--defaults-file=${empty_mysql_cnf}" || {
                rm -f -- "${empty_mysql_cnf}"
                return 1
            }
        fi
        rm -f -- "${empty_mysql_cnf}"
    fi
    /etc/init.d/mysql restart || return 1

    Make_TempMycnf "${DB_Root_Password}"
    Do_Query "" || return 1
    echo "OK, MySQL root password correct."
    echo "Update root password..."
    if [ "${DBSelect}" = "4" ] || echo "${mysql_version}" | grep -Eqi '^5.7.'; then
        Do_Query "UPDATE mysql.user SET authentication_string=PASSWORD('$(Escape_SQL_String "${DB_Root_Password}")') WHERE User='root';" || return 1
    elif Is_Modern_MySQL_DB || Is_Modern_MySQL_Version; then
        Do_Query "SET PASSWORD FOR 'root'@'localhost' = '$(Escape_SQL_String "${DB_Root_Password}")';" || return 1
    else
        Do_Query "UPDATE mysql.user SET Password=PASSWORD('$(Escape_SQL_String "${DB_Root_Password}")') WHERE User='root';" || return 1
    fi
    echo " ... Success."
    echo "Remove anonymous users..."
    Do_Query "DELETE FROM mysql.user WHERE User='';" || return 1
    echo " ... Success."
    echo "Disallow root login remotely..."
    Do_Query "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');" || return 1
    echo " ... Success."
    echo "Remove test database..."
    Do_Query "DROP DATABASE IF EXISTS test;" || return 1
    echo " ... Success."
    echo "Reload privilege tables..."
    Do_Query "FLUSH PRIVILEGES;" || return 1
    echo " ... Success."

    /etc/init.d/mysql restart || return 1
    /etc/init.d/mysql stop || return 1
}

Set_MySQL_Redo_Log()
{
    local size="$1"
    if Is_Modern_MySQL_DB || Is_Modern_MySQL_Version; then
        sed -i "s#^innodb_redo_log_capacity.*#innodb_redo_log_capacity = ${size}#" /etc/my.cnf
    else
        sed -i "s#^innodb_log_file_size.*#innodb_log_file_size = ${size}#" /etc/my.cnf
    fi
}

MySQL_Opt()
{
    if [[ ${MemTotal} -gt 1024 && ${MemTotal} -lt 2048 ]]; then
        sed -i "s#^key_buffer_size.*#key_buffer_size = 32M#" /etc/my.cnf
        sed -i "s#^table_open_cache.*#table_open_cache = 128#" /etc/my.cnf
        sed -i "s#^sort_buffer_size.*#sort_buffer_size = 768K#" /etc/my.cnf
        sed -i "s#^read_buffer_size.*#read_buffer_size = 768K#" /etc/my.cnf
        sed -i "s#^myisam_sort_buffer_size.*#myisam_sort_buffer_size = 8M#" /etc/my.cnf
        sed -i "s#^thread_cache_size.*#thread_cache_size = 16#" /etc/my.cnf
        sed -i "s#^query_cache_size.*#query_cache_size = 16M#" /etc/my.cnf
        sed -i "s#^tmp_table_size.*#tmp_table_size = 32M#" /etc/my.cnf
        sed -i "s#^innodb_buffer_pool_size.*#innodb_buffer_pool_size = 128M#" /etc/my.cnf
        Set_MySQL_Redo_Log 32M
        sed -i "s#^performance_schema_max_table_instances.*#performance_schema_max_table_instances = 1000#" /etc/my.cnf
    elif [[ ${MemTotal} -ge 2048 && ${MemTotal} -lt 4096 ]]; then
        sed -i "s#^key_buffer_size.*#key_buffer_size = 64M#" /etc/my.cnf
        sed -i "s#^table_open_cache.*#table_open_cache = 256#" /etc/my.cnf
        sed -i "s#^sort_buffer_size.*#sort_buffer_size = 1M#" /etc/my.cnf
        sed -i "s#^read_buffer_size.*#read_buffer_size = 1M#" /etc/my.cnf
        sed -i "s#^myisam_sort_buffer_size.*#myisam_sort_buffer_size = 16M#" /etc/my.cnf
        sed -i "s#^thread_cache_size.*#thread_cache_size = 32#" /etc/my.cnf
        sed -i "s#^query_cache_size.*#query_cache_size = 32M#" /etc/my.cnf
        sed -i "s#^tmp_table_size.*#tmp_table_size = 64M#" /etc/my.cnf
        sed -i "s#^innodb_buffer_pool_size.*#innodb_buffer_pool_size = 256M#" /etc/my.cnf
        Set_MySQL_Redo_Log 64M
        sed -i "s#^performance_schema_max_table_instances.*#performance_schema_max_table_instances = 2000#" /etc/my.cnf
    elif [[ ${MemTotal} -ge 4096 && ${MemTotal} -lt 8192 ]]; then
        sed -i "s#^key_buffer_size.*#key_buffer_size = 128M#" /etc/my.cnf
        sed -i "s#^table_open_cache.*#table_open_cache = 512#" /etc/my.cnf
        sed -i "s#^sort_buffer_size.*#sort_buffer_size = 2M#" /etc/my.cnf
        sed -i "s#^read_buffer_size.*#read_buffer_size = 2M#" /etc/my.cnf
        sed -i "s#^myisam_sort_buffer_size.*#myisam_sort_buffer_size = 32M#" /etc/my.cnf
        sed -i "s#^thread_cache_size.*#thread_cache_size = 64#" /etc/my.cnf
        sed -i "s#^query_cache_size.*#query_cache_size = 64M#" /etc/my.cnf
        sed -i "s#^tmp_table_size.*#tmp_table_size = 64M#" /etc/my.cnf
        sed -i "s#^innodb_buffer_pool_size.*#innodb_buffer_pool_size = 512M#" /etc/my.cnf
        Set_MySQL_Redo_Log 128M
        sed -i "s#^performance_schema_max_table_instances.*#performance_schema_max_table_instances = 4000#" /etc/my.cnf
    elif [[ ${MemTotal} -ge 8192 && ${MemTotal} -lt 16384 ]]; then
        sed -i "s#^key_buffer_size.*#key_buffer_size = 256M#" /etc/my.cnf
        sed -i "s#^table_open_cache.*#table_open_cache = 1024#" /etc/my.cnf
        sed -i "s#^sort_buffer_size.*#sort_buffer_size = 4M#" /etc/my.cnf
        sed -i "s#^read_buffer_size.*#read_buffer_size = 4M#" /etc/my.cnf
        sed -i "s#^myisam_sort_buffer_size.*#myisam_sort_buffer_size = 64M#" /etc/my.cnf
        sed -i "s#^thread_cache_size.*#thread_cache_size = 128#" /etc/my.cnf
        sed -i "s#^query_cache_size.*#query_cache_size = 128M#" /etc/my.cnf
        sed -i "s#^tmp_table_size.*#tmp_table_size = 128M#" /etc/my.cnf
        sed -i "s#^innodb_buffer_pool_size.*#innodb_buffer_pool_size = 1024M#" /etc/my.cnf
        Set_MySQL_Redo_Log 256M
        sed -i "s#^performance_schema_max_table_instances.*#performance_schema_max_table_instances = 6000#" /etc/my.cnf
    elif [[ ${MemTotal} -ge 16384 && ${MemTotal} -lt 32768 ]]; then
        sed -i "s#^key_buffer_size.*#key_buffer_size = 512M#" /etc/my.cnf
        sed -i "s#^table_open_cache.*#table_open_cache = 2048#" /etc/my.cnf
        sed -i "s#^sort_buffer_size.*#sort_buffer_size = 8M#" /etc/my.cnf
        sed -i "s#^read_buffer_size.*#read_buffer_size = 8M#" /etc/my.cnf
        sed -i "s#^myisam_sort_buffer_size.*#myisam_sort_buffer_size = 128M#" /etc/my.cnf
        sed -i "s#^thread_cache_size.*#thread_cache_size = 256#" /etc/my.cnf
        sed -i "s#^query_cache_size.*#query_cache_size = 256M#" /etc/my.cnf
        sed -i "s#^tmp_table_size.*#tmp_table_size = 256M#" /etc/my.cnf
        sed -i "s#^innodb_buffer_pool_size.*#innodb_buffer_pool_size = 2048M#" /etc/my.cnf
        Set_MySQL_Redo_Log 512M
        sed -i "s#^performance_schema_max_table_instances.*#performance_schema_max_table_instances = 8000#" /etc/my.cnf
    elif [[ ${MemTotal} -ge 32768 ]]; then
        sed -i "s#^key_buffer_size.*#key_buffer_size = 1024M#" /etc/my.cnf
        sed -i "s#^table_open_cache.*#table_open_cache = 4096#" /etc/my.cnf
        sed -i "s#^sort_buffer_size.*#sort_buffer_size = 16M#" /etc/my.cnf
        sed -i "s#^read_buffer_size.*#read_buffer_size = 16M#" /etc/my.cnf
        sed -i "s#^myisam_sort_buffer_size.*#myisam_sort_buffer_size = 256M#" /etc/my.cnf
        sed -i "s#^thread_cache_size.*#thread_cache_size = 512#" /etc/my.cnf
        sed -i "s#^query_cache_size.*#query_cache_size = 512M#" /etc/my.cnf
        sed -i "s#^tmp_table_size.*#tmp_table_size = 512M#" /etc/my.cnf
        sed -i "s#^innodb_buffer_pool_size.*#innodb_buffer_pool_size = 4096M#" /etc/my.cnf
        Set_MySQL_Redo_Log 1024M
        sed -i "s#^performance_schema_max_table_instances.*#performance_schema_max_table_instances = 10000#" /etc/my.cnf
    fi
}

Check_MySQL_Data_Dir()
{
    if [ -d "${MySQL_Data_Dir}" ]; then
        datetime=$(date +"%Y%m%d%H%M%S")
        local backup_dir="/root/mysql-data-dir-backup${datetime}"
        mkdir -p "${backup_dir}"
        find "${MySQL_Data_Dir}" -mindepth 1 -maxdepth 1 -exec cp -a -- {} "${backup_dir}/" \;
        find "${MySQL_Data_Dir}" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
    else
        mkdir -p "${MySQL_Data_Dir}"
    fi
}

Install_MySQL_51()
{
    Echo_Blue "[+] Installing ${Mysql_Ver}..."
    rm -f /etc/my.cnf
    Tar_Cd "${Mysql_Ver}.tar.gz" "${Mysql_Ver}" || return 1
    MySQL_Gcc7_Patch
    if [ "${InstallInnodb}" = "y" ]; then
        ./configure --prefix=/usr/local/mysql --with-extra-charsets=complex --enable-thread-safe-client --enable-assembler --with-mysqld-ldflags=-all-static --with-charset=utf8 --enable-thread-safe-client --with-big-tables --with-readline --with-ssl --with-embedded-server --enable-local-infile --with-plugins=innobase ${MySQL51MAOpt}
    else
        ./configure --prefix=/usr/local/mysql --with-extra-charsets=complex --enable-thread-safe-client --enable-assembler --with-mysqld-ldflags=-all-static --with-charset=utf8 --enable-thread-safe-client --with-big-tables --with-readline --with-ssl --with-embedded-server --enable-local-infile ${MySQL51MAOpt}
    fi
    sed -i '/set -ex;/,/done/d' Makefile
    Make_Install || return 1

    getent group mysql >/dev/null 2>&1 || groupadd mysql || return 1
    id mysql >/dev/null 2>&1 || useradd -s /sbin/nologin -M -g mysql mysql || return 1

    cat > /etc/my.cnf<<EOF
[client]
#password	= your_password
port		= 3306
socket		= /tmp/mysql.sock

[mysqld]
port		= 3306
socket		= /tmp/mysql.sock
datadir = ${MySQL_Data_Dir}
skip-external-locking
key_buffer_size = 16M
max_allowed_packet = 1M
table_open_cache = 64
sort_buffer_size = 512K
net_buffer_length = 8K
read_buffer_size = 256K
read_rnd_buffer_size = 512K
myisam_sort_buffer_size = 8M
thread_cache_size = 8
query_cache_size = 8M
tmp_table_size = 16M

#skip-networking
max_connections = 500
max_connect_errors = 100
open_files_limit = 65535

log-bin=mysql-bin
binlog_format=mixed
server-id	= 1
expire_logs_days = 10

default_storage_engine = InnoDB
#innodb_file_per_table = 1
#innodb_data_home_dir = ${MySQL_Data_Dir}
#innodb_data_file_path = ibdata1:10M:autoextend
#innodb_log_group_home_dir = ${MySQL_Data_Dir}
#innodb_buffer_pool_size = 16M
#innodb_additional_mem_pool_size = 2M
#innodb_log_file_size = 5M
#innodb_log_buffer_size = 8M
#innodb_flush_log_at_trx_commit = 1
#innodb_lock_wait_timeout = 50

[mysqldump]
quick
max_allowed_packet = 16M

[mysql]
no-auto-rehash

[myisamchk]
key_buffer_size = 20M
sort_buffer_size = 20M
read_buffer = 2M
write_buffer = 2M

[mysqlhotcopy]
interactive-timeout
EOF
    if [ "${InstallInnodb}" = "y" ]; then
        sed -i 's/^#innodb/innodb/g' /etc/my.cnf
    else
        sed -i '/^default_storage_engine/d' /etc/my.cnf
        sed -i 's#default_storage_engine.*#default_storage_engine = MyISAM#' /etc/my.cnf
    fi
    MySQL_Opt
    Check_MySQL_Data_Dir
    chown -R mysql:mysql /usr/local/mysql
    /usr/local/mysql/bin/mysql_install_db --user=mysql --datadir=${MySQL_Data_Dir}
    chown -R mysql:mysql ${MySQL_Data_Dir}
    \cp /usr/local/mysql/share/mysql/mysql.server /etc/init.d/mysql
    chmod 755 /etc/init.d/mysql

    cat > /etc/ld.so.conf.d/mysql.conf<<EOF
    /usr/local/mysql/lib/mysql
    /usr/local/lib
EOF
    ldconfig

    ln -sf /usr/local/mysql/lib/mysql /usr/lib/mysql
    ln -sf /usr/local/mysql/include/mysql /usr/include/mysql

    MySQL_Sec_Setting
}

Install_MySQL_55()
{
    if [ "${Bin}" = "y" ]; then
        Echo_Blue "[+] Installing ${Mysql_Ver} Using Generic Binaries..."
        Tar_Cd "${Mysql_Ver}-linux-glibc2.12-${DB_ARCH}.tar.gz" || return 1
        mkdir /usr/local/mysql
        mv ${Mysql_Ver}-linux-glibc2.12-${DB_ARCH}/* /usr/local/mysql/
    else
        Echo_Blue "[+] Installing ${Mysql_Ver} Using Source code..."
        if [ "${isOpenSSL3}" = "y" ]; then
            MySQL_WITH_SSL='-DWITH_SSL=bundled'
        else
            MySQL_WITH_SSL=''
        fi
        Tar_Cd "${Mysql_Ver}.tar.gz" "${Mysql_Ver}" || return 1
        MySQL_ARM_Patch
        if  g++ -dM -E -x c++ /dev/null | grep -F __cplusplus | cut -d' ' -f3 | grep -Eqi "^2017|202[0-9]"; then
            sed -i '1s/^/set(CMAKE_CXX_STANDARD 11)\n/' CMakeLists.txt
        fi
        if echo "${Rocky_Version}" | grep -Eqi "^9"; then
            sed -i 's@^INCLUDE(cmake/abi_check.cmake)@#INCLUDE(cmake/abi_check.cmake)@' CMakeLists.txt
        fi
        cmake -DCMAKE_INSTALL_PREFIX=/usr/local/mysql -DSYSCONFDIR=/etc -DWITH_MYISAM_STORAGE_ENGINE=1 -DWITH_INNOBASE_STORAGE_ENGINE=1 -DWITH_PARTITION_STORAGE_ENGINE=1 -DWITH_FEDERATED_STORAGE_ENGINE=1 -DEXTRA_CHARSETS=all -DDEFAULT_CHARSET=utf8mb4 -DDEFAULT_COLLATION=utf8mb4_general_ci -DWITH_READLINE=1 -DWITH_EMBEDDED_SERVER=1 -DENABLED_LOCAL_INFILE=1 ${MySQL_WITH_SSL}
        Make_Install || return 1
    fi

    getent group mysql >/dev/null 2>&1 || groupadd mysql || return 1
    id mysql >/dev/null 2>&1 || useradd -s /sbin/nologin -M -g mysql mysql || return 1

    cat > /etc/my.cnf<<EOF
[client]
#password	= your_password
port		= 3306
socket		= /tmp/mysql.sock

[mysqld]
port		= 3306
socket		= /tmp/mysql.sock
datadir = ${MySQL_Data_Dir}
skip-external-locking
key_buffer_size = 16M
max_allowed_packet = 1M
table_open_cache = 64
sort_buffer_size = 512K
net_buffer_length = 8K
read_buffer_size = 256K
read_rnd_buffer_size = 512K
myisam_sort_buffer_size = 8M
thread_cache_size = 8
query_cache_size = 8M
tmp_table_size = 16M

#skip-networking
max_connections = 500
max_connect_errors = 100
open_files_limit = 65535

log-bin=mysql-bin
binlog_format=mixed
server-id	= 1
expire_logs_days = 10

default_storage_engine = InnoDB
#innodb_file_per_table = 1
#innodb_data_home_dir = ${MySQL_Data_Dir}
#innodb_data_file_path = ibdata1:10M:autoextend
#innodb_log_group_home_dir = ${MySQL_Data_Dir}
#innodb_buffer_pool_size = 16M
#innodb_additional_mem_pool_size = 2M
#innodb_log_file_size = 5M
#innodb_log_buffer_size = 8M
#innodb_flush_log_at_trx_commit = 1
#innodb_lock_wait_timeout = 50

[mysqldump]
quick
max_allowed_packet = 16M

[mysql]
no-auto-rehash

[myisamchk]
key_buffer_size = 20M
sort_buffer_size = 20M
read_buffer = 2M
write_buffer = 2M

[mysqlhotcopy]
interactive-timeout

${MySQLMAOpt}
EOF
    if [ "${InstallInnodb}" = "y" ]; then
        sed -i 's/^#innodb/innodb/g' /etc/my.cnf
    else
        sed -i '/^default_storage_engine/d' /etc/my.cnf
        sed -i '/skip-external-locking/i\default_storage_engine = MyISAM\nloose-skip-innodb' /etc/my.cnf
    fi
    MySQL_Opt
    Check_MySQL_Data_Dir
    chown -R mysql:mysql /usr/local/mysql
    /usr/local/mysql/scripts/mysql_install_db --defaults-file=/etc/my.cnf --basedir=/usr/local/mysql --datadir=${MySQL_Data_Dir} --user=mysql
    chown -R mysql:mysql ${MySQL_Data_Dir}
    \cp /usr/local/mysql/support-files/mysql.server /etc/init.d/mysql
    \cp ${cur_dir}/init.d/mysql.service /etc/systemd/system/mysql.service
    chmod 755 /etc/init.d/mysql

    cat > /etc/ld.so.conf.d/mysql.conf<<EOF
/usr/local/mysql/lib
/usr/local/lib
EOF
    ldconfig
    ln -sf /usr/local/mysql/lib/mysql /usr/lib/mysql
    ln -sf /usr/local/mysql/include/mysql /usr/include/mysql

    MySQL_Sec_Setting
}

Install_MySQL_56()
{
    if [ "${Bin}" = "y" ]; then
        Echo_Blue "[+] Installing ${Mysql_Ver} Using Generic Binaries..."
        Tar_Cd "${Mysql_Ver}-linux-glibc2.12-${DB_ARCH}.tar.gz" || return 1
        mkdir /usr/local/mysql
        mv ${Mysql_Ver}-linux-glibc2.12-${DB_ARCH}/* /usr/local/mysql/
    else
        Echo_Blue "[+] Installing ${Mysql_Ver} Using Source code..."
        if [ "${isOpenSSL3}" = "y" ]; then
            Install_Openssl_New
            MySQL_WITH_SSL='-DWITH_SSL=/usr/local/openssl1.1.1'
        else
            MySQL_WITH_SSL=''
        fi
        Tar_Cd "${Mysql_Ver}.tar.gz" "${Mysql_Ver}" || return 1
        if  g++ -dM -E -x c++ /dev/null | grep -F __cplusplus | cut -d' ' -f3 | grep -Eqi "^2017|202[0-9]"; then
            sed -i '1s/^/set(CMAKE_CXX_STANDARD 11)\n/' CMakeLists.txt
        fi
        if echo "${Rocky_Version}" | grep -Eqi "^9"; then
            sed -i 's@^INCLUDE(cmake/abi_check.cmake)@#INCLUDE(cmake/abi_check.cmake)@' CMakeLists.txt
        fi
        cmake -DCMAKE_INSTALL_PREFIX=/usr/local/mysql -DSYSCONFDIR=/etc -DWITH_MYISAM_STORAGE_ENGINE=1 -DWITH_INNOBASE_STORAGE_ENGINE=1 -DWITH_PARTITION_STORAGE_ENGINE=1 -DWITH_FEDERATED_STORAGE_ENGINE=1 -DEXTRA_CHARSETS=all -DDEFAULT_CHARSET=utf8mb4 -DDEFAULT_COLLATION=utf8mb4_general_ci -DWITH_EMBEDDED_SERVER=1 -DENABLED_LOCAL_INFILE=1 ${MySQL_WITH_SSL}
        Make_Install || return 1
    fi

    getent group mysql >/dev/null 2>&1 || groupadd mysql || return 1
    id mysql >/dev/null 2>&1 || useradd -s /sbin/nologin -M -g mysql mysql || return 1

    cat > /etc/my.cnf<<EOF
[client]
#password   = your_password
port        = 3306
socket      = /tmp/mysql.sock

[mysqld]
port        = 3306
socket      = /tmp/mysql.sock
datadir = ${MySQL_Data_Dir}
skip-external-locking
key_buffer_size = 16M
max_allowed_packet = 1M
table_open_cache = 64
sort_buffer_size = 512K
net_buffer_length = 8K
read_buffer_size = 256K
read_rnd_buffer_size = 512K
myisam_sort_buffer_size = 8M
thread_cache_size = 8
query_cache_size = 8M
tmp_table_size = 16M
performance_schema_max_table_instances = 500

explicit_defaults_for_timestamp = true
#skip-networking
max_connections = 500
max_connect_errors = 100
open_files_limit = 65535

log-bin=mysql-bin
binlog_format=mixed
server-id   = 1
expire_logs_days = 10

#loose-innodb-trx=0
#loose-innodb-locks=0
#loose-innodb-lock-waits=0
#loose-innodb-cmp=0
#loose-innodb-cmp-per-index=0
#loose-innodb-cmp-per-index-reset=0
#loose-innodb-cmp-reset=0
#loose-innodb-cmpmem=0
#loose-innodb-cmpmem-reset=0
#loose-innodb-buffer-page=0
#loose-innodb-buffer-page-lru=0
#loose-innodb-buffer-pool-stats=0
#loose-innodb-metrics=0
#loose-innodb-ft-default-stopword=0
#loose-innodb-ft-inserted=0
#loose-innodb-ft-deleted=0
#loose-innodb-ft-being-deleted=0
#loose-innodb-ft-config=0
#loose-innodb-ft-index-cache=0
#loose-innodb-ft-index-table=0
#loose-innodb-sys-tables=0
#loose-innodb-sys-tablestats=0
#loose-innodb-sys-indexes=0
#loose-innodb-sys-columns=0
#loose-innodb-sys-fields=0
#loose-innodb-sys-foreign=0
#loose-innodb-sys-foreign-cols=0

default_storage_engine = InnoDB
#innodb_file_per_table = 1
#innodb_data_home_dir = ${MySQL_Data_Dir}
#innodb_data_file_path = ibdata1:10M:autoextend
#innodb_log_group_home_dir = ${MySQL_Data_Dir}
#innodb_buffer_pool_size = 16M
#innodb_log_file_size = 5M
#innodb_log_buffer_size = 8M
#innodb_flush_log_at_trx_commit = 1
#innodb_lock_wait_timeout = 50

[mysqldump]
quick
max_allowed_packet = 16M

[mysql]
no-auto-rehash

[myisamchk]
key_buffer_size = 20M
sort_buffer_size = 20M
read_buffer = 2M
write_buffer = 2M

[mysqlhotcopy]
interactive-timeout

${MySQLMAOpt}
EOF

    if [ "${InstallInnodb}" = "y" ]; then
        sed -i 's/^#innodb/innodb/g' /etc/my.cnf
    else
        sed -i '/^default_storage_engine/d' /etc/my.cnf
        sed -i '/skip-external-locking/i\innodb=OFF\nignore-builtin-innodb\nskip-innodb\ndefault_storage_engine = MyISAM\ndefault_tmp_storage_engine = MyISAM' /etc/my.cnf
        sed -i 's/^#loose-innodb/loose-innodb/g' /etc/my.cnf
    fi
    MySQL_Opt
    Check_MySQL_Data_Dir
    chown -R mysql:mysql /usr/local/mysql
    /usr/local/mysql/scripts/mysql_install_db --defaults-file=/etc/my.cnf --basedir=/usr/local/mysql --datadir=${MySQL_Data_Dir} --user=mysql
    chown -R mysql:mysql ${MySQL_Data_Dir}
    \cp /usr/local/mysql/support-files/mysql.server /etc/init.d/mysql
    \cp ${cur_dir}/init.d/mysql.service /etc/systemd/system/mysql.service
    chmod 755 /etc/init.d/mysql

    cat > /etc/ld.so.conf.d/mysql.conf<<EOF
    /usr/local/mysql/lib
    /usr/local/lib
EOF
    ldconfig
    ln -sf /usr/local/mysql/lib/mysql /usr/lib/mysql
    ln -sf /usr/local/mysql/include/mysql /usr/include/mysql

    MySQL_Sec_Setting
}

Install_MySQL_57()
{
    rm -f /etc/my.cnf
    if [ "${Bin}" = "y" ]; then
        Echo_Blue "[+] Installing ${Mysql_Ver} Using Generic Binaries..."
        Tar_Cd "${Mysql_Ver}-linux-glibc2.12-${DB_ARCH}.tar.gz" || return 1
        mkdir /usr/local/mysql
        mv ${Mysql_Ver}-linux-glibc2.12-${DB_ARCH}/* /usr/local/mysql/
    else
        Echo_Blue "[+] Installing ${Mysql_Ver} Using Source code..."
        if [ "${isOpenSSL3}" = "y" ]; then
            Install_Openssl_New
            MySQL_WITH_SSL='-DWITH_SSL=/usr/local/openssl1.1.1'
        else
            MySQL_WITH_SSL=''
        fi
        Tar_Cd "${Mysql_Ver}.tar.gz" "${Mysql_Ver}" || return 1
        Install_Boost || return 1
        if echo "${Rocky_Version}" | grep -Eqi "^9"; then
            sed -i 's@^INCLUDE(cmake/abi_check.cmake)@#INCLUDE(cmake/abi_check.cmake)@' CMakeLists.txt
        fi
        cmake -DCMAKE_INSTALL_PREFIX=/usr/local/mysql -DSYSCONFDIR=/etc -DWITH_MYISAM_STORAGE_ENGINE=1 -DWITH_INNOBASE_STORAGE_ENGINE=1 -DWITH_PARTITION_STORAGE_ENGINE=1 -DWITH_FEDERATED_STORAGE_ENGINE=1 -DEXTRA_CHARSETS=all -DDEFAULT_CHARSET=utf8mb4 -DDEFAULT_COLLATION=utf8mb4_general_ci -DWITH_EMBEDDED_SERVER=1 -DENABLED_LOCAL_INFILE=1 ${MySQL_WITH_SSL} ${MySQL_WITH_BOOST}
        Make_Install || return 1
    fi

    getent group mysql >/dev/null 2>&1 || groupadd mysql || return 1
    id mysql >/dev/null 2>&1 || useradd -s /sbin/nologin -M -g mysql mysql || return 1

    cat > /etc/my.cnf<<EOF
[client]
#password   = your_password
port        = 3306
socket      = /tmp/mysql.sock

[mysqld]
port        = 3306
socket      = /tmp/mysql.sock
datadir = ${MySQL_Data_Dir}
skip-external-locking
key_buffer_size = 16M
max_allowed_packet = 1M
table_open_cache = 64
sort_buffer_size = 512K
net_buffer_length = 8K
read_buffer_size = 256K
read_rnd_buffer_size = 512K
myisam_sort_buffer_size = 8M
thread_cache_size = 8
query_cache_size = 8M
tmp_table_size = 16M
performance_schema_max_table_instances = 500

explicit_defaults_for_timestamp = true
#skip-networking
max_connections = 500
max_connect_errors = 100
open_files_limit = 65535

log-bin=mysql-bin
binlog_format=mixed
server-id   = 1
expire_logs_days = 10
early-plugin-load = ""

default_storage_engine = InnoDB
innodb_file_per_table = 1
innodb_data_home_dir = ${MySQL_Data_Dir}
innodb_data_file_path = ibdata1:10M:autoextend
innodb_log_group_home_dir = ${MySQL_Data_Dir}
innodb_buffer_pool_size = 16M
innodb_log_file_size = 5M
innodb_log_buffer_size = 8M
innodb_flush_log_at_trx_commit = 1
innodb_lock_wait_timeout = 50

[mysqldump]
quick
max_allowed_packet = 16M

[mysql]
no-auto-rehash

[myisamchk]
key_buffer_size = 20M
sort_buffer_size = 20M
read_buffer_size = 2M
write_buffer_size = 2M

[mysqlhotcopy]
interactive-timeout

${MySQLMAOpt}
EOF

    MySQL_Opt
    Check_MySQL_Data_Dir
    chown -R mysql:mysql /usr/local/mysql
    /usr/local/mysql/bin/mysqld --initialize-insecure --basedir=/usr/local/mysql --datadir=${MySQL_Data_Dir} --user=mysql
    chown -R mysql:mysql ${MySQL_Data_Dir}
    \cp /usr/local/mysql/support-files/mysql.server /etc/init.d/mysql
    \cp ${cur_dir}/init.d/mysql.service /etc/systemd/system/mysql.service
    chmod 755 /etc/init.d/mysql

    cat > /etc/ld.so.conf.d/mysql.conf<<EOF
    /usr/local/mysql/lib
    /usr/local/lib
EOF
    ldconfig
    ln -sf /usr/local/mysql/lib/mysql /usr/lib/mysql
    ln -sf /usr/local/mysql/include/mysql /usr/include/mysql

    MySQL_Sec_Setting
}

Install_MySQL_80()
{
    rm -f /etc/my.cnf
    if [ "${Bin}" = "y" ]; then
        Echo_Blue "[+] Installing ${Mysql_Ver} Using Generic Binaries..."
        mysql8_file=$(Get_MySQL_Binary_File "${Mysql_Ver}" "${DB_ARCH}") || return 1
        mysql8_dir="${mysql8_file%.tar.*}"
        Tar_Cd "${mysql8_file}" "${mysql8_dir}" || return 1
        cd "${cur_dir}/src"
        mkdir -p /usr/local/mysql
        find "${mysql8_dir}" -mindepth 1 -maxdepth 1 -exec mv -f -- {} /usr/local/mysql/ \; || return 1
        rmdir "${mysql8_dir}" || return 1
    else
        Echo_Blue "[+] Installing ${Mysql_Ver} Using Source code..."
        Tar_Cd "${Mysql_Ver}.tar.gz" "${Mysql_Ver}" || return 1
        Install_Boost || return 1
        mkdir build && cd build || return 1
        cmake .. -DCMAKE_INSTALL_PREFIX=/usr/local/mysql -DSYSCONFDIR=/etc -DWITH_MYISAM_STORAGE_ENGINE=1 -DWITH_INNOBASE_STORAGE_ENGINE=1 -DWITH_PARTITION_STORAGE_ENGINE=1 -DWITH_FEDERATED_STORAGE_ENGINE=1 -DEXTRA_CHARSETS=all -DDEFAULT_CHARSET=utf8mb4 -DDEFAULT_COLLATION=utf8mb4_general_ci -DENABLED_LOCAL_INFILE=1 ${MySQL_WITH_BOOST} || return 1
        Make_Install || return 1
    fi

    getent group mysql >/dev/null 2>&1 || groupadd mysql || return 1
    id mysql >/dev/null 2>&1 || useradd -s /sbin/nologin -M -g mysql mysql || return 1

    cat > /etc/my.cnf<<EOF
[client]
#password   = your_password
port        = 3306
socket      = /tmp/mysql.sock

[mysqld]
port        = 3306
socket      = /tmp/mysql.sock
datadir = ${MySQL_Data_Dir}
skip-external-locking
key_buffer_size = 16M
max_allowed_packet = 1M
table_open_cache = 64
sort_buffer_size = 512K
net_buffer_length = 8K
read_buffer_size = 256K
read_rnd_buffer_size = 512K
myisam_sort_buffer_size = 8M
thread_cache_size = 8
tmp_table_size = 16M
performance_schema_max_table_instances = 500

explicit_defaults_for_timestamp = true
#skip-networking
max_connections = 500
max_connect_errors = 100
open_files_limit = 65535

log-bin=mysql-bin
# MySQL 8.0 no longer needs the deprecated binlog_format option.
server-id   = 1
binlog_expire_logs_seconds = 864000

default_storage_engine = InnoDB
innodb_file_per_table = 1
innodb_data_home_dir = ${MySQL_Data_Dir}
innodb_data_file_path = ibdata1:10M:autoextend
innodb_log_group_home_dir = ${MySQL_Data_Dir}
innodb_buffer_pool_size = 16M
innodb_redo_log_capacity = 100M
innodb_log_buffer_size = 8M
innodb_flush_log_at_trx_commit = 1
innodb_lock_wait_timeout = 50

[mysqldump]
quick
max_allowed_packet = 16M

[mysql]
no-auto-rehash

[myisamchk]
key_buffer_size = 20M
sort_buffer_size = 20M
read_buffer_size = 2M
write_buffer_size = 2M

[mysqlhotcopy]
interactive-timeout

${MySQLMAOpt}
EOF

    MySQL_Opt
    Check_MySQL_Data_Dir
    chown -R mysql:mysql /usr/local/mysql
    Check_MySQL_Dependencies || return 1
    local mysql_init_output
    MySQL_Temporary_Password=''
    mysql_init_output=$(mktemp "${TMPDIR:-/tmp}/lnmp-mysql-init.XXXXXX") || return 1
    if ! /usr/local/mysql/bin/mysqld --initialize --console --basedir=/usr/local/mysql --datadir="${MySQL_Data_Dir}" --user=mysql >"${mysql_init_output}" 2>&1; then
        echo "MySQL initialization failed; refusing to print its captured output because it may contain credentials." >&2
        rm -f -- "${mysql_init_output}"
        return 1
    fi
    MySQL_Temporary_Password=$(sed -n 's/.*[Tt]emporary password is generated for root@localhost: //p' "${mysql_init_output}" | tail -n 1)
    rm -f -- "${mysql_init_output}"
    if [ -z "${MySQL_Temporary_Password}" ]; then
        echo "MySQL initialization did not provide a temporary root password." >&2
        return 1
    fi
    chown -R mysql:mysql "${MySQL_Data_Dir}" || return 1
    \cp /usr/local/mysql/support-files/mysql.server /etc/init.d/mysql || return 1
    \cp "${cur_dir}/init.d/mysql.service" /etc/systemd/system/mysql.service || return 1
    chmod 755 /etc/init.d/mysql || return 1

    cat > /etc/ld.so.conf.d/mysql.conf<<EOF
    /usr/local/mysql/lib
    /usr/local/lib
EOF
    ldconfig || return 1
    if ldd /usr/local/mysql/bin/mysqld 2>&1 | grep -q 'not found'; then
        echo "MySQL has unresolved shared-library dependencies." >&2
        ldd /usr/local/mysql/bin/mysqld >&2
        return 1
    fi
    ln -sf /usr/local/mysql/lib/mysql /usr/lib/mysql || return 1
    ln -sf /usr/local/mysql/include/mysql /usr/include/mysql || return 1

    MySQL_Sec_Setting || return 1
}

Install_MySQL_84()
{
    Install_MySQL_80
}

Install_MySQL_97()
{
    Install_MySQL_80
}
