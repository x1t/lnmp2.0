#!/usr/bin/env bash

DB_Info=('MySQL 5.1.73' 'MySQL 5.5.62' 'MySQL 5.6.51' 'MySQL 5.7.42' 'MySQL 8.0.46' 'MariaDB 5.5.68' 'MariaDB 10.4.29' 'MariaDB 10.5.20' 'MariaDB 10.6.13' 'MariaDB 10.11.3' 'MySQL 8.4.11' 'MySQL 9.7.2')
PHP_Info=('PHP 7.0.33' 'PHP 7.1.33' 'PHP 7.2.34' 'PHP 7.3.33' 'PHP 7.4.33' 'PHP 8.0.28' 'PHP 8.1.19' 'PHP 8.2.35' 'PHP 8.3.36' 'PHP 8.4.27' 'PHP 8.5.12')
Apache_Info=('Apache 2.2.34' 'Apache 2.4.57')

Is_MySQL_DB()
{
    case "${1:-${DBSelect}}" in
    1|2|3|4|5|11|12)
        return 0
        ;;
    *)
        return 1
        ;;
    esac
}

Is_MariaDB_DB()
{
    case "${1:-${DBSelect}}" in
    6|7|8|9|10)
        return 0
        ;;
    *)
        return 1
        ;;
    esac
}

Is_Modern_MySQL_DB()
{
    case "${1:-${DBSelect}}" in
    5|11|12)
        return 0
        ;;
    *)
        return 1
        ;;
    esac
}

Is_Modern_MySQL_Version()
{
    local version="${1:-${Mysql_Ver:-${mysql_version}}}"
    version="${version#mysql-}"
    case "${version}" in
    8.*|9.*)
        return 0
        ;;
    *)
        return 1
        ;;
    esac
}

Get_MySQL_Binary_File()
{
    local version="${1:-${Mysql_Ver:-}}"
    local arch="${2:-${DB_ARCH:-}}"
    local version_without_prefix="${version#mysql-}"
    local short_version="${version_without_prefix%.*}"
    local glibc_version
    local extension

    case "${short_version}" in
    5.5|5.6|5.7)
        glibc_version="2.12"
        extension="tar.gz"
        ;;
    8.0)
        glibc_version="2.28"
        extension="tar.xz"
        ;;
    8.*|9.*)
        glibc_version="2.28"
        extension="tar.xz"
        ;;
    *)
        return 1
        ;;
    esac

    printf 'mysql-%s-linux-glibc%s-%s.%s\n' \
        "${version_without_prefix}" "${glibc_version}" "${arch}" "${extension}"
}

