#!/usr/bin/env bash
umask 077
export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)" || exit 1
cd -- "${SCRIPT_DIR}" || exit 1

# Check if user is root
if [ $(id -u) != "0" ]; then
    echo "Error: You must be root to run this script, please use root to install lnmp"
    exit 1
fi

cur_dir="${SCRIPT_DIR}"
Stack=$1

LNMP_Ver='2.0'

. lnmp.conf
. include/main.sh

shopt -s extglob

Check_DB
Get_Dist_Name

clear
echo "+------------------------------------------------------------------------+"
echo "|          LNMP V${LNMP_Ver} for ${DISTRO} Linux Server, Written by Licess          |"
echo "+------------------------------------------------------------------------+"
echo "|        A tool to auto-compile & install Nginx+MySQL+PHP on Linux       |"
echo "+------------------------------------------------------------------------+"
echo "|           For more information please visit https://lnmp.org           |"
echo "+------------------------------------------------------------------------+"

Sleep_Sec()
{
    seconds=$1
    while [ "${seconds}" -ge "0" ];do
      echo -ne "\r     \r"
      echo -n ${seconds}
      seconds=$(($seconds - 1))
      sleep 1
    done
    echo -ne "\r"
}

Backup_Database_Data()
{
    local data_dir backup_dir

    case "${DB_Name}" in
        mysql)
            data_dir="${MySQL_Data_Dir}"
            ;;
        mariadb)
            data_dir="${MariaDB_Data_Dir}"
            ;;
        *)
            return 0
            ;;
    esac

    if [[ -z "${data_dir}" || "${data_dir}" != /* || "${data_dir}" = "/" ]]; then
        echo "Error: refusing to back up an invalid database data directory: ${data_dir}" >&2
        return 1
    fi
    if [ ! -d "${data_dir}" ]; then
        echo "Database data directory does not exist; backup skipped: ${data_dir}"
        return 0
    fi

    backup_dir="/root/databases_backup_$(date +"%Y%m%d%H%M%S")-$$"
    while [ -e "${backup_dir}" ]; do
        backup_dir="${backup_dir}-1"
    done
    echo "Backup ${DB_Name} databases directory to ${backup_dir}"
    mv -- "${data_dir}" "${backup_dir}" || return 1
}

Uninstall_LNMP()
{
    echo "Stoping LNMP..."
    lnmp kill
    lnmp stop

    Remove_StartUp nginx
    Remove_StartUp php-fpm
    if [ "${DB_Name}" != "None" ]; then
        Remove_StartUp "${DB_Name}"
        Backup_Database_Data || return 1
    fi
    if [ -n "${Default_Website_Dir}" ] && [ "${Default_Website_Dir}" != "/" ]; then
        chattr -i -- "${Default_Website_Dir}/.user.ini" >/dev/null 2>&1 || true
    fi
    echo "Deleting LNMP files..."
    rm -rf /usr/local/nginx
    rm -rf /usr/local/php
    rm -rf /usr/local/zend

    if [ "${DB_Name}" != "None" ]; then
        rm -rf -- "/usr/local/${DB_Name}"
        rm -f /etc/my.cnf
        rm -f -- "/etc/init.d/${DB_Name}"
    fi

    for mphp in /usr/local/php[0-9]*.[0-9]*; do
        [ -d "${mphp}" ] || continue
        mphp_ver="${mphp#/usr/local/php}"
        if [ -s "/etc/init.d/php-fpm${mphp_ver}" ]; then
            "/etc/init.d/php-fpm${mphp_ver}" stop
            Remove_StartUp "php-fpm${mphp_ver}"
            rm -f -- "/etc/init.d/php-fpm${mphp_ver}"
        fi
        rm -rf -- "${mphp}"
    done

    if [ -s /usr/local/acme.sh/acme.sh ]; then
        /usr/local/acme.sh/acme.sh --uninstall
        rm -rf /usr/local/acme.sh
        if crontab -l|grep -v "/usr/local/acme.sh/upgrade.sh"; then
            crontab -l|grep -v "/usr/local/acme.sh/upgrade.sh" | crontab -
        fi
    fi

    rm -f /etc/init.d/nginx
    rm -f /etc/init.d/php-fpm
    rm -f /bin/lnmp
    echo "LNMP Uninstall completed."
}

Uninstall_LNMPA()
{
    echo "Stoping LNMPA..."
    lnmp kill
    lnmp stop
    
    Remove_StartUp nginx
    Remove_StartUp httpd
    if [ "${DB_Name}" != "None" ]; then
        Remove_StartUp "${DB_Name}"
        Backup_Database_Data || return 1
    fi
    echo "Deleting LNMPA files..."
    rm -rf /usr/local/nginx
    rm -rf /usr/local/php
    rm -rf /usr/local/apache
    rm -rf /usr/local/zend

    if [ "${DB_Name}" != "None" ]; then
        rm -rf -- "/usr/local/${DB_Name}"
        rm -f /etc/my.cnf
        rm -f -- "/etc/init.d/${DB_Name}"
    fi

    if [ -s /usr/local/acme.sh/acme.sh ]; then
        /usr/local/acme.sh/acme.sh --uninstall
        rm -rf /usr/local/acme.sh
        if crontab -l|grep -v "/usr/local/acme.sh/upgrade.sh"; then
            crontab -l|grep -v "/usr/local/acme.sh/upgrade.sh" | crontab -
        fi
    fi

    rm -f /etc/init.d/nginx
    rm -f /etc/init.d/httpd
    rm -f /bin/lnmp
    echo "LNMPA Uninstall completed."
}

Uninstall_LAMP()
{
    echo "Stoping LAMP..."
    lnmp kill
    lnmp stop

    Remove_StartUp httpd
    if [ "${DB_Name}" != "None" ]; then
        Remove_StartUp "${DB_Name}"
        Backup_Database_Data || return 1
    fi
    echo "Deleting LAMP files..."
    rm -rf /usr/local/apache
    rm -rf /usr/local/php
    rm -rf /usr/local/zend

    if [ "${DB_Name}" != "None" ]; then
        rm -rf -- "/usr/local/${DB_Name}"
        rm -f /etc/my.cnf
        rm -f -- "/etc/init.d/${DB_Name}"
    fi

    if [ -s /usr/local/acme.sh/acme.sh ]; then
        /usr/local/acme.sh/acme.sh --uninstall
        rm -rf /usr/local/acme.sh
        if crontab -l|grep -v "/usr/local/acme.sh/upgrade.sh"; then
            crontab -l|grep -v "/usr/local/acme.sh/upgrade.sh" | crontab -
        fi
    fi

    rm -f /etc/my.cnf
    rm -f /etc/init.d/httpd
    rm -f /bin/lnmp
    echo "LAMP Uninstall completed."
}

    Check_Stack
    echo "Current Stack: ${Get_Stack}"

    action=""
    echo "Enter 1 to uninstall LNMP"
    echo "Enter 2 to uninstall LNMPA"
    echo "Enter 3 to uninstall LAMP"
    read -p "(Please input 1, 2 or 3): " action

    case "$action" in
    1|[lL][nN][nM][pP])
        echo "You will uninstall LNMP"
        Echo_Red "Please backup your configure files and mysql data!!!!!!"
        Echo_Red "The following directory or files will be remove!"
        cat << EOF
/usr/local/nginx
${MySQL_Dir}
/usr/local/php
/etc/init.d/nginx
/etc/init.d/${DB_Name}
/etc/init.d/php-fpm
/usr/local/zend
/etc/my.cnf
/bin/lnmp
EOF
        Sleep_Sec 3
        Press_Start
        Uninstall_LNMP
    ;;
    2|[lL][nN][nM][pP][aA])
        echo "You will uninstall LNMPA"
        Echo_Red "Please backup your configure files and mysql data!!!!!!"
        Echo_Red "The following directory or files will be remove!"
        cat << EOF
/usr/local/nginx
${MySQL_Dir}
/usr/local/php
/usr/local/apache
/etc/init.d/nginx
/etc/init.d/${DB_Name}
/etc/init.d/httpd
/usr/local/zend
/etc/my.cnf
/bin/lnmp
EOF
        Sleep_Sec 3
        Press_Start
        Uninstall_LNMPA
    ;;
    3|[lL][aA][nM][pP])
        echo "You will uninstall LAMP"
        Echo_Red "Please backup your configure files and mysql data!!!!!!"
        Echo_Red "The following directory or files will be remove!"
        cat << EOF
/usr/local/apache
${MySQL_Dir}
/etc/init.d/httpd
/etc/init.d/${DB_Name}
/usr/local/php
/usr/local/zend
/etc/my.cnf
/bin/lnmp
EOF
        Sleep_Sec 3
        Press_Start
        Uninstall_LAMP
    ;;
    esac
