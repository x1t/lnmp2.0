#!/usr/bin/env bash

Nginx_Dependent()
{
    if [ "$PM" = "yum" ]; then
        rpm -e httpd httpd-tools --nodeps
        yum -y remove httpd*
        for packages in make gcc gcc-c++ gcc-g77 wget crontabs zlib zlib-devel openssl openssl-devel perl patch bzip2 initscripts xz gzip;
        do yum -y install $packages; done
        if [ "${DISTRO}" = "Fedora" ] || echo "${CentOS_Version}" | grep -Eqi "^9"; then
            dnf install chkconfig -y
        fi
    elif [ "$PM" = "apt" ]; then
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -y
        [[ $? -ne 0 ]] && apt-get update --allow-releaseinfo-change -y
        dpkg -P apache2 apache2-doc apache2-mpm-prefork apache2-utils apache2.2-common
        for removepackages in apache2 apache2-doc apache2-utils apache2.2-common apache2.2-bin apache2-mpm-prefork apache2-doc apache2-mpm-worker;
        do apt-get purge -y $removepackages; done
        for packages in debian-keyring debian-archive-keyring build-essential gcc g++ make autoconf automake wget cron openssl libssl-dev zlib1g zlib1g-dev bzip2 xz-utils gzip;
        do apt-get --no-install-recommends install -y $packages; done
    fi
}

Install_Only_Nginx()
{
    clear
    echo "+-----------------------------------------------------------------------+"
    echo "|              Install Nginx for LNMP, Written by Licess                |"
    echo "+-----------------------------------------------------------------------+"
    echo "|                     A tool to only install Nginx.                     |"
    echo "+-----------------------------------------------------------------------+"
    echo "|           For more information please visit https://lnmp.org          |"
    echo "+-----------------------------------------------------------------------+"
    Press_Install || return 1
    Echo_Blue "Install dependent packages..."
    cd "${cur_dir}/src" || return 1
    Get_Dist_Version
    Modify_Source || return 1
    Nginx_Dependent || return 1
    cd "${cur_dir}/src" || return 1
    # Use the public university mirror for the PCRE1 archive, with SourceForge fallback.
    if ! Download_Files "${University_Mirror}/macports/distfiles/pcre/${Pcre_Ver}.tar.bz2" "${Pcre_Ver}.tar.bz2"; then
        Download_Files "https://sourceforge.net/projects/pcre/files/pcre/${Pcre_Ver##*-}/${Pcre_Ver}.tar.bz2/download" "${Pcre_Ver}.tar.bz2" || return 1
    fi
    Install_Pcre || return 1
    if [ `grep -L '/usr/local/lib'    '/etc/ld.so.conf'` ]; then
        echo "/usr/local/lib" >> /etc/ld.so.conf
    fi
    ldconfig
    # Use official Nginx download
    Download_Files "https://nginx.org/download/${Nginx_Ver}.tar.gz" "${Nginx_Ver}.tar.gz" || return 1
    Install_Nginx || return 1
    StartUp nginx || return 1
    rm -rf -- "${cur_dir}/src/${Nginx_Ver}"
    [[ -d "${cur_dir}/src/${Openssl_Ver}" ]] && rm -rf ${cur_dir}/src/${Openssl_Ver}
    [[ -d "${cur_dir}/src/${Openssl_New_Ver}" ]] && rm -rf ${cur_dir}/src/${Openssl_New_Ver}
    StartOrStop start nginx || return 1
    Add_Iptables_Rules || return 1
    \cp "${cur_dir}/conf/index.html" "${Default_Website_Dir}/index.html" || return 1
    chown www:www "${Default_Website_Dir}/index.html" || return 1
    chmod 0644 "${Default_Website_Dir}/index.html" || return 1
    \cp "${cur_dir}/conf/lnmp" /bin/lnmp || return 1
    Check_Nginx_Files || return 1
}

