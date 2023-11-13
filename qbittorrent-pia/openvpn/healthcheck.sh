#!/bin/bash

sleep 15

while true; do

    HOST=${HEALTH_CHECK_HOST}
    if [[ -z "$HOST" ]]
    then
        HOST="google.com"
    fi

    # Check DNS resolution works
    nslookup $HOST 2>&1 >/dev/null
    STATUS=$?
    if [[ ${STATUS} -ne 0 ]]
    then
        echo "[WARNING] DNS resolution failed. Exiting..." | ts '%Y-%m-%d %H:%M:%.S'
        kill 1
    fi

    ping -c 2 -w 10 $HOST 2>&1 >/dev/null
    STATUS=$?
    if [[ ${STATUS} -ne 0 ]]
    then
        echo "[WARNING] Network is down. Exiting..." | ts '%Y-%m-%d %H:%M:%.S'
        kill 1
    fi

    OPENVPN=$(pgrep openvpn | wc -l)
    if [[ ${OPENVPN} -eq 0 ]]; then
        echo "[WARNING] Openvpn process not running. Exiting..." | ts '%Y-%m-%d %H:%M:%.S'
        kill 1
    fi

    QBITTORRENT=$(pgrep qbittorrent | wc -l)
    if [[ ${QBITTORRENT} -eq 0 ]]; then
        echo "[WARNING] qBittorrent process not running. Exiting..." | ts '%Y-%m-%d %H:%M:%.S'
        kill 1
    fi

    sleep 10

done