Database_Selection()
{
#which MySQL Version do you want to install?
    if [ -z ${DBSelect} ]; then
        DBSelect="2"
        Echo_Yellow "You have 12 options for your DataBase install."
        echo "1: Install ${DB_Info[0]}"
        echo "2: Install ${DB_Info[1]} (Default)"
        echo "3: Install ${DB_Info[2]}"
        echo "4: Install ${DB_Info[3]}"
        echo "5: Install ${DB_Info[4]}"
        echo "6: Install ${DB_Info[5]}"
        echo "7: Install ${DB_Info[6]}"
        echo "8: Install ${DB_Info[7]}"
        echo "9: Install ${DB_Info[8]}"
        echo "10: Install ${DB_Info[9]}"
        echo "11: Install ${DB_Info[10]}"
        echo "12: Install ${DB_Info[11]}"
        echo "0: DO NOT Install MySQL/MariaDB"
        read -p "Enter your choice (1-12 or 0): " DBSelect
    fi

    case "${DBSelect}" in
    1)
        echo "You will install ${DB_Info[0]}"
        ;;
    2)
        if [[ "${DB_ARCH}" = "x86_64" || "${DB_ARCH}" = "i686" ]]; then
            if [ -z ${Bin} ]; then
                read -p "Using Generic Binaries [y/n]: " Bin
            fi
            case "${Bin}" in
            [yY][eE][sS]|[yY])
                echo "You will install ${DB_Info[1]} Using Generic Binaries."
                Bin="y"
                ;;
            [nN][oO]|[nN])
                echo "You will install ${DB_Info[1]} from Source."
                Bin="n"
                ;;
            *)
                Bin="n"
                ;;
            esac
        else
            echo "Default install ${DB_Info[1]} from Source."
            Bin="n"
        fi
        ;;
    3)
        if [[ "${DB_ARCH}" = "x86_64" || "${DB_ARCH}" = "i686" ]]; then
            if [ -z ${Bin} ]; then
                read -p "Using Generic Binaries [y/n]: " Bin
            fi
            case "${Bin}" in
            [yY][eE][sS]|[yY])
                echo "You will install ${DB_Info[2]} Using Generic Binaries."
                Bin="y"
                ;;
            [nN][oO]|[nN])
                echo "You will install ${DB_Info[2]} from Source."
                Bin="n"
                ;;
            *)
                if [ "${CheckMirror}" != "n" ]; then
                    echo "Default install ${DB_Info[2]} Using Generic Binaries."
                    Bin="y"
                else
                    echo "Default install ${DB_Info[2]} from Source."
                    Bin="n"
                fi
                ;;
            esac
        else
            Bin="n"
        fi
        ;;
    4)
        if [[ "${DB_ARCH}" = "x86_64" || "${DB_ARCH}" = "i686" ]]; then
            if [ -z ${Bin} ]; then
                read -p "Using Generic Binaries [y/n]: " Bin
            fi
            case "${Bin}" in
            [yY][eE][sS]|[yY])
                echo "You will install ${DB_Info[3]} Using Generic Binaries."
                Bin="y"
                ;;
            [nN][oO]|[nN])
                echo "You will install ${DB_Info[3]} from Source."
                Bin="n"
                ;;
            *)
                if [ "${CheckMirror}" != "n" ]; then
                    echo "Default install ${DB_Info[3]} Using Generic Binaries."
                    Bin="y"
                else
                    echo "Default install ${DB_Info[3]} from Source."
                    Bin="n"
                fi
                ;;
            esac
        else
            Bin="n"
        fi
        ;;
    5)
        if [[ "${DB_ARCH}" = "x86_64" || "${DB_ARCH}" = "aarch64" ]]; then
            if [ -z ${Bin} ]; then
                read -p "Using Generic Binaries [y/n]: " Bin
            fi
            case "${Bin}" in
            [yY][eE][sS]|[yY])
                echo "You will install ${DB_Info[4]} Using Generic Binaries."
                Bin="y"
                ;;
            [nN][oO]|[nN])
                echo "You will install ${DB_Info[4]} from Source."
                Bin="n"
                ;;
            *)
                if [ "${CheckMirror}" != "n" ]; then
                    echo "Default install ${DB_Info[4]} Using Generic Binaries."
                    Bin="y"
                else
                    echo "Default install ${DB_Info[4]} from Source."
                    Bin="n"
                fi
                ;;
            esac
        else
            Bin="n"
        fi
        ;;
    6)
        echo "You will install ${DB_Info[5]}"
        if [[ "${DB_ARCH}" = "x86_64" || "${DB_ARCH}" = "i686" ]]; then
            if [ -z ${Bin} ]; then
                read -p "Using Generic Binaries [y/n]: " Bin
            fi
            case "${Bin}" in
            [yY][eE][sS]|[yY])
                echo "You will install ${DB_Info[5]} Using Generic Binaries."
                Bin="y"
                ;;
            [nN][oO]|[nN])
                echo "You will install ${DB_Info[5]} from Source."
                Bin="n"
                ;;
            *)
                if [ "${CheckMirror}" != "n" ]; then
                    echo "Default install ${DB_Info[5]} Using Generic Binaries."
                    Bin="y"
                else
                    echo "Default install ${DB_Info[5]} from Source."
                    Bin="n"
                fi
                ;;
            esac
        else
            Bin="n"
        fi
        ;;
    7)
        echo "You will install ${DB_Info[6]}"
        if [[ "${DB_ARCH}" = "x86_64" || "${DB_ARCH}" = "i686" ]]; then
            if [ -z ${Bin} ]; then
                read -p "Using Generic Binaries [y/n]: " Bin
            fi
            case "${Bin}" in
            [yY][eE][sS]|[yY])
                echo "You will install ${DB_Info[6]} Using Generic Binaries."
                Bin="y"
                ;;
            [nN][oO]|[nN])
                echo "You will install ${DB_Info[6]} from Source."
                Bin="n"
                ;;
            *)
                if [ "${CheckMirror}" != "n" ]; then
                    echo "Default install ${DB_Info[6]} Using Generic Binaries."
                    Bin="y"
                else
                    echo "Default install ${DB_Info[6]} from Source."
                    Bin="n"
                fi
                ;;
            esac
        else
            Bin="n"
        fi
        ;;
    8)
        echo "You will install ${DB_Info[7]}"
        if [[ "${DB_ARCH}" = "x86_64" || "${DB_ARCH}" = "i686" ]]; then
            if [ -z ${Bin} ]; then
                read -p "Using Generic Binaries [y/n]: " Bin
            fi
            case "${Bin}" in
            [yY][eE][sS]|[yY])
                echo "You will install ${DB_Info[7]} Using Generic Binaries."
                Bin="y"
                ;;
            [nN][oO]|[nN])
                echo "You will install ${DB_Info[7]} from Source."
                Bin="n"
                ;;
            *)
                if [ "${CheckMirror}" != "n" ]; then
                    echo "Default install ${DB_Info[7]} Using Generic Binaries."
                    Bin="y"
                else
                    echo "Default install ${DB_Info[7]} from Source."
                    Bin="n"
                fi
                ;;
            esac
        else
            Bin="n"
        fi
        ;;
    9)
        echo "You will install ${DB_Info[8]}"
        if [[ "${DB_ARCH}" = "x86_64" ]]; then
            if [ -z ${Bin} ]; then
                read -p "Using Generic Binaries [y/n]: " Bin
            fi
            case "${Bin}" in
            [yY][eE][sS]|[yY])
                echo "You will install ${DB_Info[8]} Using Generic Binaries."
                Bin="y"
                ;;
            [nN][oO]|[nN])
                echo "You will install ${DB_Info[8]} from Source."
                Bin="n"
                ;;
            *)
                if [ "${CheckMirror}" != "n" ]; then
                    echo "Default install ${DB_Info[8]} Using Generic Binaries."
                    Bin="y"
                else
                    echo "Default install ${DB_Info[8]} from Source."
                    Bin="n"
                fi
                ;;
            esac
        else
            Bin="n"
        fi
        ;;
    10)
        echo "You will install ${DB_Info[9]}"
        if [[ "${DB_ARCH}" = "x86_64" ]]; then
            if [ -z ${Bin} ]; then
                read -p "Using Generic Binaries [y/n]: " Bin
            fi
            case "${Bin}" in
            [yY][eE][sS]|[yY])
                echo "You will install ${DB_Info[9]} Using Generic Binaries."
                Bin="y"
                ;;
            [nN][oO]|[nN])
                echo "You will install ${DB_Info[9]} from Source."
                Bin="n"
                ;;
            *)
                if [ "${CheckMirror}" != "n" ]; then
                    echo "Default install ${DB_Info[9]} Using Generic Binaries."
                    Bin="y"
                else
                    echo "Default install ${DB_Info[9]} from Source."
                    Bin="n"
                fi
                ;;
            esac
        else
            Bin="n"
        fi
        ;;
    11)
        echo "You will install ${DB_Info[10]}"
        if [[ "${DB_ARCH}" = "x86_64" || "${DB_ARCH}" = "aarch64" ]]; then
            if [ -z "${Bin}" ]; then
                read -p "Using Generic Binaries [y/n]: " Bin
            fi
            case "${Bin}" in
            [yY][eE][sS]|[yY])
                echo "You will install ${DB_Info[10]} Using Generic Binaries."
                Bin="y"
                ;;
            [nN][oO]|[nN])
                echo "You will install ${DB_Info[10]} from Source."
                Bin="n"
                ;;
            *)
                if [ "${CheckMirror}" != "n" ]; then
                    echo "Default install ${DB_Info[10]} Using Generic Binaries."
                    Bin="y"
                else
                    echo "Default install ${DB_Info[10]} from Source."
                    Bin="n"
                fi
                ;;
            esac
        else
            echo "Default install ${DB_Info[10]} from Source."
            Bin="n"
        fi
        ;;
    12)
        echo "You will install ${DB_Info[11]}"
        if [[ "${DB_ARCH}" = "x86_64" || "${DB_ARCH}" = "aarch64" ]]; then
            if [ -z "${Bin}" ]; then
                read -p "Using Generic Binaries [y/n]: " Bin
            fi
            case "${Bin}" in
            [yY][eE][sS]|[yY])
                echo "You will install ${DB_Info[11]} Using Generic Binaries."
                Bin="y"
                ;;
            [nN][oO]|[nN])
                echo "You will install ${DB_Info[11]} from Source."
                Bin="n"
                ;;
            *)
                if [ "${CheckMirror}" != "n" ]; then
                    echo "Default install ${DB_Info[11]} Using Generic Binaries."
                    Bin="y"
                else
                    echo "Default install ${DB_Info[11]} from Source."
                    Bin="n"
                fi
                ;;
            esac
        else
            echo "Default install ${DB_Info[11]} from Source."
            Bin="n"
        fi
        ;;
    0)
        echo "Do not install MySQL/MariaDB!"
        ;;
    *)
        echo "No input,You will install ${DB_Info[1]}"
        DBSelect="2"
    esac

    if [ "${Bin}" != "y" ] && { Is_Modern_MySQL_DB || Is_MariaDB_DB; } && [ $(awk '/MemTotal/ {printf( "%d\n", $2 / 1024 )}' /proc/meminfo) -le 1024 ]; then
        echo "Memory less than 1GB, can't install MySQL 8.0+ or MariaDB 10.3+!"
        exit 1
    fi

    if Is_MariaDB_DB; then
        MySQL_Bin="/usr/local/mariadb/bin/mysql"
        MySQL_Config="/usr/local/mariadb/bin/mysql_config"
        MySQL_Dir="/usr/local/mariadb"
    elif Is_MySQL_DB; then
        MySQL_Bin="/usr/local/mysql/bin/mysql"
        MySQL_Config="/usr/local/mysql/bin/mysql_config"
        MySQL_Dir="/usr/local/mysql"
    fi

    if [[ "${DBSelect}" != "0" ]]; then
        #set mysql root password
        if [ -z "${DB_Root_Password:-}" ]; then
            echo "==========================="
            Echo_Yellow "Please setup root password of MySQL."
            read -r -s -p "Please enter (input will not be shown): " DB_Root_Password
            printf '\n'
            if [ -z "${DB_Root_Password}" ]; then
                if command -v openssl >/dev/null 2>&1; then
                    DB_Root_Password=$(openssl rand -hex 24) || return 1
                else
                    DB_Root_Password=$(od -An -N24 -tx1 /dev/urandom | tr -d '[:space:]') || return 1
                fi
                if [ "${#DB_Root_Password}" -ne 48 ]; then
                    Echo_Red "Unable to generate a secure MySQL root password."
                    return 1
                fi
                if [ -w /dev/tty ]; then
                    printf 'Generated MySQL root password (not written to the install log): %s\n' "${DB_Root_Password}" >/dev/tty
                else
                    Echo_Red "No terminal is available to display the generated MySQL root password."
                    return 1
                fi
            fi
        fi
        echo "MySQL root password has been configured."

        #do you want to enable or disable the InnoDB Storage Engine?
        echo "==========================="

        if [ -z ${InstallInnodb} ]; then
            InstallInnodb="y"
            Echo_Yellow "Do you want to enable or disable the InnoDB Storage Engine?"
            read -p "Default enable,Enter your choice [Y/n]: " InstallInnodb
        fi

        case "${InstallInnodb}" in
        [yY][eE][sS]|[yY])
            echo "You will enable the InnoDB Storage Engine"
            InstallInnodb="y"
            ;;
        [nN][oO]|[nN])
            echo "You will disable the InnoDB Storage Engine!"
            InstallInnodb="n"
            ;;
        *)
            echo "No input,The InnoDB Storage Engine will enable."
            InstallInnodb="y"
        esac
    fi
}

