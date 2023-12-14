FROM ghcr.io/pr0fg/pia-docker-base:latest

WORKDIR /opt

# Install dependencies
RUN apt update \
    && apt install -y --no-install-recommends qbittorrent-nox python3 git runit \
    && apt-get clean \
    && apt --purge autoremove -y \
    && rm -rf \
    /var/lib/apt/lists/* \
    /tmp/* \
    /var/tmp/*

# Configs
RUN rm -rf /etc/qBittorrent/*
ADD qBittorrent/ /etc/qBittorrent/

# Setup qBittorrent + VueTorrent
RUN useradd -c "qbittorrent user" -U qbittorrent
RUN cd /etc/qBittorrent && git clone --single-branch --branch latest-release https://github.com/WDaan/VueTorrent.git

# Make directories
RUN mkdir -p /downloads /config/qBittorrent

# Entrypoint
ADD entrypoint.sh /
RUN chmod +x /entrypoint.sh

# Health check env
ENV HEALTHCHECK_PROCESS_NAME=qbittorrent-nox

VOLUME ["/downloads", "/config"]
EXPOSE 8080
