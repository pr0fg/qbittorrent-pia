#!/bin/bash
# Modified from https://github.com/DyonR/docker-qbittorrentvpn

set -e

# Check if /config/qBittorrent exists, if not make the directory
if [[ ! -e /config/qBittorrent/config ]]; then
	mkdir -p /config/qBittorrent/config
fi

# Set the correct rights on /config/qBittorrent
chown -R qbittorrent:qbittorrent /config/qBittorrent

# Set the rights on the /downloads folder
chmod -R 777 /downloads

# Check if qBittorrent.conf exists, if not, copy the template over
if [ ! -e /config/qBittorrent/config/qBittorrent.conf ]; then
	echo "[WARNING] qBittorrent.conf is missing! Copying template." | ts '%Y-%m-%d %H:%M:%.S'
	cp /etc/qBittorrent/qBittorrent.conf /config/qBittorrent/config/qBittorrent.conf
	chmod 755 /config/qBittorrent/config/qBittorrent.conf
	chown qbittorrent:qbittorrent /config/qBittorrent/config/qBittorrent.conf
fi

# Start qBittorrent
echo "[INFO] Starting qBittorrent..." | ts '%Y-%m-%d %H:%M:%.S'
chpst -u qbittorrent:qbittorrent /usr/bin/qbittorrent-nox --profile=/config
