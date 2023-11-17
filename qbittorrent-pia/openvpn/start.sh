#!/bin/bash
# Modified from https://github.com/DyonR/docker-qbittorrentvpn

set -e

check_network=$(ifconfig | grep docker0 || true)
if [[ ! -z "${check_network}" ]]; then
    echo "[ERROR] Network type detected as 'Host', this will cause major issues! Exiting..." | ts '%Y-%m-%d %H:%M:%.S'
    sleep 10
    exit 1
fi

set -e

if [[ -z "${VPN_REGION}" ]]; then
    echo "[ERROR] VPN_REGION not specified. Exiting..." | ts '%Y-%m-%d %H:%M:%.S'
    echo "[ERROR] The following PIA regions are available:" | ts '%Y-%m-%d %H:%M:%.S'
    ls /etc/openvpn/configs/ | grep ovpn | sed 's/.ovpn//g' | tr '\n', ','
    echo -e "\nExiting..." | ts '%Y-%m-%d %H:%M:%.S'
    sleep 10
    exit 1
fi

if ! test -f "/etc/openvpn/configs/${VPN_REGION}.ovpn"; then
    echo "[ERROR] VPN_REGION not found in /etc/openvpn/configs." | ts '%Y-%m-%d %H:%M:%.S'
    echo "[ERROR] The following PIA regions are available:" | ts '%Y-%m-%d %H:%M:%.S'
    ls /etc/openvpn/configs/ | grep ovpn | sed 's/.ovpn//g' | tr '\n', ','
    echo -e "\nExiting..." | ts '%Y-%m-%d %H:%M:%.S'
    sleep 10
    exit 1
fi

echo "[INFO] OpenVPN config file found at /etc/openvpn/configs/${VPN_REGION}" | ts '%Y-%m-%d %H:%M:%.S'
cp "/etc/openvpn/configs/${VPN_REGION}.ovpn" /etc/openvpn/config.ovpn
export VPN_CONFIG="/etc/openvpn/config.ovpn"

if [[ -z "${VPN_USERNAME}" ]]; then
    echo "[ERROR] VPN_USERNAME not specified. Exiting..." | ts '%Y-%m-%d %H:%M:%.S'
    sleep 10
    exit 1
fi

if [[ -z "${VPN_PASSWORD}" ]]; then
    echo "[ERROR] VPN_PASSWORD not specified. Exiting..." | ts '%Y-%m-%d %H:%M:%.S'
    sleep 10
    exit 1
fi

echo "${VPN_USERNAME}" > /etc/openvpn/credentials.conf
echo "${VPN_PASSWORD}" >> /etc/openvpn/credentials.conf
echo "auth-user-pass /etc/openvpn/credentials.conf" >> "${VPN_CONFIG}"

set +e

user_exists=$(cat "${VPN_CONFIG}" | grep -m 1 'user ')
if [[ ! -z "${user_exists}" ]]; then
    LINE_NUM=$(grep -Fn -m 1 'user ' "${VPN_CONFIG}" | cut -d: -f 1)
    sed -i "${LINE_NUM}s/.*/user nobody/" "${VPN_CONFIG}"
else
    echo "user nobody" >> "${VPN_CONFIG}"
fi

group_exists=$(cat "${VPN_CONFIG}" | grep -m 1 'group ')
if [[ ! -z "${group_exists}" ]]; then
    LINE_NUM=$(grep -Fn -m 1 'group ' "${VPN_CONFIG}" | cut -d: -f 1)
    sed -i "${LINE_NUM}s/.*/group nogroup/" "${VPN_CONFIG}"
else
    echo "group nogroup" >> "${VPN_CONFIG}"
fi

set -e

