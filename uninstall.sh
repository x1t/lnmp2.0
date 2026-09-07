#!/usr/bin/env bash

set -Eeuo pipefail
umask 077
export PATH="${PATH}:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)" || exit 1
cd -- "${SCRIPT_DIR}" || exit 1

if [[ "$(id -u)" != "0" ]]; then
    echo "错误：必须使用 root 运行此脚本。" >&2
    exit 1
fi

if [[ ! -r "${SCRIPT_DIR}/lnmp.conf" ]]; then
    echo "错误：找不到 ${SCRIPT_DIR}/lnmp.conf。" >&2
    exit 1
fi

# 只读取配置中的路径，不执行其它项目脚本，避免卸载脚本被安装逻辑影响。
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/lnmp.conf"

DRY_RUN=0
FORCE=0
SYSTEMD_RUNNING=0
BACKUP_ROOT=""

declare -a PLAN=()
declare -a SERVICES=()
declare -a SOFTWARE_DIRS=()
declare -a MIGRATION_DIRS=()
declare -a MIGRATION_RELS=()
declare -a DATA_DIRS=()
declare -a DATA_RELS=()
declare -a CONFIG_DIRS=()
declare -a CONFIG_RELS=()
declare -a LOCAL_LIBRARY_FILES=()
declare -a PRESERVE_FILES=()
declare -a REMOVE_CONFIG_FILES=()
declare -A SEEN_SERVICES=()
declare -A SEEN_SOFTWARE=()
declare -A SEEN_MIGRATION=()
declare -A SEEN_DATA=()
declare -A SEEN_CONFIG=()
declare -A SEEN_LIBRARY=()
declare -A SEEN_PRESERVE=()

trap 'printf "卸载脚本在第 %s 行失败：%s\n" "${LINENO}" "${BASH_COMMAND}" >&2' ERR

usage() {
    cat <<'EOF'
用法：
  ./uninstall.sh [--dry-run]
  ./uninstall.sh --yes

行为：
  默认删除 LNMP 软件、其明确生成的启动项/软链接/配置片段和防火墙规则，
  网站目录与数据库目录不直接删除；位于待删除软件目录中的数据库数据会
  移动到 /root/lnmp-uninstall-backup-* 备份目录。

选项：
  --dry-run       只显示计划，不修改系统
  --yes, -y       跳过确认提示（仅适合已审阅计划后使用）
  --help, -h      显示帮助
EOF
}

for argument in "$@"; do
    case "${argument}" in
        --dry-run)
            DRY_RUN=1
            ;;
        --yes|-y)
            FORCE=1
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            echo "未知参数：${argument}" >&2
            usage >&2
            exit 2
            ;;
    esac
done

path_present() {
    [[ -e "$1" || -L "$1" ]]
}