PHP_Selection()
{
#which PHP Version do you want to install?
    if [ -z ${PHPSelect} ]; then
        echo "==========================="

        PHPSelect="11"
        Echo_Yellow "You have 11 options for your PHP install."
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
        echo "11: Install ${PHP_Info[10]} (Default)"
        read -p "Enter your choice (1, 2, 3, 4, 5, 6, 7, 8, 9, 10 or 11): " PHPSelect
    fi

    case "${PHPSelect}" in
    1)
        echo "You will install ${PHP_Info[0]}"
        if [[ "${DBSelect}" = 0 ]]; then
            echo "You didn't select MySQL/MariaDB can't select ${PHP_Info[0]}!"
            exit 1
        fi
        ;;
    2)
        echo "You will install ${PHP_Info[1]}"
        ;;
    3)
        echo "You will Install ${PHP_Info[2]}"
        ;;
    4)
        echo "You will install ${PHP_Info[3]}"
        ;;
    5)
        echo "You will install ${PHP_Info[4]}"
        ;;
    6)
        echo "You will install ${PHP_Info[5]}"
        ;;
    7)
        echo "You will install ${PHP_Info[6]}"
        ;;
    8)
        echo "You will install ${PHP_Info[7]}"
        ;;
    9)
        echo "You will install ${PHP_Info[8]}"
        ;;
    10)
        echo "You will install ${PHP_Info[9]}"
        ;;
    11)
        echo "You will install ${PHP_Info[10]}"
        ;;
    *)
        echo "No input,You will install ${PHP_Info[10]}"
        PHPSelect="11"
    esac
}

MemoryAllocator_Selection()
{
#which Memory Allocator do you want to install?
    if [ -z ${SelectMalloc} ]; then
        echo "==========================="

        SelectMalloc="1"
        Echo_Yellow "You have 3 options for your Memory Allocator install."
        echo "1: Don't install Memory Allocator. (Default)"
        echo "2: Install Jemalloc"
        echo "3: Install TCMalloc"
        read -p "Enter your choice (1, 2 or 3): " SelectMalloc
    fi

    case "${SelectMalloc}" in
    1)
        echo "You will install not install Memory Allocator."
        ;;
    2)
        echo "You will install JeMalloc"
        ;;
    3)
        echo "You will Install TCMalloc"
        ;;
    *)
        echo "No input,You will not install Memory Allocator."
        SelectMalloc="1"
    esac

    if [ "${SelectMalloc}" =  "1" ]; then
        MySQL51MAOpt=''
        MySQLMAOpt=''
        NginxMAOpt=''
    elif [ "${SelectMalloc}" =  "2" ]; then
        MySQL51MAOpt='--with-mysqld-ldflags=-ljemalloc'
        MySQLMAOpt='[mysqld_safe]
malloc-lib=/usr/lib/libjemalloc.so'
        NginxMAOpt="--with-ld-opt='-ljemalloc'"
    elif [ "${SelectMalloc}" =  "3" ]; then
        MySQL51MAOpt='--with-mysqld-ldflags=-ltcmalloc'
        MySQLMAOpt='[mysqld_safe]
malloc-lib=/usr/lib/libtcmalloc.so'
        NginxMAOpt='--with-google_perftools_module'
    fi
}

Dispaly_Selection()
{
    Database_Selection
    PHP_Selection
    MemoryAllocator_Selection
}

Apache_Selection()
{
    echo "==========================="
    #set Server Administrator Email Address
    if [ -z ${ServerAdmin} ]; then
        ServerAdmin=""
        read -p "Please enter Administrator Email Address: " ServerAdmin
    fi
    if [ "${ServerAdmin}" == "" ]; then
        echo "Administrator Email Address will set to webmaster@example.com!"
        ServerAdmin="webmaster@example.com"
    else
        echo "==========================="
        echo Server Administrator Email: "${ServerAdmin}"
        echo "==========================="
    fi
    echo "==========================="

#which Apache Version do you want to install?
    if [ -z ${ApacheSelect} ]; then
        ApacheSelect="1"
        Echo_Yellow "You have 2 options for your Apache install."
        echo "1: Install ${Apache_Info[0]}"
        echo "2: Install ${Apache_Info[1]} (Default)"
        read -p "Enter your choice (1 or 2): " ApacheSelect
    fi

    if [ "${ApacheSelect}" = "1" ]; then
        echo "You will install ${Apache_Info[0]}"
    elif [ "${ApacheSelect}" = "2" ]; then
        echo "You will install ${Apache_Info[1]}"
    else
        echo "No input,You will install ${Apache_Info[1]}"
        ApacheSelect="2"
    fi
    if [[ "${PHPSelect}" = "1" && "${ApacheSelect}" = "2" ]]; then
        Echo_Red "PHP 5.2.17 is not compatible with Apache 2.4.*."
        Echo_Red "Force use Apache 2.2.31"
        ApacheSelect="1"
    fi
}

Kill_PM()
{
    local package_manager pids current_pids

    pids=""
    for package_manager in yum dnf dnf5 apt apt-get dpkg packagekitd unattended-upgrade; do
        current_pids=$(ps -eo pid=,comm= | awk -v command="${package_manager}" '$2 == command { print $1 }')
        if [ -n "${current_pids}" ]; then
            pids="${pids} ${package_manager}:${current_pids}"
        fi
    done

    if [ -n "${pids//[[:space:]]/}" ]; then
        Echo_Red "A system package manager is already running:${pids}"
        Echo_Yellow "Stop the active package manager normally, then run LNMP again."
        return 1
    fi
    return 0
}

Press_Install()
{
    if [ -z ${LNMP_Auto} ]; then
        echo ""
        Echo_Green "Press any key to install...or Press Ctrl+c to cancel"
        OLDCONFIG=`stty -g`
        stty -icanon -echo min 1 time 0
        dd count=1 2>/dev/null
        stty ${OLDCONFIG}
    fi
    . include/version.sh
    Kill_PM || return 1
}

Press_Start()
{
    echo ""
    Echo_Green "Press any key to start...or Press Ctrl+c to cancel"
    OLDCONFIG=`stty -g`
    stty -icanon -echo min 1 time 0
    dd count=1 2>/dev/null
    stty ${OLDCONFIG}
}

Install_LSB()
{
    echo "[+] Installing lsb..."
    if [ "$PM" = "yum" ]; then
        yum -y install redhat-lsb
    elif [ "$PM" = "apt" ]; then
        apt-get update
        apt-get --no-install-recommends install -y lsb-release
    fi
}