export vpn_remote_line=$(cat "${VPN_CONFIG}" | grep -P -o -m 1 '(?<=^remote\s)[^\n\r]+' | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
if [[ ! -z "${vpn_remote_line}" ]]; then
    echo "[INFO] VPN remote line defined as '${vpn_remote_line}'" | ts '%Y-%m-%d %H:%M:%.S'
else
    echo "[ERROR] VPN configuration file ${VPN_CONFIG} does not contain 'remote' line. Exiting..." | ts '%Y-%m-%d %H:%M:%.S'
    sleep 10
    exit 1
fi

export VPN_REMOTE=$(echo "${vpn_remote_line}" | grep -P -o -m 1 '^[^\s\r\n]+' | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
if [[ ! -z "${VPN_REMOTE}" ]]; then
    echo "[INFO] VPN_REMOTE defined as '${VPN_REMOTE}'" | ts '%Y-%m-%d %H:%M:%.S'
else
    echo "[ERROR] VPN_REMOTE not found in ${VPN_CONFIG}. Exiting..." | ts '%Y-%m-%d %H:%M:%.S'
    sleep 10
    exit 1
fi

export VPN_PORT=$(echo "${vpn_remote_line}" | grep -P -o -m 1 '(?<=\s)\d{2,5}(?=\s)?+' | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
if [[ ! -z "${VPN_PORT}" ]]; then
    echo "[INFO] VPN_PORT defined as '${VPN_PORT}'" | ts '%Y-%m-%d %H:%M:%.S'
else
    echo "[ERROR] VPN_PORT not found in ${VPN_CONFIG}. Exiting..." | ts '%Y-%m-%d %H:%M:%.S'
    sleep 10
    exit 1
fi

export VPN_PROTOCOL=$(cat "${VPN_CONFIG}" | grep -P -o -m 1 '(?<=^proto\s)[^\r\n]+' | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
if [[ ! -z "${VPN_PROTOCOL}" ]]; then
    echo "[INFO] VPN_PROTOCOL defined as '${VPN_PROTOCOL}'" | ts '%Y-%m-%d %H:%M:%.S'
else
    export VPN_PROTOCOL=$(echo "${vpn_remote_line}" | grep -P -o -m 1 'udp|tcp-client|tcp$' | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
    if [[ ! -z "${VPN_PROTOCOL}" ]]; then
        echo "[INFO] VPN_PROTOCOL defined as '${VPN_PROTOCOL}'" | ts '%Y-%m-%d %H:%M:%.S'
    else
        echo "[WARNING] VPN_PROTOCOL not found in ${VPN_CONFIG}, assuming udp" | ts '%Y-%m-%d %H:%M:%.S'
        export VPN_PROTOCOL="udp"
    fi
fi

if [[ "${VPN_PROTOCOL}" == "tcp-client" ]]; then
    export VPN_PROTOCOL="tcp"
fi

export VPN_DEVICE_TYPE=$(cat "${VPN_CONFIG}" | grep -P -o -m 1 '(?<=^dev\s)[^\r\n\d]+' | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
if [[ ! -z "${VPN_DEVICE_TYPE}" ]]; then
    export VPN_DEVICE_TYPE="${VPN_DEVICE_TYPE}0"
    echo "[INFO] VPN_DEVICE_TYPE defined as '${VPN_DEVICE_TYPE}'" | ts '%Y-%m-%d %H:%M:%.S'
else
    echo "[ERROR] VPN_DEVICE_TYPE not found in ${VPN_CONFIG}, exiting..." | ts '%Y-%m-%d %H:%M:%.S'
    sleep 10
    exit 1
fi

export VPN_OPTIONS=$(echo "${VPN_OPTIONS}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
if [[ ! -z "${VPN_OPTIONS}" ]]; then
    echo "[INFO] VPN_OPTIONS defined as '${VPN_OPTIONS}'" | ts '%Y-%m-%d %H:%M:%.S'
else
    echo "[INFO] VPN_OPTIONS not defined (via -e VPN_OPTIONS)" | ts '%Y-%m-%d %H:%M:%.S'
    export VPN_OPTIONS=""
fi

export LAN_NETWORK=$(echo "${LAN_NETWORK}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
if [[ ! -z "${LAN_NETWORK}" ]]; then
    echo "[INFO] LAN_NETWORK defined as '${LAN_NETWORK}'" | ts '%Y-%m-%d %H:%M:%.S'
else
    echo "[ERROR] LAN_NETWORK not defined (via -e LAN_NETWORK). Exiting..." | ts '%Y-%m-%d %H:%M:%.S'
    sleep 10
    exit 1
fi

export NAME_SERVERS=$(echo "${NAME_SERVERS}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
if [[ ! -z "${NAME_SERVERS}" ]]; then
    echo "[INFO] NAME_SERVERS defined as '${NAME_SERVERS}'" | ts '%Y-%m-%d %H:%M:%.S'
else
    echo "[WARNING] NAME_SERVERS not defined (via -e NAME_SERVERS), defaulting to CloudFlare and Google name servers" | ts '%Y-%m-%d %H:%M:%.S'
    export NAME_SERVERS="1.1.1.1,8.8.8.8,1.0.0.1,8.8.4.4"
fi

> /etc/resolv.conf
IFS=',' read -ra name_server_list <<< "${NAME_SERVERS}"
for name_server_item in "${name_server_list[@]}"; do
    name_server_item=$(echo "${name_server_item}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
    echo "[INFO] Adding ${name_server_item} to resolv.conf" | ts '%Y-%m-%d %H:%M:%.S'
    echo "nameserver ${name_server_item}" >> /etc/resolv.conf
done

# Stash env for OpenVPN --up
env | grep -P '(VPN_|LAN_NETWORK|NAME_SERVERS)' > /tmp/env

echo "[INFO] Starting OpenVPN..." | ts '%Y-%m-%d %H:%M:%.S'
exec openvpn --pull-filter ignore route-ipv6 --pull-filter ignore ifconfig-ipv6 --config "${VPN_CONFIG}" --script-security 2 --up /etc/openvpn/iptables.sh --down '/usr/bin/kill 1'