safe_absolute_path() {
    local path="${1:-}"
    [[ "${path}" == /* && "${path}" != "/" ]] || return 1
    [[ "${path}" != *$'\n'* && "${path}" != *$'\r'* ]] || return 1
    case "${path}" in
        *'//'/*|*/../*|*/..|../*)
            return 1
            ;;
    esac
    return 0
}

path_is_under() {
    local child="$1"
    local parent="$2"
    [[ "${child}" == "${parent}" || "${child}" == "${parent}"/* ]]
}

resolved_path() {
    realpath -e -- "$1" 2>/dev/null || readlink -f -- "$1" 2>/dev/null
}

add_unique() {
    local array_name="$1"
    local value="$2"
    local existing
    declare -n array_ref="${array_name}"
    for existing in "${array_ref[@]}"; do
        [[ "${existing}" == "${value}" ]] && return 0
    done
    array_ref+=("${value}")
}

plan() {
    PLAN+=("$1")
}

warn() {
    printf '警告：%s\n' "$1" >&2
}

remove_path() {
    local path="$1"
    path_present "${path}" || return 0
    if (( DRY_RUN )); then
        printf '[dry-run] 删除：%s\n' "${path}"
    else
        rm -rf -- "${path}"
        printf '已删除：%s\n' "${path}"
    fi
}

remove_file() {
    local path="$1"
    path_present "${path}" || return 0
    if (( DRY_RUN )); then
        printf '[dry-run] 删除文件：%s\n' "${path}"
    else
        rm -f -- "${path}"
        printf '已删除文件：%s\n' "${path}"
    fi
}

stash_path() {
    local source="$1"
    local relative="$2"
    local destination base counter=1

    path_present "${source}" || return 0
    destination="${BACKUP_ROOT}/${relative}"
    base="${destination}"

    if (( DRY_RUN )); then
        printf '[dry-run] 备份并保留：%s -> %s\n' "${source}" "${destination}"
        return 0
    fi

    mkdir -p -- "$(dirname -- "${destination}")"
    while path_present "${destination}"; do
        destination="${base}.${counter}"
        ((counter++))
    done
    mv -- "${source}" "${destination}"
    printf '已备份并移出软件目录：%s -> %s\n' "${source}" "${destination}"
}

unit_is_owned() {
    local service="$1"
    local unit="/etc/systemd/system/${service}.service"
    path_present "${unit}" || return 1
    if grep -Eq '/usr/local/(nginx|php[^[:space:]]*|mysql|mariadb|apache|redis|pureftpd)' "${unit}" 2>/dev/null; then
        return 0
    fi
    if grep -Eq "/etc/init.d/${service}([[:space:]]|$)" "${unit}" 2>/dev/null && init_script_is_owned "${service}"; then
        return 0
    fi
    return 1
}

init_script_is_owned() {
    local service="$1"
    local init_script="/etc/init.d/${service}"
    path_present "${init_script}" || return 1
    grep -Eq '/usr/local/(nginx|php[^[:space:]]*|mysql|mariadb|apache|redis|pureftpd)' "${init_script}" 2>/dev/null
}

service_pattern() {
    case "$1" in
        nginx)
            printf '%s\n' '/usr/local/nginx/[^[:space:]]*nginx'
            ;;
        php-fpm|php-fpm*)
            printf '%s\n' '(/usr/local/php[^[:space:]]*/sbin/php-fpm|php-fpm:.*\(/usr/local/php)'
            ;;
        mysql)
            printf '%s\n' '/usr/local/mysql/[^[:space:]]*(mysqld|mysqld_safe)'
            ;;
        mariadb)
            printf '%s\n' '/usr/local/mariadb/[^[:space:]]*(mariadbd|mysqld|mysqld_safe)'
            ;;
        httpd)
            printf '%s\n' '/usr/local/apache/[^[:space:]]*httpd'
            ;;
        redis)
            printf '%s\n' '/usr/local/redis/[^[:space:]]*redis-server'
            ;;
        pureftpd)
            printf '%s\n' '/usr/local/pureftpd/[^[:space:]]*pure-ftpd'
            ;;
        *)
            return 1
            ;;
    esac
}

service_process_is_running() {
    local pattern
    pattern="$(service_pattern "$1")" || return 1
    pgrep -f -- "${pattern}" >/dev/null 2>&1
}

add_service() {
    local service="$1"
    if [[ -z "${SEEN_SERVICES[${service}]:-}" ]]; then
        SEEN_SERVICES["${service}"]=1
        SERVICES+=("${service}")
    fi
}