Get_Dist_Version()
{
    if command -v lsb_release >/dev/null 2>&1; then
        DISTRO_Version=$(lsb_release -sr)
    elif [ -f /etc/lsb-release ]; then
        . /etc/lsb-release
        DISTRO_Version="$DISTRIB_RELEASE"
    elif [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO_Version="$VERSION_ID"
    fi
    if [[ "${DISTRO}" = "" || "${DISTRO_Version}" = "" ]]; then
        if command -v python2 >/dev/null 2>&1; then
            DISTRO_Version=$(python2 -c 'import platform; print platform.linux_distribution()[1]')
        elif command -v python3 >/dev/null 2>&1; then
            DISTRO_Version=$(python3 -c 'import platform; print(platform.linux_distribution()[1])')
        else
            Install_LSB
            DISTRO_Version=`lsb_release -rs`
        fi
    fi
    printf -v "${DISTRO}_Version" '%s' "${DISTRO_Version}"
}

Get_Dist_Name()
{
    if grep -Eqi "Alibaba" /etc/issue || grep -Eq "Alibaba Cloud Linux" /etc/*-release; then
        DISTRO='Alibaba'
        PM='yum'
    elif grep -Eqi "Aliyun" /etc/issue || grep -Eq "Aliyun Linux" /etc/*-release; then
        DISTRO='Aliyun'
        PM='yum'
    elif grep -Eqi "Amazon Linux" /etc/issue || grep -Eq "Amazon Linux" /etc/*-release; then
        DISTRO='Amazon'
        PM='yum'
    elif grep -Eqi "Fedora" /etc/issue || grep -Eq "Fedora" /etc/*-release; then
        DISTRO='Fedora'
        PM='yum'
    elif grep -Eqi "Oracle Linux" /etc/issue || grep -Eq "Oracle Linux" /etc/*-release; then
        DISTRO='Oracle'
        PM='yum'
    elif grep -Eqi "rockylinux" /etc/issue || grep -Eq "Rocky Linux" /etc/*-release; then
        DISTRO='Rocky'
        PM='yum'
    elif grep -Eqi "almalinux" /etc/issue || grep -Eq "AlmaLinux" /etc/*-release; then
        DISTRO='Alma'
        PM='yum'
    elif grep -Eqi "openEuler" /etc/issue || grep -Eq "openEuler" /etc/*-release; then
        DISTRO='openEuler'
        PM='yum'
    elif grep -Eqi "Anolis OS" /etc/issue || grep -Eq "Anolis OS" /etc/*-release; then
        DISTRO='Anolis'
        PM='yum'
    elif grep -Eqi "Kylin Linux Advanced Server" /etc/issue || grep -Eq "Kylin Linux Advanced Server" /etc/*-release; then
        DISTRO='Kylin'
        PM='yum'
    elif grep -Eqi "OpenCloudOS" /etc/issue || grep -Eq "OpenCloudOS" /etc/*-release; then
        DISTRO='OpenCloudOS'
        PM='yum'
    elif grep -Eqi "CentOS" /etc/issue || grep -Eq "CentOS" /etc/*-release; then
        DISTRO='CentOS'
        PM='yum'
        if grep -Eq "CentOS Stream" /etc/*-release; then
            isCentosStream='y'
        fi
    elif grep -Eqi "Red Hat Enterprise Linux" /etc/issue || grep -Eq "Red Hat Enterprise Linux" /etc/*-release; then
        DISTRO='RHEL'
        PM='yum'
    elif grep -Eqi "Ubuntu" /etc/issue || grep -Eq "Ubuntu" /etc/*-release; then
        DISTRO='Ubuntu'
        PM='apt'
    elif grep -Eqi "Raspbian" /etc/issue || grep -Eq "Raspbian" /etc/*-release; then
        DISTRO='Raspbian'
        PM='apt'
    elif grep -Eqi "Deepin" /etc/issue || grep -Eq "Deepin" /etc/*-release; then
        DISTRO='Deepin'
        PM='apt'
    elif grep -Eqi "Mint" /etc/issue || grep -Eq "Mint" /etc/*-release; then
        DISTRO='Mint'
        PM='apt'
    elif grep -Eqi "Kali" /etc/issue || grep -Eq "Kali" /etc/*-release; then
        DISTRO='Kali'
        PM='apt'
    elif grep -Eqi "Debian" /etc/issue || grep -Eq "Debian" /etc/*-release; then
        DISTRO='Debian'
        PM='apt'
    elif grep -Eqi "UnionTech OS" /etc/issue || grep -Eq "UnionTech OS" /etc/*-release; then
        DISTRO='UOS'
        if command -v apt >/dev/null 2>&1; then
            PM='apt'
        elif command -v yum >/dev/null 2>&1; then
            PM='yum'
        fi
    elif grep -Eqi "Kylin Linux Desktop" /etc/issue || grep -Eq "Kylin Linux Desktop" /etc/*-release; then
        DISTRO='Kylin'
        PM='apt'
    else
        DISTRO='unknow'
    fi
    Get_OS_Bit
}

Get_RHEL_Version()
{
    Get_Dist_Name
    if [ "${DISTRO}" = "RHEL" ]; then
        if grep -Eqi "release 5." /etc/redhat-release; then
            echo "Current Version: RHEL Ver 5"
            RHEL_Ver='5'
        elif grep -Eqi "release 6." /etc/redhat-release; then
            echo "Current Version: RHEL Ver 6"
            RHEL_Ver='6'
        elif grep -Eqi "release 7." /etc/redhat-release; then
            echo "Current Version: RHEL Ver 7"
            RHEL_Ver='7'
        elif grep -Eqi "release 8." /etc/redhat-release; then
            echo "Current Version: RHEL Ver 8"
            RHEL_Ver='8'
        elif grep -Eqi "release 9." /etc/redhat-release; then
            echo "Current Version: RHEL Ver 9"
            RHEL_Ver='9'
        fi
        RHEL_Version="$(cat /etc/redhat-release | sed 's/.*release\ //' | sed 's/\ .*//')"
    fi
}

Get_OS_Bit()
{
    if [[ `getconf WORD_BIT` = '32' && `getconf LONG_BIT` = '64' ]] ; then
        Is_64bit='y'
        ARCH='x86_64'
        DB_ARCH='x86_64'
    else
        Is_64bit='n'
        ARCH='i386'
        DB_ARCH='i686'
    fi

    if uname -m | grep -Eqi "arm|aarch64"; then
        Is_ARM='y'
        if uname -m | grep -Eqi "armv7|armv6"; then
            ARCH='armhf'
        elif uname -m | grep -Eqi "aarch64"; then
            ARCH='aarch64'
            DB_ARCH='aarch64'
        else
            ARCH='arm'
        fi
    fi
}

Download_Files()
{
    local URL="$1"
    local FileName="$2"
    local Expected_SHA256="${3:-}"

    if [ -z "${URL}" ] || [ -z "${FileName}" ]; then
        Echo_Red "Download failed: URL and output file are required."
        return 1
    fi
    if ! Validate_Download_URL "${URL}"; then
        return 1
    fi

    if [ -z "${Expected_SHA256}" ]; then
        Expected_SHA256=$(Get_Source_Checksum "${FileName}") || true
    fi
    Expected_SHA256=$(printf '%s' "${Expected_SHA256}" | tr '[:upper:]' '[:lower:]')
    if ! [[ "${Expected_SHA256}" =~ ^[0-9a-f]{64}$ ]]; then
        Echo_Red "Download refused: no trusted SHA256 entry for $(basename -- "${FileName}")."
        return 1
    fi

    if [ -s "${FileName}" ]; then
        if Verify_Source_Checksum "${FileName}" "${Expected_SHA256}"; then
            echo "${FileName} [verified]"
            return 0
        fi
        Echo_Yellow "${FileName} failed SHA256 verification; removing it."
        rm -f -- "${FileName}" || return 1
    fi

    local TempFile="${FileName}.part"
    rm -f -- "${TempFile}" || return 1
    echo "Notice: ${FileName} not found or not verified; downloading over HTTPS..."
    if ! wget --https-only --progress=dot -e dotbytes=20M --prefer-family=IPv4 -T 120 -t 3 --max-redirect=3 -O "${TempFile}" "${URL}"; then
        rm -f -- "${TempFile}"
        Echo_Red "Download failed: ${URL}"
        return 1
    fi
    if ! Verify_Source_Checksum "${TempFile}" "${Expected_SHA256}"; then
        rm -f -- "${TempFile}"
        return 1
    fi
    mv -f -- "${TempFile}" "${FileName}" || return 1
    echo "${FileName} [SHA256 verified]"
}

Get_Source_Checksum()
{
    local FileName="$1"
    local Checksum_File="${cur_dir}/${Source_Checksum_File:-checksums.sha256}"
    [ -r "${Checksum_File}" ] || return 1
    awk -v name="$(basename -- "${FileName}")" '
        /^[[:space:]]*#/ || NF < 2 { next }
        {
            manifest_name = $2
            sub(/^.*\//, "", manifest_name)
        }
        manifest_name == name {
            print tolower($1)
            found = 1
            exit
        }
        END {
            if (!found) {
                exit 1
            }
        }
    ' "${Checksum_File}"
}

Check_Core_Source_Manifest()
{
    local -a required_sources=()
    local source_name missing=0
    local mysql_binary_file

    required_sources+=("${Libiconv_Ver}.tar.gz" "${Pcre_Ver}.tar.bz2" "${Php_Ver}.tar.bz2" "${Freetype_Ver}.tar.bz2" "${Freetype_New_Ver}.tar.xz")
    required_sources+=("${Curl_Ver}.tar.bz2" "${Libicu4c_Ver}-src.tgz" "icu4c-60_3-src.tgz" "${Libzip_Ver}.tar.xz" "${Nghttp2_Ver}.tar.xz" "${Openssl_Ver}.tar.gz" "${Openssl_New_Ver}.tar.gz")
    PhpMyAdmin_Version="${PhpMyAdmin_Ver#phpMyAdmin-}"
    PhpMyAdmin_Version="${PhpMyAdmin_Version%%-*}"
    required_sources+=("${PhpMyAdmin_Ver}.tar.xz")

    if [[ "${PHPSelect}" =~ ^[1-5]$ ]]; then
        required_sources+=("${LibMcrypt_Ver}.tar.bz2" "${Mcypt_Ver}.tar.gz" "${Mhash_Ver}.tar.bz2")
    fi

    if [ "${SelectMalloc}" = "2" ]; then
        required_sources+=("${Jemalloc_Ver}.tar.bz2")
    elif [ "${SelectMalloc}" = "3" ]; then
        required_sources+=("${TCMalloc_Ver}.tar.gz" "${Libunwind_Ver}.tar.gz")
    fi

    if [ "${DBSelect}" = "4" ]; then
        required_sources+=("${Boost_Ver}.tar.bz2")
    elif Is_Modern_MySQL_DB; then
        required_sources+=("boost_1_77_0.tar.bz2" "boost_1_87_0.tar.bz2")
    fi

    if [ "${Enable_Nginx_Lua}" = "y" ]; then
        required_sources+=("${Luajit_Ver}.tar.gz" "${LuaNginxModule}.tar.gz" "${NgxDevelKit}.tar.gz" "${LuaRestyCore}.tar.gz" "${LuaRestyLrucache}.tar.gz")
    fi
    if [ "${Enable_Ngx_FancyIndex}" = "y" ]; then
        required_sources+=("${NgxFancyIndex_Ver}.tar.xz")
    fi

    if [ "${Stack}" != "lamp" ]; then
        required_sources+=("${Nginx_Ver}.tar.gz")
    fi

    if Is_MySQL_DB; then
        if [ "${Bin}" = "y" ]; then
            if [[ "${DBSelect}" =~ ^[2-4]$ ]]; then
                required_sources+=("${Mysql_Ver}-linux-glibc2.12-${DB_ARCH}.tar.gz")
            else
                mysql_binary_file=$(Get_MySQL_Binary_File "${Mysql_Ver}" "${DB_ARCH}") || return 1
                required_sources+=("${mysql_binary_file}")
            fi
        else
            required_sources+=("${Mysql_Ver}.tar.gz")
        fi
    elif Is_MariaDB_DB; then
        Mariadb_Version="${Mariadb_Ver#*-}"
        if [ "${Bin}" = "y" ]; then
            required_sources+=("${Mariadb_Ver}-linux-systemd-${DB_ARCH}.tar.gz")
        else
            required_sources+=("${Mariadb_Ver}.tar.gz")
        fi
    fi

    if [ "${Stack}" != "lnmp" ]; then
        required_sources+=("${Apache_Ver}.tar.bz2" "${APR_Ver}.tar.bz2" "${APR_Util_Ver}.tar.bz2")
    fi

    for source_name in "${required_sources[@]}"; do
        if ! Get_Source_Checksum "${source_name}" >/dev/null 2>&1; then
            Echo_Red "Missing trusted SHA256 entry: ${source_name}"
            missing=1
        fi
    done

    if [ "${missing}" -ne 0 ]; then
        Echo_Red "Installation stopped before system changes because one or more source checksums are missing."
        return 1
    fi
    return 0
}

Verify_Source_Checksum()
{
    local FileName="$1"
    local Expected_SHA256="$2"
    local Actual_SHA256

    if [ -L "${FileName}" ]; then
        Echo_Red "Checksum refused for symbolic link: ${FileName}."
        return 1
    fi
    if [ ! -s "${FileName}" ]; then
        Echo_Red "Checksum failed: ${FileName} is missing or empty."
        return 1
    fi
    Actual_SHA256=$(sha256sum -- "${FileName}" | awk '{print tolower($1)}') || return 1
    if [ "${Actual_SHA256}" != "${Expected_SHA256}" ]; then
        Echo_Red "SHA256 mismatch for ${FileName}."
        echo "Expected: ${Expected_SHA256}"
        echo "Actual:   ${Actual_SHA256}"
        return 1
    fi
    return 0
}

Require_Verified_Source_Archive()
{
    local FileName="$1"
    local Expected_SHA256="${2:-}"

    if [ -z "${Expected_SHA256}" ]; then
        Expected_SHA256=$(Get_Source_Checksum "${FileName}") || {
            Echo_Red "Archive refused: no trusted SHA256 entry for $(basename -- "${FileName}")."
            return 1
        }
    fi
    Expected_SHA256=$(printf '%s' "${Expected_SHA256}" | tr '[:upper:]' '[:lower:]')
    if ! [[ "${Expected_SHA256}" =~ ^[0-9a-f]{64}$ ]]; then
        Echo_Red "Archive refused: invalid SHA256 entry for $(basename -- "${FileName}")."
        return 1
    fi
    Verify_Source_Checksum "${FileName}" "${Expected_SHA256}"
}

Validate_Download_URL()
{
    local URL="$1"
    local Host

    if [[ "${URL}" != https://* ]]; then
        Echo_Red "Download refused: only HTTPS sources are allowed: ${URL}"
        return 1
    fi

    Host="${URL#https://}"
    Host="${Host%%/*}"
    Host="${Host%%:*}"
    Host="${Host,,}"
    case "${Host}" in
        archive.apache.org|archives.boost.io|cdn.mysql.com|curl.se|dev.mysql.com|download.pureftpd.org|download.redis.io|download.savannah.nongnu.org|downloads.mariadb.org|downloads.sourceforge.net|files.phpmyadmin.net|getcomposer.org|github.com|libzip.org|mirror.cs.uchicago.edu|mirror.math.princeton.edu|mirrors.mit.edu|museum.php.net|nginx.org|pecl.php.net|raw.githubusercontent.com|sourceforge.net|www.openssl.org|www.php.net)
            return 0
            ;;
        *)
            Echo_Red "Download refused: source host is not allowlisted: ${Host}"
            return 1
            ;;
    esac
}

Validate_Archive_Entries()
{
    local FileName="$1"
    local extension="${FileName##*.}"
    local ListFile MetadataFile

    [ -f "${FileName}" ] || {
        Echo_Red "Archive validation failed: ${FileName} is missing."
        return 1
    }

    ListFile=$(mktemp "${TMPDIR:-/tmp}/lnmp-archive.XXXXXX") || return 1
    case "${extension}" in
        gz|tgz)
            LC_ALL=C tar --list --gzip --file "${FileName}" > "${ListFile}"
            ;;
        bz2)
            LC_ALL=C tar --list --bzip2 --file "${FileName}" > "${ListFile}"
            ;;
        xz)
            LC_ALL=C tar --list --xz --file "${FileName}" > "${ListFile}"
            ;;
        *)
            rm -f -- "${ListFile}"
            Echo_Red "Unsupported archive format: ${FileName}"
            return 1
            ;;
    esac
    if [ "$?" -ne 0 ]; then
        rm -f -- "${ListFile}"
        Echo_Red "Archive listing failed: ${FileName}"
        return 1
    fi

    if awk '
        $0 ~ /^\// || $0 ~ /(^|\/)\.\.(\/|$)/ {
            print "unsafe archive path: " $0 > "/dev/stderr"
            bad = 1
        }
        END { exit bad }
    ' "${ListFile}"; then
        MetadataFile=$(mktemp "${TMPDIR:-/tmp}/lnmp-archive-meta.XXXXXX") || {
            rm -f -- "${ListFile}"
            return 1
        }
        case "${extension}" in
            gz|tgz)
                LC_ALL=C tar --list --verbose --gzip --file "${FileName}" > "${MetadataFile}"
                ;;
            bz2)
                LC_ALL=C tar --list --verbose --bzip2 --file "${FileName}" > "${MetadataFile}"
                ;;
            xz)
                LC_ALL=C tar --list --verbose --xz --file "${FileName}" > "${MetadataFile}"
                ;;
        esac
        if [ "$?" -ne 0 ]; then
            rm -f -- "${ListFile}" "${MetadataFile}"
            Echo_Red "Archive metadata listing failed: ${FileName}"
            return 1
        fi
        if awk '
            function unsafe_path(path) {
                return path ~ /^\// || path ~ /(^|\/)\.\.(\/|$)/
            }
            $1 !~ /^[dhl-]/ {
                print "archive special files are not allowed: " $0 > "/dev/stderr"
                bad = 1
            }
            $1 ~ /^l/ {
                marker = index($0, " -> ")
                if (marker == 0) {
                    print "archive symbolic-link metadata is invalid: " $0 > "/dev/stderr"
                    bad = 1
                } else {
                    target = substr($0, marker + 4)
                    if (unsafe_path(target)) {
                        print "unsafe archive link target: " target > "/dev/stderr"
                        bad = 1
                    }
                }
            }
            $1 ~ /^h/ {
                marker = index($0, " link to ")
                if (marker == 0) {
                    print "archive hard-link metadata is invalid: " $0 > "/dev/stderr"
                    bad = 1
                } else {
                    target = substr($0, marker + 9)
                    if (unsafe_path(target)) {
                        print "unsafe archive link target: " target > "/dev/stderr"
                        bad = 1
                    }
                }
            }
            END { exit bad }
        ' "${MetadataFile}"; then
            rm -f -- "${ListFile}" "${MetadataFile}"
            return 0
        fi
        rm -f -- "${ListFile}" "${MetadataFile}"
        Echo_Red "Archive rejected because it contains a symbolic or hard link: ${FileName}"
        return 1
    fi
    rm -f -- "${ListFile}"
    Echo_Red "Archive rejected because it contains an absolute or parent-directory path: ${FileName}"
    return 1
}