DB_Dependent()
{
    if [ "$PM" = "yum" ]; then
        yum -y remove mysql-server mysql mysql-libs mariadb-server mariadb mariadb-libs
        rpm -qa|grep mysql
        if [ $? -ne 0 ]; then
            rpm -e mysql mysql-libs --nodeps
            rpm -e mariadb mariadb-libs --nodeps
        fi
        for packages in make cmake gcc gcc-c++ gcc-g77 flex bison wget zlib zlib-devel openssl openssl-devel ncurses ncurses-devel libaio-devel rpcgen libtirpc-devel patch cyrus-sasl-devel pkg-config pcre-devel libxml2-devel hostname ncurses-libs numactl-devel libxcrypt gnutls-devel initscripts libxcrypt-compat perl xz gzip;
        do yum -y install $packages; done
        if echo "${CentOS_Version}" | grep -Eqi "^8" || echo "${RHEL_Version}" | grep -Eqi "^8" || echo "${Rocky_Version}" | grep -Eqi "^8" || echo "${Alma_Version}" | grep -Eqi "^8"; then
            Check_PowerTools
            dnf --enablerepo=${repo_id} install rpcgen -y
            dnf install libarchive -y

            dnf install gcc-toolset-10 -y
        fi

        if [ "${DISTRO}" = "Oracle" ] && echo "${Oracle_Version}" | grep -Eqi "^8"; then
            Check_Codeready
            dnf --enablerepo=${repo_id} install rpcgen re2c -y
            dnf install libarchive -y
        fi

        if [ "${DISTRO}" = "Oracle" ] && echo "${Oracle_Version}" | grep -Eqi "^9"; then
            Check_Codeready
            dnf --enablerepo=${repo_id} install libtirpc-devel -y
            if [[ "${Bin}" != "y" ]] && Is_Modern_MySQL_DB; then
                dnf install gcc-toolset-12-gcc gcc-toolset-12-gcc-c++ gcc-toolset-12-binutils gcc-toolset-12-annobin-annocheck gcc-toolset-12-annobin-plugin-gcc -y
            fi
        fi

        if [ "${DISTRO}" = "Fedora" ] || echo "${CentOS_Version}" | grep -Eqi "^9" || echo "${Alma_Version}" | grep -Eqi "^9" || echo "${Rocky_Version}" | grep -Eqi "^9"; then
            dnf install chkconfig -y
        fi

        if echo "${CentOS_Version}" | grep -Eqi "^9" || echo "${Alma_Version}" | grep -Eqi "^9" || echo "${Rocky_Version}" | grep -Eqi "^9"; then
            dnf --enablerepo=crb install libtirpc-devel libxcrypt-compat -y
            if [[ "${Bin}" != "y" ]] && Is_Modern_MySQL_DB; then
                dnf install gcc-toolset-12-gcc gcc-toolset-12-gcc-c++ gcc-toolset-12-binutils gcc-toolset-12-annobin-annocheck gcc-toolset-12-annobin-plugin-gcc -y
            fi
        fi

        if [ -s /usr/lib64/libtinfo.so.6 ]; then
            ln -sf /usr/lib64/libtinfo.so.6 /usr/lib64/libtinfo.so.5
        elif [ -s /usr/lib/libtinfo.so.6 ]; then
            ln -sf /usr/lib/libtinfo.so.6 /usr/lib/libtinfo.so.5
        fi

        if [ -s /usr/lib64/libncurses.so.6 ]; then
            ln -sf /usr/lib64/libncurses.so.6 /usr/lib64/libncurses.so.5
        elif [ -s /usr/lib/libncurses.so.6 ]; then
            ln -sf /usr/lib/libncurses.so.6 /usr/lib/libncurses.so.5
        fi
    elif [ "$PM" = "apt" ]; then
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -y
        [[ $? -ne 0 ]] && apt-get update --allow-releaseinfo-change -y
        for removepackages in mysql-client mysql-server mysql-common mysql-server-core-5.5 mysql-client-5.5 mariadb-client mariadb-server mariadb-common;
        do apt-get purge -y $removepackages; done
        dpkg -l |grep mysql
        dpkg -P mysql-server mysql-common libmysqlclient15off libmysqlclient15-dev
        dpkg -P mariadb-client mariadb-server mariadb-common
        # Check for Debian 13 Trixie and adjust package names
        if [ "${DISTRO}" = "Debian" ] && echo "${Debian_Version}" | grep -Eqi "^13"; then
            libaio_pkg="libaio1t64"
            libncurses_pkg="libncurses6 libncurses-dev"
            libtinfo_pkg="libtinfo6"
        else
            libaio_pkg="libaio-dev"
            libncurses_pkg="libncurses5 libncurses5-dev"
            libtinfo_pkg="libtinfo-dev"
        fi
        
        for packages in debian-keyring debian-archive-keyring build-essential gcc g++ make cmake autoconf automake wget openssl libssl-dev zlib1g zlib1g-dev ${libncurses_pkg} bison ${libaio_pkg} libtirpc-dev libsasl2-dev pkg-config libpcre2-dev libxml2-dev ${libtinfo_pkg} libnuma-dev gnutls-dev xz-utils gzip;
        do apt-get --no-install-recommends install -y $packages; done
    fi
}

