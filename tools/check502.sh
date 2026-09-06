#!/usr/bin/env bash
# author: licess
# LNMP Environment Check Script

CheckURL="${1:-}"
if [[ "${CheckURL}" != https://* ]]; then
    echo "Usage: $0 <HTTPS_URL>" >&2
    exit 2
fi

STATUS_CODE=$(curl --proto '=https' --proto-redir '=https' -o /dev/null -m 10 --connect-timeout 10 -s -w '%{http_code}' "${CheckURL}")
#echo "$CheckURL Status Code:\t$STATUS_CODE"
if [ "$STATUS_CODE" = "502" ]; then
    /etc/init.d/php-fpm restart
fi
