FROM debian:bookworm-slim

WORKDIR /opt

RUN usermod -u 99 nobody

# Make directories
RUN mkdir -p /etc/openvpn /etc/qBittorrent
RUN mkdir -p /downloads /config/qBittorrent

# Install
RUN apt update \
    && apt install -y --no-install-recommends \
    curl \
    ca-certificates \
    dnsutils \
    git \
    inetutils-ping \
    ipcalc \
    iproute2 \
    iptables \
    kmod \
    moreutils \
    net-tools \
    openresolv \
    openvpn \
    procps \
    python3 \
    qbittorrent-nox \
    runit \
    tzdata \
    unzip \
    && apt-get clean \
    && apt --purge autoremove -y \
    && rm -rf \
    /var/lib/apt/lists/* \
    /tmp/* \
    /var/tmp/*

RUN rm -rf /etc/openvpn/*
RUN rm -rf /etc/qBittorrent/*

# Configs
ADD openvpn/ /etc/openvpn/
ADD qBittorrent/ /etc/qBittorrent/

# PIA
RUN curl https://www.privateinternetaccess.com/openvpn/openvpn.zip --output /tmp/configs.zip && unzip /tmp/configs.zip -d /etc/openvpn/configs && rm /tmp/configs.zip

# qBittorrent
RUN useradd -c "qbittorrent user" -U qbittorrent
RUN cd /etc/qBittorrent && git clone --single-branch --branch latest-release https://github.com/WDaan/VueTorrent.git

# Runners
RUN chmod +x /etc/openvpn/*.sh
RUN chmod +x /etc/qBittorrent/*.sh

VOLUME ["/downloads", "/config"]

EXPOSE 8080

CMD ["/bin/bash", "/etc/openvpn/start.sh"]