stop_process_pattern() {
    local service="$1"
    local pattern
    local -a pids=()
    local pid

    pattern="$(service_pattern "${service}")" || return 0
    mapfile -t pids < <(pgrep -f -- "${pattern}" || true)
    if ((${#pids[@]} == 0)); then
        return 0
    fi

    if (( DRY_RUN )); then
        printf '[dry-run] 停止进程：%s（匹配 %s）\n' "${service}" "${pattern}"
        return 0
    fi

    for pid in "${pids[@]}"; do
        [[ "${pid}" =~ ^[0-9]+$ && "${pid}" != "$$" ]] || continue
        kill -TERM "${pid}" 2>/dev/null || true
    done
    for _ in {1..30}; do
        service_process_is_running "${service}" || return 0
        sleep 1
    done

    mapfile -t pids < <(pgrep -f -- "${pattern}" || true)
    for pid in "${pids[@]}"; do
        [[ "${pid}" =~ ^[0-9]+$ && "${pid}" != "$$" ]] || continue
        kill -KILL "${pid}" 2>/dev/null || true
    done
    sleep 1
}

stop_service() {
    local service="$1"
    local unit_owned=0
    local init_owned=0

    unit_is_owned "${service}" && unit_owned=1 || true
    init_script_is_owned "${service}" && init_owned=1 || true

    if (( DRY_RUN )); then
        if (( unit_owned && SYSTEMD_RUNNING )); then
            printf '[dry-run] systemctl disable --now %s.service\n' "${service}"
        elif (( init_owned )); then
            printf '[dry-run] /etc/init.d/%s stop\n' "${service}"
        fi
        stop_process_pattern "${service}"
        return 0
    fi

    if (( unit_owned && SYSTEMD_RUNNING )); then
        if ! systemctl disable --now "${service}.service"; then
            warn "systemd 停止/禁用 ${service}.service 返回非零，将继续检查进程。"
        fi
    elif (( init_owned )); then
        "/etc/init.d/${service}" stop >/dev/null 2>&1 || true
    fi

    stop_process_pattern "${service}"
    if service_process_is_running "${service}"; then
        echo "错误：仍有 ${service} 进程运行，已停止卸载以避免删除正在使用的文件。" >&2
        return 1
    fi
}

discover_services() {
    local service init_script unit

    for service in nginx php-fpm mysql mariadb httpd redis pureftpd; do
        if unit_is_owned "${service}" || init_script_is_owned "${service}" || service_process_is_running "${service}"; then
            add_service "${service}"
        fi
    done

    for init_script in /etc/init.d/php-fpm*; do
        path_present "${init_script}" || continue
        service="$(basename -- "${init_script}")"
        [[ "${service}" == "php-fpm" ]] && continue
        if init_script_is_owned "${service}" || service_process_is_running "${service}"; then
            add_service "${service}"
        fi
    done

    for unit in /etc/systemd/system/php-fpm*.service; do
        path_present "${unit}" || continue
        service="$(basename -- "${unit}" .service)"
        [[ "${service}" == "php-fpm" ]] && continue
        if unit_is_owned "${service}" || service_process_is_running "${service}"; then
            add_service "${service}"
        fi
    done
}

add_software_dir() {
    local path="$1"
    path_present "${path}" || return 0
    safe_absolute_path "${path}" || {
        echo "错误：拒绝处理不安全软件路径：${path}" >&2
        return 1
    }
    if [[ -z "${SEEN_SOFTWARE[${path}]:-}" ]]; then
        SEEN_SOFTWARE["${path}"]=1
        SOFTWARE_DIRS+=("${path}")
    fi
}

add_migration_dir() {
    local path="$1"
    path_present "${path}" || return 0
    safe_absolute_path "${path}" || {
        echo "错误：拒绝处理不安全迁移目录：${path}" >&2
        return 1
    }
    if [[ -z "${SEEN_MIGRATION[${path}]:-}" ]]; then
        SEEN_MIGRATION["${path}"]=1
        MIGRATION_DIRS+=("${path}")
        MIGRATION_RELS+=("database/migration-$(basename -- "${path}")")
    fi
}

add_data_candidate() {
    local raw_path="$1"
    local label="$2"
    local resolved prefix relative

    safe_absolute_path "${raw_path}" || {
        echo "错误：数据库目录不是安全的绝对路径：${raw_path}" >&2
        return 1
    }
    path_present "${raw_path}" || return 0
    resolved="$(resolved_path "${raw_path}")" || {
        echo "错误：无法解析数据库目录：${raw_path}" >&2
        return 1
    }

    prefix=""
    for candidate in /usr/local/mysql /usr/local/mariadb; do
        if path_is_under "${resolved}" "${candidate}"; then
            prefix="${candidate}"
            break
        fi
    done

    if [[ -n "${prefix}" ]]; then
        if [[ "${resolved}" == "${prefix}" ]]; then
            echo "错误：数据库目录不能等于软件根目录：${resolved}" >&2
            return 1
        fi
        if [[ -z "${SEEN_DATA[${resolved}]:-}" ]]; then
            SEEN_DATA["${resolved}"]=1
            relative="database/${label}-$(basename -- "${resolved}")"
            DATA_DIRS+=("${resolved}")
            DATA_RELS+=("${relative}")
            plan "数据库数据：${resolved} 将移动到备份 ${relative}"
        fi
    else
        plan "外置数据库目录：${resolved} 保持原位置不动"
    fi
}

add_config_dir() {
    local source="$1"
    local relative="$2"
    local resolved

    path_present "${source}" || return 0
    resolved="$(resolved_path "${source}")" || return 1
    if path_is_under "${resolved}" "/usr/local/nginx" || path_is_under "${resolved}" "/usr/local/php"; then
        if [[ -z "${SEEN_CONFIG[${source}]:-}" ]]; then
            SEEN_CONFIG["${source}"]=1
            CONFIG_DIRS+=("${source}")
            CONFIG_RELS+=("${relative}")
            plan "软件配置：${source} 将备份到 ${relative}"
        fi
    fi
}

add_preserve_file() {
    local source="$1"
    local relative="$2"
    path_present "${source}" || return 0
    if [[ -z "${SEEN_PRESERVE[${source}]:-}" ]]; then
        SEEN_PRESERVE["${source}"]=1
        PRESERVE_FILES+=("${source}|${relative}")
        plan "配置保留：${source} 将备份到 ${relative}"
    fi
}

add_library_file() {
    local source="$1"
    path_present "${source}" || return 0
    if [[ -z "${SEEN_LIBRARY[${source}]:-}" ]]; then
        SEEN_LIBRARY["${source}"]=1
        LOCAL_LIBRARY_FILES+=("${source}")
    fi
}

discover_software() {
    local path base

    for path in /usr/local/nginx /usr/local/php /usr/local/mysql /usr/local/mariadb /usr/local/apache /usr/local/redis /usr/local/pureftpd /usr/local/acme.sh; do
        add_software_dir "${path}"
    done

    for path in /usr/local/php[0-9]* /usr/local/oldphp* /usr/local/mphp-*; do
        path_present "${path}" || continue
        [[ -d "${path}" ]] || continue
        base="$(basename -- "${path}")"
        if [[ "${base}" == php[0-9]* || "${base}" == oldphp* || "${base}" == mphp-* ]]; then
            add_software_dir "${path}"
        fi
    done

    for path in /usr/local/mysql2mariadb*; do
        path_present "${path}" || continue
        add_migration_dir "${path}"
    done

    for path in /usr/local/freetype /usr/local/curl /usr/local/openssl /usr/local/openssl1.1.1 /usr/local/icu /usr/local/nghttp2 /usr/local/luajit /usr/local/autoconf-2.13; do
        add_software_dir "${path}"
    done

    for pattern in \
        /usr/local/lib/libiconv.* \
        /usr/local/lib/libcharset.* \
        /usr/local/lib/libmcrypt.* \
        /usr/local/lib/libmhash.* \
        /usr/local/lib/libjemalloc.* \
        /usr/local/lib/libtcmalloc.* \
        /usr/local/lib/libunwind.* \
        /usr/local/lib/libzip.* \
        /usr/local/lib/libltdl.*; do
        add_library_file "${pattern}"
    done

    for path in /usr/local/lib/pkgconfig/libiconv.pc /usr/local/lib/pkgconfig/libcharset.pc /usr/local/lib/pkgconfig/libmcrypt.pc /usr/local/lib/pkgconfig/libmhash.pc /usr/local/lib/pkgconfig/libzip.pc; do
        add_library_file "${path}"
    done
}

discover_data_and_configs() {
    local configured_datadir=""

    add_data_candidate "${MySQL_Data_Dir:-/usr/local/mysql/var}" mysql || return 1
    add_data_candidate "${MariaDB_Data_Dir:-/usr/local/mariadb/var}" mariadb || return 1
    add_data_candidate "/usr/local/mysql/var" mysql-default || return 1
    add_data_candidate "/usr/local/mysql/data" mysql-default || return 1
    add_data_candidate "/usr/local/mariadb/var" mariadb-default || return 1
    add_data_candidate "/usr/local/mariadb/data" mariadb-default || return 1

    if [[ -s /etc/my.cnf ]]; then
        configured_datadir="$(awk '
            /^[[:space:]]*#/ { next }
            tolower($1) == "datadir" {
                value=$0
                sub(/^[^=]*=/, "", value)
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
                gsub(/^"|"$/, "", value)
                gsub(/^\x27|\x27$/, "", value)
                print value
                exit
            }
        ' /etc/my.cnf)"
        if [[ -n "${configured_datadir}" ]]; then
            add_data_candidate "${configured_datadir}" config || return 1
        fi
        if grep -Eq '/usr/local/(mysql|mariadb)' /etc/my.cnf; then
            add_preserve_file /etc/my.cnf config/etc/my.cnf
        fi
    fi

    add_config_dir /usr/local/nginx/conf config/nginx-conf
    add_config_dir /usr/local/php/etc config/php-etc
}

discover_owned_config_files() {
    local path

    for path in /etc/ld.so.conf.d/mysql.conf /etc/ld.so.conf.d/freetype.conf /etc/ld.so.conf.d/icu.conf /etc/ld.so.conf.d/luajit.conf; do
        path_present "${path}" || continue
        if grep -Eq '/usr/local/(mysql|mariadb|freetype|icu|luajit)' "${path}" 2>/dev/null; then
            REMOVE_CONFIG_FILES+=("${path}")
        fi
    done

    if [[ -s /etc/profile.d/luajit.sh ]] && grep -Eq '/usr/local/luajit' /etc/profile.d/luajit.sh; then
        REMOVE_CONFIG_FILES+=(/etc/profile.d/luajit.sh)
    fi
}

discover_plan() {
    local service path

    discover_software
    discover_services
    discover_data_and_configs
    discover_owned_config_files

    safe_absolute_path "${Default_Website_Dir:-/home/wwwroot/default}" || {
        echo "错误：网站目录不是安全的绝对路径：${Default_Website_Dir:-}" >&2
        return 1
    }
    if [[ "${Default_Website_Dir}" == /usr/local/* ]]; then
        echo "错误：网站目录位于 /usr/local 下，拒绝执行以避免误删网站：${Default_Website_Dir}" >&2
        return 1
    fi
    plan "网站目录：${Default_Website_Dir} 保持不动"
    if path_present /home/wwwroot; then
        plan "网站根目录：/home/wwwroot 保持不动"
    fi
    if path_present /home/wwwlogs; then
        plan "网站日志目录：/home/wwwlogs 保持不动"
    fi

    for service in "${SERVICES[@]}"; do
        plan "停止并移除 LNMP 服务：${service}"
    done
    for path in "${MIGRATION_DIRS[@]}"; do
        plan "数据库迁移目录：${path} 将完整备份后移出"
    done
    for path in "${SOFTWARE_DIRS[@]}"; do
        plan "删除软件目录：${path}"
    done
    for path in "${LOCAL_LIBRARY_FILES[@]}"; do
        plan "备份并移除 LNMP 专用库文件：${path}"
    done
    plan "移除由 LNMP 明确生成的命令软链接、启动项和配置片段"
    plan "移除 LNMP 明确添加的 iptables INPUT 规则；不卸载系统软件包和用户"
}

show_plan() {
    echo ""
    echo "================ LNMP 卸载计划 ================"
    if ((${#PLAN[@]} == 0)); then
        echo "未发现可处理的 LNMP 安装痕迹。"
    else
        printf ' - %s\n' "${PLAN[@]}"
    fi
    echo "================================================="
}

confirm_plan() {
    (( DRY_RUN )) && return 0
    (( FORCE )) && return 0
    local confirmation
    read -r -p '确认执行请输入 REMOVE-LNMP：' confirmation
    [[ "${confirmation}" == "REMOVE-LNMP" ]] || {
        echo "未确认，已退出。"
        return 1
    }
}

prepare_backup() {
    BACKUP_ROOT="/root/lnmp-uninstall-backup-$(date +%Y%m%d%H%M%S)-$$"
    if (( DRY_RUN )); then
        printf '[dry-run] 备份根目录：%s\n' "${BACKUP_ROOT}"
        return 0
    fi
    mkdir -p -- "${BACKUP_ROOT}"
    {
        printf 'created=%s\n' "$(date --iso-8601=seconds)"
        printf 'script=%s\n' "${SCRIPT_DIR}/uninstall.sh"
        printf 'website_dir=%s\n' "${Default_Website_Dir}"
        printf '\nPLAN\n'
        printf '%s\n' "${PLAN[@]}"
    } >"${BACKUP_ROOT}/MANIFEST.txt"
}

backup_firewall() {
    (( DRY_RUN )) && return 0
    mkdir -p -- "${BACKUP_ROOT}/firewall"
    if command -v iptables-save >/dev/null 2>&1; then
        iptables-save >"${BACKUP_ROOT}/firewall/rules.v4.before" 2>/dev/null || warn "无法保存卸载前 IPv4 防火墙规则。"
    fi
    if command -v ip6tables-save >/dev/null 2>&1; then
        ip6tables-save >"${BACKUP_ROOT}/firewall/rules.v6.before" 2>/dev/null || warn "无法保存卸载前 IPv6 防火墙规则。"
    fi
}

preserve_data_and_configs() {
    local index source relative entry

    for index in "${!DATA_DIRS[@]}"; do
        stash_path "${DATA_DIRS[${index}]}" "${DATA_RELS[${index}]}"
    done
    for index in "${!MIGRATION_DIRS[@]}"; do
        stash_path "${MIGRATION_DIRS[${index}]}" "${MIGRATION_RELS[${index}]}"
    done
    for index in "${!CONFIG_DIRS[@]}"; do
        stash_path "${CONFIG_DIRS[${index}]}" "${CONFIG_RELS[${index}]}"
    done
    for entry in "${PRESERVE_FILES[@]}"; do
        source="${entry%%|*}"
        relative="${entry#*|}"
        stash_path "${source}" "${relative}"
    done
}

remove_startup_links() {
    local service link target unit_owned=0

    for service in "${SERVICES[@]}"; do
        unit_owned=0
        unit_is_owned "${service}" && unit_owned=1 || true
        if init_script_is_owned "${service}"; then
            remove_file "/etc/init.d/${service}"
        fi
        if (( unit_owned )); then
            remove_file "/etc/systemd/system/${service}.service"
        fi

        while IFS= read -r -d '' link; do
            remove_file "${link}"
        done < <(find /etc -type l -path "/etc/rc*.d/[SK][0-9][0-9]${service}*" -print0 2>/dev/null || true)

        while IFS= read -r -d '' link; do
            target="$(readlink -f -- "${link}" 2>/dev/null || true)"
            if [[ "$(basename -- "${target}")" == "${service}.service" ]]; then
                remove_file "${link}"
            fi
        done < <(find /etc/systemd/system -type l -print0 2>/dev/null || true)
    done

    if command -v systemctl >/dev/null 2>&1 && [[ -d /run/systemd/system ]]; then
        if (( DRY_RUN )); then
            echo '[dry-run] systemctl daemon-reload'
        else
            systemctl daemon-reload
        fi
    fi
}

remove_owned_symlinks() {
    local directory link target prefix
    local -a link_directories=(/usr/bin /usr/sbin /usr/lib /usr/lib64 /lib /lib64 /usr/include)
    local -a target_prefixes=(/usr/local/nginx /usr/local/php /usr/local/mysql /usr/local/mariadb /usr/local/apache /usr/local/redis /usr/local/pureftpd /usr/local/freetype /usr/local/curl /usr/local/openssl /usr/local/openssl1.1.1 /usr/local/icu /usr/local/nghttp2 /usr/local/luajit /usr/local/autoconf-2.13)
    target_prefixes+=("${SOFTWARE_DIRS[@]}")

    for directory in "${link_directories[@]}"; do
        [[ -d "${directory}" ]] || continue
        while IFS= read -r -d '' link; do
            target="$(readlink -f -- "${link}" 2>/dev/null || true)"
            [[ -n "${target}" ]] || continue
            for prefix in "${target_prefixes[@]}"; do
                if path_is_under "${target}" "${prefix}"; then
                    remove_file "${link}"
                    break
                fi
            done
        done < <(find "${directory}" -maxdepth 1 -type l -print0 2>/dev/null || true)
    done

}

remove_config_fragments() {
    local path
    for path in "${REMOVE_CONFIG_FILES[@]}"; do
        if path_present "${path}"; then
            stash_path "${path}" "config${path}"
        fi
    done
}

remove_local_libraries() {
    local source
    for source in "${LOCAL_LIBRARY_FILES[@]}"; do
        stash_path "${source}" "libraries/local/$(basename -- "${source}")"
    done

    for source in /usr/local/include/iconv.h /usr/local/include/libcharset.h /usr/local/include/localcharset.h /usr/local/include/mcrypt.h /usr/local/include/mhash.h /usr/local/include/ltdl.h; do
        if path_present "${source}"; then
            stash_path "${source}" "libraries/include/$(basename -- "${source}")"
        fi
    done
}

remove_acme_cron() {
    local cron_content filtered_content temp_file
    path_present /usr/local/acme.sh || true

    if ! command -v crontab >/dev/null 2>&1; then
        return 0
    fi
    cron_content="$(crontab -l 2>/dev/null || true)"
    [[ "${cron_content}" == *'/usr/local/acme.sh/'* ]] || return 0

    filtered_content="$(printf '%s\n' "${cron_content}" | grep -vF '/usr/local/acme.sh/' || true)"
    if (( DRY_RUN )); then
        echo '[dry-run] 删除 root crontab 中由 acme.sh 生成的任务'
        return 0
    fi

    if [[ -n "${filtered_content//[[:space:]]/}" ]]; then
        temp_file="$(mktemp "${TMPDIR:-/tmp}/lnmp-crontab.XXXXXX")"
        printf '%s\n' "${filtered_content}" >"${temp_file}"
        crontab "${temp_file}"
        rm -f -- "${temp_file}"
    else
        crontab -r 2>/dev/null || true
    fi
}

remove_firewall_rule() {
    local -a rule=("$@")
    while iptables -C INPUT "${rule[@]}" >/dev/null 2>&1; do
        iptables -D INPUT "${rule[@]}"
    done
}

cleanup_firewall() {
    (( DRY_RUN )) && {
        if command -v iptables >/dev/null 2>&1; then
            echo '[dry-run] 清理 LNMP 添加的 IPv4 INPUT 规则'
        fi
        return 0
    }
    command -v iptables >/dev/null 2>&1 || return 0

    remove_firewall_rule -i lo -j ACCEPT
    remove_firewall_rule -m state --state ESTABLISHED,RELATED -j ACCEPT
    remove_firewall_rule -p tcp --dport 22 -j ACCEPT
    remove_firewall_rule -p tcp --dport 80 -j ACCEPT
    remove_firewall_rule -p tcp --dport 443 -j ACCEPT
    remove_firewall_rule -p tcp --dport 3306 -j DROP
    remove_firewall_rule -p icmp -m icmp --icmp-type 8 -j ACCEPT
    remove_firewall_rule -p tcp --dport 6379 -j DROP

    if command -v netfilter-persistent >/dev/null 2>&1; then
        netfilter-persistent save || warn 'netfilter-persistent 保存规则失败。'
    elif [[ -x /etc/init.d/iptables-persistent ]]; then
        /etc/init.d/iptables-persistent save || warn 'iptables-persistent 保存规则失败。'
    elif command -v service >/dev/null 2>&1 && command -v iptables-save >/dev/null 2>&1; then
        service iptables save >/dev/null 2>&1 || true
    fi
}

remove_known_software() {
    local path
    for path in "${SOFTWARE_DIRS[@]}"; do
        remove_path "${path}"
    done
}

remove_runtime_artifacts() {
    remove_owned_symlinks
    remove_file /bin/lnmp
    remove_file /tmp/php-cgi.sock
    remove_file /tmp/mysql.sock
    remove_file /tmp/mariadb.sock
    remove_config_fragments
    remove_local_libraries
}

verify_no_owned_processes() {
    local service
    for service in nginx php-fpm mysql mariadb httpd redis pureftpd; do
        if service_process_is_running "${service}"; then
            echo "错误：卸载后仍检测到 ${service} 进程。" >&2
            return 1
        fi
    done
}

finish_cleanup() {
    local path
    if command -v ldconfig >/dev/null 2>&1; then
        if (( DRY_RUN )); then
            echo '[dry-run] ldconfig'
        else
            ldconfig
        fi
    fi
    if (( ! DRY_RUN )); then
        for path in "${SOFTWARE_DIRS[@]}"; do
            if path_present "${path}"; then
                echo "错误：软件目录未能完整移除：${path}" >&2
                return 1
            fi
        done
    fi
}

main() {
    local service

    if [[ -d /run/systemd/system ]] && command -v systemctl >/dev/null 2>&1; then
        SYSTEMD_RUNNING=1
    fi

    discover_plan
    show_plan
    confirm_plan
    prepare_backup
    backup_firewall

    if (( DRY_RUN )); then
        preserve_data_and_configs
        for service in "${SERVICES[@]}"; do
            stop_service "${service}"
        done
        remove_startup_links
        remove_acme_cron
        remove_runtime_artifacts
        cleanup_firewall
        remove_known_software
        finish_cleanup
        echo 'dry-run 完成：未修改系统。'
        return 0
    fi

    echo '开始停止 LNMP 服务...'
    for service in "${SERVICES[@]}"; do
        stop_service "${service}"
    done
    verify_no_owned_processes

    preserve_data_and_configs
    remove_startup_links
    remove_acme_cron
    remove_runtime_artifacts
    cleanup_firewall
    remove_known_software
    finish_cleanup

    echo ''
    echo 'LNMP 软件卸载完成。'
    echo "网站目录已保留：${Default_Website_Dir}"
    echo '数据库数据未删除；位于 LNMP 软件目录内的数据已备份到：'
    echo "${BACKUP_ROOT}"
    echo '未删除系统软件包、www/mysql 用户及外置数据库目录。'
}

main "$@"