Extract_Archive()
{
    local FileName="$1"
    local TargetDir="${2:-.}"
    local Expected_SHA256="${3:-}"
    local extension="${FileName##*.}"

    Require_Verified_Source_Archive "${FileName}" "${Expected_SHA256}" || return 1
    Validate_Archive_Entries "${FileName}" || return 1
    [ -d "${TargetDir}" ] || {
        Echo_Red "Archive extraction directory does not exist: ${TargetDir}"
        return 1
    }
    case "${extension}" in
        gz|tgz)
            tar --no-same-owner --no-same-permissions --directory "${TargetDir}" --extract --gzip --file "${FileName}"
            ;;
        bz2)
            tar --no-same-owner --no-same-permissions --directory "${TargetDir}" --extract --bzip2 --file "${FileName}"
            ;;
        xz)
            tar --no-same-owner --no-same-permissions --directory "${TargetDir}" --extract --xz --file "${FileName}"
            ;;
        *)
            Echo_Red "Unsupported archive format: ${FileName}"
            return 1
            ;;
    esac
}

Validate_Zip_Entries()
{
    local FileName="$1"
    local ListFile

    [ -f "${FileName}" ] || {
        Echo_Red "ZIP validation failed: ${FileName} is missing."
        return 1
    }
    ListFile=$(mktemp "${TMPDIR:-/tmp}/lnmp-zip.XXXXXX") || return 1
    if ! unzip -Z1 "${FileName}" > "${ListFile}"; then
        rm -f -- "${ListFile}"
        Echo_Red "ZIP listing failed: ${FileName}"
        return 1
    fi
    if awk '
        $0 ~ /^\// || $0 ~ /(^|\/)\.\.(\/|$)/ {
            print "unsafe ZIP path: " $0 > "/dev/stderr"
            bad = 1
        }
        END { exit bad }
    ' "${ListFile}"; then
        rm -f -- "${ListFile}"
        return 0
    fi
    rm -f -- "${ListFile}"
    Echo_Red "ZIP rejected because it contains an absolute or parent-directory path: ${FileName}"
    return 1
}

