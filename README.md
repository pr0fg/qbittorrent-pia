# [qBittorrent](https://github.com/qbittorrent/qBittorrent) with Private Internet Access (PIA) Integration

Forked and modified from [DyonR/docker-qbittorrentvpn](https://github.com/DyonR/docker-qbittorrentvpn).

Docker container that runs the latest [qBittorrent](https://github.com/qbittorrent/qBittorrent)-nox client while connecting to Private Internet Access (PIA) via OpenVPN. Includes iptables killswitch, DNS nameserver overrides, and IPv6 blocking to prevent IP leakage when the tunnel goes down. Drops all permissions and supports x86 & ARM.

# Docker Features
* Base: Debian bookworm-slim (**supports ARM**)
* [qBittorrent](https://github.com/qbittorrent/qBittorrent) with modern [VueTorrent](https://github.com/WDaan/VueTorrent) frontend
* Automatically connects to Private Internet Access (PIA) using OpenVPN
* IP tables killswitch to prevent IP leaking when VPN connection fails
* DNS overrides to avoid DNS leakage
* Blocks IPv6 to avoid leakage
* Drops all permissions where possible
* Auto checks VPN health every 15 seconds
* Simplified configuation options

# Variables, Volumes, and Ports
## Environment Variables
| Variable | Required | Function | Example |
|----------|----------|----------|----------|
|`VPN_REGION`| Yes | PIA VPN Region | `VPN_REGION=ca_toronto`||
|`VPN_USERNAME`| Yes | PIA username | `VPN_USERNAME=pXXXXXX`||
|`VPN_PASSWORD`| Yes | PIA password | `VPN_PASSWORD=XXXXXXX`||
|`LAN_NETWORK`| Yes | Local network with CIDR notation | `LAN_NETWORK=192.168.1.0/24`||
|`NAME_SERVERS`| No | Comma delimited name servers |`NAME_SERVERS=1.1.1.1,1.0.0.1`|`1.1.1.1,1.0.0.1`||
|`TZ`| No | Timezone |`TZ=America/Toronto`||

`LAN_NETWORK` is required to ensure packets from qBittorrent can return to their source.

## Volumes
| Volume | Required | Function | Example |
|----------|----------|----------|----------|
| `config` | Yes | qBittorrent config files | `/your/config/path/:/config`|
| `downloads` | Yes | Default downloads path for saving downloads | `/your/downloads/path/:/downloads`|

## Ports
| Port | Proto | Required | Function | Example |
|----------|----------|----------|----------|----------|
| `8080` | TCP | Yes | qBittorrent WebUI | `8080:8080`|

# Access the WebUI
Access https://IPADDRESS:PORT from a browser on the same network (e.g.: https://192.168.1.10:8080).

## Default Credentials
| Credential | Default Value |
|----------|----------|
|`username`| `admin` |
|`password`| `adminadmin` |

# How to setup PIA VPN
The container will fail to boot if any of the config options are not set or if `VPN_REGION` does not map to a valid .ovpn file present in the /etc/openvpn/configs directory. If no `VPN_REGION` is set, the container will display all available regions. Simply set `VPN_REGION` to the PIA region you prefer (e.g. `VPN_REGION=ca_toronto`) with no .ovpn extension. Auto injects credentials from `VPN_USERNAME` and `VPN_PASSWORD` into a temporary .ovpn file.

# Issues
If you are having issues with this container please submit an issue on GitHub.  
Please provide logs, Docker version and other information that can simplify reproducing the issue.  
If possible, always use the most up to date version of Docker, you operating system, kernel and the container itself. Support is always a best-effort basis.

### Credits:
[DyonR/docker-qbittorrentvpn](https://github.com/DyonR/docker-qbittorrentvpn)
[MarkusMcNugen/docker-qBittorrentvpn](https://github.com/MarkusMcNugen/docker-qBittorrentvpn)  
[DyonR/jackettvpn](https://github.com/DyonR/jackettvpn)  
