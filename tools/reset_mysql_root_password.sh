#!/usr/bin/env bash
set -o pipefail

export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
umask 077

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)" || exit 1
cd -- "${SCRIPT_DIR}" || exit 1

if [ "$(id -u)" != "0" ]; then
    echo "Error: You must be root to run this script!"
    exit 1
fi

echo "+-------------------------------------------------------------------+"
echo "|   Reset MySQL/MariaDB root Password for LNMP, Written by Licess   |"
echo "+-------------------------------------------------------------------+"
echo "|       A tool to reset MySQL/MariaDB root password for LNMP        |"
echo "+-------------------------------------------------------------------+"
echo "|       For more information please visit https://lnmp.org          |"
echo "+-------------------------------------------------------------------+"
echo "|           Usage: ./reset_mysql_root_password.sh                   |"
echo "+-------------------------------------------------------------------+"

if [ -x /usr/local/mariadb/bin/mysql ] && [ -x /usr/local/mariadb/bin/mysqld_safe ]; then
    DB_Name="mariadb"
    DB_Home="/usr/local/mariadb"
elif [ -x /usr/local/mysql/bin/mysql ] && [ -x /usr/local/mysql/bin/mysqld_safe ]; then
    DB_Name="mysql"
    DB_Home="/usr/local/mysql"
else
    echo "MySQL/MariaDB not found!"
    exit 1
fi

DB_Bin="${DB_Home}/bin/mysql"
DB_Admin="${DB_Home}/bin/mysqladmin"
DB_Safe="${DB_Home}/bin/mysqld_safe"
DB_Service="/etc/init.d/${DB_Name}"
if [ ! -x "${DB_Admin}" ] || [ ! -x "${DB_Service}" ]; then
    echo "Required ${DB_Name} management tools were not found."
    exit 1
fi

DB_Ver="$(${DB_Home}/bin/mysql_config --version 2>/dev/null)" || {
    echo "Unable to determine ${DB_Name} version."
    exit 1
}
DB_Version_Number="$(printf '%s\n' "${DB_Ver}" | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1 || true)"

while :; do
    DB_Root_Password=""
    if ! read -r -s -p "Enter New ${DB_Name} root password (input will not be shown): " DB_Root_Password; then
        printf '\nError: input stream closed.\n' >&2
        exit 1
    fi
    printf '\n'
    if [ -z "${DB_Root_Password}" ]; then
        echo "Error: Password can't be NULL!!"
    else
        break
    fi
done

sql_password="${DB_Root_Password//\\/\\\\}"
sql_password="${sql_password//\'/\'\'}"
reset_socket="/tmp/lnmp-reset-${DB_Name}-$$.sock"
reset_pid="/tmp/lnmp-reset-${DB_Name}-$$.pid"
reset_safe_pid=""
reset_service_needed=0

Reset_Cleanup()
{
    local status=$?

    if [ -n "${reset_safe_pid}" ]; then
        "${DB_Admin}" --no-defaults --protocol=socket --socket="${reset_socket}" -u root shutdown >/dev/null 2>&1 || true
        if kill -0 "${reset_safe_pid}" >/dev/null 2>&1; then
            kill "${reset_safe_pid}" >/dev/null 2>&1 || true
            wait "${reset_safe_pid}" 2>/dev/null || true
        fi
    fi
    rm -f -- "${reset_socket}" "${reset_pid}"

    if [ "${reset_service_needed}" -eq 1 ]; then
        echo "Restarting the actual ${DB_Name} service..."
        if ! "${DB_Service}" start >/dev/null 2>&1; then
            echo "Error: failed to restart ${DB_Name}." >&2
            status=1
        fi
    fi
    unset DB_Root_Password sql_password
    return "${status}"
}
trap Reset_Cleanup EXIT
trap 'exit 130' INT TERM

echo "Stopping ${DB_Name}..."
"${DB_Service}" stop || exit 1
reset_service_needed=1

echo "Starting ${DB_Name} in a private, grant-table recovery socket..."
"${DB_Safe}" --skip-grant-tables --skip-networking \
    --socket="${reset_socket}" --pid-file="${reset_pid}" >/dev/null 2>&1 &
reset_safe_pid=$!

db_ready=0
for ((attempt = 0; attempt < 30; attempt++)); do
    if "${DB_Bin}" --no-defaults --protocol=socket --socket="${reset_socket}" -u root \
        -e 'SELECT 1' >/dev/null 2>&1; then
        db_ready=1
        break
    fi
    if ! kill -0 "${reset_safe_pid}" >/dev/null 2>&1; then
        break
    fi
    sleep 1
done

if [ "${db_ready}" -ne 1 ]; then
    echo "Error: ${DB_Name} did not become ready in recovery mode." >&2
    exit 1
fi

echo "Updating ${DB_Name} root password..."
if {
    [[ "${DB_Name}" == "mysql" && ( "${DB_Version_Number}" == 8.* || "${DB_Version_Number}" == 5.7.* ) ]] ||
        [[ "${DB_Name}" == "mariadb" && "${DB_Version_Number}" =~ ^10\.(2|3|4|5|6|7|8|9|1[0-9])\. ]]
}; then
    printf "FLUSH PRIVILEGES;\nALTER USER 'root'@'localhost' IDENTIFIED BY '%s';\n" "${sql_password}" |
        "${DB_Bin}" --no-defaults --protocol=socket --socket="${reset_socket}" -u root
else
    printf "UPDATE mysql.user SET Password=PASSWORD('%s') WHERE User='root';\nFLUSH PRIVILEGES;\n" "${sql_password}" |
        "${DB_Bin}" --no-defaults --protocol=socket --socket="${reset_socket}" -u root
fi

echo "Password reset completed successfully."