Extract_Zip()
{
    local FileName="$1"
    local TargetDir="${2:-.}"
    local Expected_SHA256="${3:-}"

    Require_Verified_Source_Archive "${FileName}" "${Expected_SHA256}" || return 1
    Validate_Zip_Entries "${FileName}" || return 1
    mkdir -p -- "${TargetDir}" || return 1
    unzip -q "${FileName}" -d "${TargetDir}"
}

Tar_Cd()
{
    local FileName="$1"
    local DirName="${2:-}"
    cd "${cur_dir}/src" || return 1
    if [ -n "${DirName}" ] && [ -d "${DirName}" ]; then
        rm -rf -- "${DirName}" || return 1
    fi
    echo "Uncompress ${FileName}..."
    Extract_Archive "${FileName}" || return 1
    if [ -n "${DirName}" ]; then
        if [ ! -d "${DirName}" ]; then
            echo "Archive did not contain expected directory: ${DirName}" >&2
            return 1
        fi
        echo "cd ${DirName}..."
        cd "${DirName}" || return 1
    fi
}

Check_LNMPConf()
{
    if [ ! -s "${cur_dir}/lnmp.conf" ]; then
        Echo_Red "lnmp.conf was not exsit!"
        exit 1
    fi
    if [[ "${University_Mirror:-}" = "" || "${Download_Mirror}" = "" || "${MySQL_Data_Dir}" = "" || "${MariaDB_Data_Dir}" = "" || "${Default_Website_Dir}" = "" ]]; then
        Echo_Red "Can't get values from lnmp.conf!"
        exit 1
    fi
    if ! Validate_Download_URL "${University_Mirror}/" || ! Validate_Download_URL "${Download_Mirror}/"; then
        Echo_Red "Download mirrors must use HTTPS and an allowlisted public source host."
        exit 1
    fi
    if [[ "${MySQL_Data_Dir}" = "/" || "${MariaDB_Data_Dir}" = "/" || "${Default_Website_Dir}" = "/" ]]; then
        Echo_Red "Can't set MySQL/MariaDB/Website Directory to / !"
        exit 1
    fi
}