Install_Database()
{
    echo "============================check files=================================="
    cd "${cur_dir}/src" || return 1
    if Is_MySQL_DB; then
        if [[ "${Bin}" = "y" && "${DBSelect}" =~ ^[2-4]$ ]]; then
            Mysql_Ver_Short=$(echo ${Mysql_Ver} | sed 's/mysql-//' | cut -d. -f1-2)
            if ! Download_Files "https://cdn.mysql.com/Downloads/MySQL-${Mysql_Ver_Short}/${Mysql_Ver}-linux-glibc2.12-${DB_ARCH}.tar.gz" "${Mysql_Ver}-linux-glibc2.12-${DB_ARCH}.tar.gz"; then
                Download_Files "https://cdn.mysql.com/archives/mysql-${Mysql_Ver_Short}/${Mysql_Ver}-linux-glibc2.12-${DB_ARCH}.tar.gz" "${Mysql_Ver}-linux-glibc2.12-${DB_ARCH}.tar.gz" || return 1
            fi
            if [ ! -s "${Mysql_Ver}-linux-glibc2.12-${DB_ARCH}.tar.gz" ]; then
                Echo_Red "Error! Unable to download MySQL ${Mysql_Ver_Short} Generic Binaries, please download it to src directory manually."
                sleep 5
                exit 1
            fi
        elif [[ "${Bin}" = "y" ]] && Is_Modern_MySQL_DB; then
            Mysql_Ver_Short=$(echo ${Mysql_Ver} | sed 's/mysql-//' | cut -d. -f1-2)
            mysql8_file=$(Get_MySQL_Binary_File "${Mysql_Ver}" "${DB_ARCH}") || return 1
            if ! Download_Files "https://cdn.mysql.com/Downloads/MySQL-${Mysql_Ver_Short}/${mysql8_file}" "${mysql8_file}"; then
                Download_Files "https://cdn.mysql.com/archives/mysql-${Mysql_Ver_Short}/${mysql8_file}" "${mysql8_file}" || return 1
            fi
            if [ ! -s "${mysql8_file}" ]; then
                Echo_Red "Error! Unable to download MySQL ${Mysql_Ver_Short} Generic Binaries, please download it to src directory manually."
                sleep 5
                exit 1
            fi
        else
            Mysql_Ver_Short=$(echo ${Mysql_Ver} | sed 's/mysql-//' | cut -d. -f1-2)
            Download_Files "https://cdn.mysql.com/Downloads/MySQL-${Mysql_Ver_Short}/${Mysql_Ver}.tar.gz" "${Mysql_Ver}.tar.gz" || return 1
            if [ ! -s "${Mysql_Ver}.tar.gz" ]; then
                Echo_Red "Error! Unable to download MySQL source code, please download it to src directory manually."
                sleep 5
                exit 1
            fi
        fi
    elif Is_MariaDB_DB; then
        Mariadb_Version=$(echo ${Mariadb_Ver} | cut -d- -f2)
        if [ "${Bin}" = "y" ]; then
            MariaDB_FileName="${Mariadb_Ver}-linux-systemd-${DB_ARCH}"
        else
            MariaDB_FileName="${Mariadb_Ver}"
        fi
        Download_Files "https://downloads.mariadb.org/rest-api/mariadb/${Mariadb_Version}/${MariaDB_FileName}.tar.gz" "${MariaDB_FileName}.tar.gz" || return 1
        if [ ! -s "${MariaDB_FileName}.tar.gz" ]; then
            Echo_Red "Error! Unable to download MariaDB, please download it to src directory manually."
            sleep 5
            exit 1
        fi
    fi
    echo "============================check files=================================="

    Echo_Blue "Install dependent packages..."
    Get_Dist_Version
    Modify_Source || return 1
    DB_Dependent || return 1
    Check_Openssl || return 1
    if [ "${DBSelect}" = "1" ]; then
        Install_MySQL_51 || return 1
    elif [ "${DBSelect}" = "2" ]; then
        Install_MySQL_55 || return 1
    elif [ "${DBSelect}" = "3" ]; then
        Install_MySQL_56 || return 1
    elif [ "${DBSelect}" = "4" ]; then
        Install_MySQL_57 || return 1
    elif [ "${DBSelect}" = "5" ]; then
        Install_MySQL_80 || return 1
    elif [ "${DBSelect}" = "11" ]; then
        Install_MySQL_84 || return 1
    elif [ "${DBSelect}" = "12" ]; then
        Install_MySQL_97 || return 1
    elif [ "${DBSelect}" = "6" ]; then
        Install_MariaDB_5 || return 1
    elif [ "${DBSelect}" = "7" ]; then
        Install_MariaDB_103 || return 1
    elif [ "${DBSelect}" = "8" ]; then
        Install_MariaDB_104 || return 1
    elif [ "${DBSelect}" = "9" ]; then
        Install_MariaDB_105 || return 1
    elif [ "${DBSelect}" = "10" ]; then
        Install_MariaDB_106 || return 1
    fi
    TempMycnf_Clean || return 1

    if Is_MariaDB_DB; then
        StartUp mariadb || return 1
        StartOrStop start mariadb || return 1
    elif Is_MySQL_DB; then
        StartUp mysql || return 1
        StartOrStop start mysql || return 1
    fi

    Clean_DB_Src_Dir || return 1
    Check_DB_Files || return 1
    if [[ "${isDB}" = "ok" ]]; then
        if Is_MySQL_DB; then
            Echo_Green "MySQL root password has been configured."
            Echo_Green "Install ${Mysql_Ver} completed! enjoy it."
        elif Is_MariaDB_DB; then
            Echo_Green "MariaDB root password has been configured."
            Echo_Green "Install ${Mariadb_Ver} completed! enjoy it."
        fi
    fi
}

Install_Only_Database()
{
    clear
    echo "+-----------------------------------------------------------------------+"
    echo "|      Install MySQL/MariaDB database for LNMP, Written by Licess       |"
    echo "+-----------------------------------------------------------------------+"
    echo "|               A tool to install MySQL/MariaDB for LNMP                |"
    echo "+-----------------------------------------------------------------------+"
    echo "|           For more information please visit https://lnmp.org          |"
    echo "+-----------------------------------------------------------------------+"

    Get_Dist_Name
    Check_DB
    if [ "${DB_Name}" != "None" ]; then
        echo "You have install ${DB_Name}!"
        exit 1
    fi

    Database_Selection
    if [ "${DBSelect}" = "0" ]; then
        echo "DO NOT Install MySQL or MariaDB."
        exit 1
    fi
    Echo_Red "The script will REMOVE MySQL/MariaDB installed via yum or apt-get and it's databases!!!"
    Press_Install || return 1
    Install_Database 2>&1 | tee /root/install_database.log
    return "${PIPESTATUS[0]}"
}