Print_APP_Ver()
{
    echo "You will install ${Stack} stack."
    if [ "${Stack}" != "lamp" ]; then
        echo "${Nginx_Ver}"
    fi

    if Is_MySQL_DB; then
        echo "${Mysql_Ver}"
    elif Is_MariaDB_DB; then
        echo "${Mariadb_Ver}"
    elif [ "${DBSelect}" = "0" ]; then
        echo "Do not install MySQL/MariaDB!"
    fi

    echo "${Php_Ver}"

    if [ "${Stack}" != "lnmp" ]; then
        echo "${Apache_Ver}"
    fi

    if [ "${SelectMalloc}" = "2" ]; then
        echo "${Jemalloc_Ver}"
    elif [ "${SelectMalloc}" = "3" ]; then
        echo "${TCMalloc_Ver}"
    fi
    echo "Enable InnoDB: ${InstallInnodb}"
    echo "Print lnmp.conf infomation..."
    echo "Download Mirror: ${Download_Mirror}"
    echo "Nginx Additional Modules: ${Nginx_Modules_Options}"
    echo "PHP Additional Modules: ${PHP_Modules_Options}"
    if [ "${Enable_PHP_Fileinfo}" = "y" ]; then
        echo "enable PHP fileinfo."
    fi
    if [ "${Enable_Nginx_Lua}" = "y" ]; then
        echo "enable Nginx Lua."
    fi
    if Is_MySQL_DB; then
        echo "Database Directory: ${MySQL_Data_Dir}"
    elif Is_MariaDB_DB; then
        echo "Database Directory: ${MariaDB_Data_Dir}"
    elif [ "${DBSelect}" = "0" ]; then
        echo "Do not install MySQL/MariaDB!"
    fi
    echo "Default Website Directory: ${Default_Website_Dir}"
}

Print_Sys_Info()
{
    echo "LNMP Version: ${LNMP_Ver}"
    local version_var="${DISTRO}_Version"
    printf '%s %s\n' "${DISTRO}" "${!version_var:-unknown}"
    cat /etc/issue
    cat /etc/*-release
    uname -a
    MemTotal=$(awk '/MemTotal/ {printf( "%d\n", $2 / 1024 )}' /proc/meminfo)
    echo "Memory is: ${MemTotal} MB "
    df -h
    Check_Openssl
    Check_WSL
    Check_Docker
    if [ "${CheckMirror}" != "n" ]; then
        Get_Country
        echo "Server Location: ${country}"
    fi
}

StartUp()
{
    init_name=$1
    echo "Add ${init_name} service at system startup..."
    if [ "${isWSL}" = "n" ] && [ "${isDocker}" = "n" ] && command -v systemctl >/dev/null 2>&1 && [[ -s /etc/systemd/system/${init_name}.service || -s /lib/systemd/system/${init_name}.service || -s /usr/lib/systemd/system/${init_name}.service ]]; then
        systemctl daemon-reload
        systemctl enable ${init_name}.service
    else
        if [ "$PM" = "yum" ]; then
            chkconfig --add ${init_name}
            chkconfig ${init_name} on
        elif [ "$PM" = "apt" ]; then
            update-rc.d -f ${init_name} defaults
        fi
    fi
}

Remove_StartUp()
{
    init_name=$1
    echo "Removing ${init_name} service at system startup..."
    if [ "${isWSL}" = "n" ] && [ "${isDocker}" = "n" ] && command -v systemctl >/dev/null 2>&1 && [[ -s /etc/systemd/system/${init_name}.service || -s /lib/systemd/system/${init_name}.service || -s /usr/lib/systemd/system/${init_name}.service ]]; then
        systemctl disable ${init_name}.service
    else
        if [ "$PM" = "yum" ]; then
            chkconfig ${init_name} off
            chkconfig --del ${init_name}
        elif [ "$PM" = "apt" ]; then
            update-rc.d -f ${init_name} remove
        fi
    fi
}

Get_Country()
{
    # Simple country detection based on timezone
    if [ -f /etc/timezone ]; then
        timezone=$(cat /etc/timezone)
        if echo "$timezone" | grep -q "Asia/Shanghai\|Asia/Chongqing\|Asia/Hong_Kong"; then
            country="CN"
        else
            country="US"
        fi
    else
        # Default to US if unable to detect
        country="US"
    fi
}

Check_Mirror()
{
    if ! command -v curl >/dev/null 2>&1; then
        if [ "$PM" = "yum" ]; then
            yum install -y curl
        elif [ "$PM" = "apt" ]; then
            export DEBIAN_FRONTEND=noninteractive
            apt-get update
            apt-get install -y curl
        fi
    fi
    # Use official sources directly, no mirror switching needed
    echo "Using official download sources for security"
}

Check_CMPT()
{
    if Is_Modern_MySQL_DB; then
        if echo "${Ubuntu_Version}" | grep -Eqi "^1[0-7]\." || echo "${Debian_Version}" | grep -Eqi "^[4-8]" || echo "${Raspbian_Version}" | grep -Eqi "^[4-8]" || echo "${CentOS_Version}" | grep -Eqi "^[4-7]"  || echo "${RHEL_Version}" | grep -Eqi "^[4-7]" || echo "${Fedora_Version}" | grep -Eqi "^2[0-3]"; then
            Echo_Red "MySQL 8.0+ please use latest Linux distributions!"
            exit 1
        fi
    fi
    if [[ "${PHPSelect}" =~ ^1[0-2]$ ]]; then
        if echo "${Ubuntu_Version}" | grep -Eqi "^1[0-7]\." || echo "${Debian_Version}" | grep -Eqi "^[4-8]" || echo "${Raspbian_Version}" | grep -Eqi "^[4-8]" || echo "${CentOS_Version}" | grep -Eqi "^[4-6]"  || echo "${RHEL_Version}" | grep -Eqi "^[4-6]" || echo "${Fedora_Version}" | grep -Eqi "^2[0-3]"; then
            Echo_Red "PHP 7.4 and PHP 8.* please use latest linux distributions!"
            exit 1
        fi
    fi
    if [[ "${PHPSelect}" = "1" ]]; then
        if echo "${Ubuntu_Version}" | grep -Eqi "^19|2[0-7]\." || echo "${Debian_Version}" | grep -Eqi "^1[0-9]" || echo "${Raspbian_Version}" | grep -Eqi "^1[0-9]" || echo "${Deepin_Version}" | grep -Eqi "^2[0-9]" || echo "${UOS_Version}" | grep -Eqi "^2[0-9]" || echo "${Fedora_Version}" | grep -Eqi "^29|3[0-9]"; then
            Echo_Red "PHP 5.2 is not supported on very new linux versions such as Ubuntu 19+, Debian 10, Deepin 20+, Fedora 29+ etc."
            exit 1
        fi
    fi
}

Color_Text()
{
  echo -e " \e[0;$2m$1\e[0m"
}

Echo_Red()
{
  echo $(Color_Text "$1" "31")
}

Echo_Green()
{
  echo $(Color_Text "$1" "32")
}

Echo_Yellow()
{
  echo $(Color_Text "$1" "33")
}

Echo_Blue()
{
  echo $(Color_Text "$1" "34")
}

Get_PHP_Ext_Dir()
{
    Cur_PHP_Version="`/usr/local/php/bin/php-config --version`"
    zend_ext_dir="`/usr/local/php/bin/php-config --extension-dir`/"
}

Check_Stack()
{
    if [[ -s /usr/local/php/sbin/php-fpm && -s /usr/local/php/etc/php-fpm.conf && -s /etc/init.d/php-fpm && -s /usr/local/nginx/sbin/nginx ]]; then
        Get_Stack="lnmp"
    elif [[ -s /usr/local/nginx/sbin/nginx && -s /usr/local/apache/bin/httpd && -s /usr/local/apache/conf/httpd.conf && -s /etc/init.d/httpd && ! -s /usr/local/php/sbin/php-fpm ]]; then
        Get_Stack="lnmpa"
    elif [[ -s /usr/local/apache/bin/httpd && -s /usr/local/apache/conf/httpd.conf && -s /etc/init.d/httpd && ! -s /usr/local/php/sbin/php-fpm ]]; then
        Get_Stack="lamp"
    else
        Get_Stack="unknow"
    fi
}

Check_DB()
{
    if [[ -s /usr/local/mariadb/bin/mysql && -s /usr/local/mariadb/bin/mysqld_safe && -s /etc/my.cnf ]]; then
        MySQL_Bin="/usr/local/mariadb/bin/mysql"
        MySQL_Config="/usr/local/mariadb/bin/mysql_config"
        MySQL_Dir="/usr/local/mariadb"
        Is_MySQL="n"
        DB_Name="mariadb"
    elif [[ -s /usr/local/mysql/bin/mysql && -s /usr/local/mysql/bin/mysqld_safe && -s /etc/my.cnf ]]; then
        MySQL_Bin="/usr/local/mysql/bin/mysql"
        MySQL_Config="/usr/local/mysql/bin/mysql_config"
        MySQL_Dir="/usr/local/mysql"
        Is_MySQL="y"
        DB_Name="mysql"
    else
        Is_MySQL="None"
        DB_Name="None"
    fi
}

Run_DB_Query()
{
    local query="$1"
    shift
    local query_file query_status

    [ "$#" -gt 0 ] || return 2
    query_file=$(mktemp "${TMPDIR:-/tmp}/lnmp-db-query.XXXXXX") || return 1
    chmod 600 "${query_file}" || {
        rm -f -- "${query_file}"
        return 1
    }
    printf '%s\n' "${query}" >"${query_file}" || {
        rm -f -- "${query_file}"
        return 1
    }
    "$@" <"${query_file}"
    query_status=$?
    rm -f -- "${query_file}"
    return "${query_status}"
}

Escape_SQL_String()
{
    local value="$1"

    value="${value//\\/\\\\}"
    value="${value//\'/\'\'}"
    printf '%s' "${value}"
}

Do_Query()
{
    local defaults_file

    Check_DB
    defaults_file="${HOME:-/root}/.my.cnf"
    Run_DB_Query "$1" "${MySQL_Bin}" "--defaults-file=${defaults_file}"
}

Make_TempMycnf()
{
    local mycnf="${HOME:-/root}/.my.cnf"
    local escaped_password="${1//\\/\\\\}"
    escaped_password="${escaped_password//\"/\\\"}"

    if [ -L "${mycnf}" ]; then
        Echo_Red "Refusing to write database credentials through a symbolic link: ${mycnf}"
        return 1
    fi
    if [ -e "${mycnf}" ] && [ ! -f "${mycnf}" ]; then
        Echo_Red "Refusing to replace a non-regular database option path: ${mycnf}"
        return 1
    fi
    if [ "${MYSQL_TEMP_CNF_BACKED_UP:-0}" -eq 0 ]; then
        if [ -e "${mycnf}" ] || [ -L "${mycnf}" ]; then
            MYSQL_TEMP_CNF_BACKUP=$(mktemp "${mycnf}.lnmp-backup.XXXXXX") || return 1
            if ! cp -p -- "${mycnf}" "${MYSQL_TEMP_CNF_BACKUP}"; then
                rm -f -- "${MYSQL_TEMP_CNF_BACKUP}"
                MYSQL_TEMP_CNF_BACKUP=""
                return 1
            fi
            chmod 600 "${MYSQL_TEMP_CNF_BACKUP}" || return 1
        else
            MYSQL_TEMP_CNF_BACKUP=""
        fi
        MYSQL_TEMP_CNF_BACKED_UP=1
    fi

    umask 077
    printf '[client]\nuser=root\npassword="%s"\n' "${escaped_password}" >"${mycnf}" || return 1
    chmod 600 "${mycnf}" || return 1
}

Make_Empty_TempMycnf()
{
    local temp_file

    temp_file=$(mktemp "${TMPDIR:-/tmp}/lnmp-empty-mysql.XXXXXX") || return 1
    if ! printf '%s\n' '[client]' 'user=root' "password=''" >"${temp_file}"; then
        rm -f -- "${temp_file}"
        return 1
    fi
    chmod 600 "${temp_file}" || {
        rm -f -- "${temp_file}"
        return 1
    }
    printf '%s\n' "${temp_file}"
}

Make_Temporary_DB_Option_File()
{
    local temp_file escaped_password

    escaped_password="${1//\\/\\\\}"
    escaped_password="${escaped_password//\"/\\\"}"
    temp_file=$(mktemp "${TMPDIR:-/tmp}/lnmp-db-options.XXXXXX") || return 1
    if ! printf '[client]\nuser=root\npassword="%s"\n' "${escaped_password}" >"${temp_file}"; then
        rm -f -- "${temp_file}"
        return 1
    fi
    chmod 600 "${temp_file}" || {
        rm -f -- "${temp_file}"
        return 1
    }
    printf '%s\n' "${temp_file}"
}

Verify_DB_Password()
{
    Check_DB
    status=1
    while [ $status -eq 1 ]; do
        if ! read -r -s -p "Enter current root password of Database (Password will not shown): " DB_Root_Password; then
            printf '\nError: input stream closed.\n' >&2
            return 1
        fi
        printf '\n'
        Make_TempMycnf "${DB_Root_Password}" || return 1
        Do_Query ""
        status=$?
    done
    echo "OK, MySQL root password correct."
}

TempMycnf_Clean()
{
    local mycnf="${HOME:-/root}/.my.cnf"

    if [ "${MYSQL_TEMP_CNF_BACKED_UP:-0}" -eq 1 ]; then
        if [ -n "${MYSQL_TEMP_CNF_BACKUP:-}" ] && [ -e "${MYSQL_TEMP_CNF_BACKUP}" ]; then
            rm -f -- "${mycnf}" || return 1
            mv -f -- "${MYSQL_TEMP_CNF_BACKUP}" "${mycnf}" || return 1
        else
            rm -f -- "${mycnf}" || return 1
        fi
    fi
    MYSQL_TEMP_CNF_BACKUP=""
    MYSQL_TEMP_CNF_BACKED_UP=0
}

StartOrStop()
{
    local action=$1
    local service=$2
    if [ "${isWSL}" = "n" ] && [ "${isDocker}" = "n" ] && command -v systemctl >/dev/null 2>&1 && [[ -s /etc/systemd/system/${service}.service ]]; then
        systemctl ${action} ${service}.service
    else
        /etc/init.d/${service} ${action}
    fi
}

Check_WSL() {
    if [[ "$(< /proc/sys/kernel/osrelease)" == *[Mm]icrosoft* ]]; then
        echo "running on WSL"
        isWSL="y"
    else
        isWSL="n"
    fi
}

Check_Docker() {
    if [ -f /.dockerenv ]; then
        echo "running on Docker"
        isDocker="y"
    elif [ -f /proc/1/cgroup ] && grep -q docker /proc/1/cgroup; then
        echo "running on Docker"
        isDocker="y"
    elif [ -f /proc/self/cgroup ] && grep -q docker /proc/self/cgroup; then
        echo "running on Docker"
        isDocker="y"
    else
        isDocker="n"
    fi
}

Check_Openssl()
{
    if ! command -v openssl >/dev/null 2>&1; then
        Echo_Blue "[+] Installing openssl..."
        if [ "${PM}" = "yum" ]; then
            yum install -y openssl
        elif [ "${PM}" = "apt" ]; then
            apt-get update -y
            [[ $? -ne 0 ]] && apt-get update --allow-releaseinfo-change -y
            apt-get install -y openssl
        fi
    fi
    openssl version
    if openssl version | grep -Eqi "OpenSSL 3.*"; then
        isOpenSSL3='y'
    fi
}
