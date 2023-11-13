#!/usr/bin/env bash
# Modified from https://github.com/wknapik/vpnfailsafe

set -eEo pipefail

source /tmp/env
rm /tmp/env

set_route_vars() {
    local network_var
    local -a network_vars; read -ra network_vars <<<"${!route_network_*}"
    for network_var in "${network_vars[@]}"; do
        local -i i="${network_var#route_network_}"
        local -a vars=("route_network_$i" "route_netmask_$i" "route_gateway_$i" "route_metric_$i")
        route_networks[i]="${!vars[0]}"
        route_netmasks[i]="${!vars[1]:-255.255.255.255}"
        route_gateways[i]="${!vars[2]:-$route_vpn_gateway}"
        route_metrics[i]="${!vars[3]:-0}"
    done
}

# Configuration.
readonly prog="$(basename "$0")"
readonly private_nets="127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
declare -a remotes cnf_remote_domains cnf_remote_ips route_networks route_netmasks route_gateways route_metrics
read -ra remotes <<<"$(env|grep -oP '^remote_[0-9]+=.*'|sort -n|cut -d= -f2|tr '\n' '\t')"
read -ra cnf_remote_domains <<<"$(printf '%s\n' "${remotes[@]%%*[0-9]}"|sort -u|tr '\n' '\t')"
read -ra cnf_remote_ips <<<"$(printf '%s\n' "${remotes[@]##*[!0-9.]*}"|sort -u|tr '\n' '\t')"
set_route_vars
read -ra numbered_vars <<<"${!foreign_option_*} ${!proto_*} ${!remote_*} ${!remote_port_*} \
                           ${!route_network_*} ${!route_netmask_*} ${!route_gateway_*} ${!route_metric_*}"
readonly numbered_vars "${numbered_vars[@]}" dev ifconfig_local ifconfig_netmask ifconfig_remote \
         route_net_gateway route_vpn_gateway script_type trusted_ip trusted_port untrusted_ip untrusted_port \
         remotes cnf_remote_domains cnf_remote_ips route_networks route_netmasks route_gateways route_metrics
readonly cur_remote_ip="${trusted_ip:-$untrusted_ip}"
readonly cur_port="${trusted_port:-$untrusted_port}"

block_ipv6() {
    ip6tables -F
    ip6tables -X
    for table in nat mangle raw security; do
        for opt in -F -X; do
            ip6tables -t "$table" "$opt"
        done
    done
    for chain in INPUT OUTPUT FORWARD; do
        ip6tables -P "$chain" DROP
    done
}

update_routes() {
    local -a resolved_ips
    read -ra resolved_ips <<<"$(getent -s files hosts "${cnf_remote_domains[@]:-ENOENT}"|cut -d' ' -f1|tr '\n' '\t' || true)"
    local -ar remote_ips=("$cur_remote_ip" "${resolved_ips[@]}" "${cnf_remote_ips[@]}") 
    for remote_ip in "${remote_ips[@]}"; do
        if [[ -n "$remote_ip" && -z "$(ip route show "$remote_ip")" ]]; then
            ip route add "$remote_ip" via "$route_net_gateway"
        fi
    done
    for net in 0.0.0.0/1 128.0.0.0/1; do
        if [[ -z "$(ip route show "$net")" ]]; then
            ip route add "$net" via "$route_vpn_gateway"
        fi
    done
    for i in $(seq 1 "${#route_networks[@]}"); do
        if [[ -z "$(ip route show "${route_networks[i]}/${route_netmasks[i]}")" ]]; then
            ip route add "${route_networks[i]}/${route_netmasks[i]}" \
              via "${route_gateways[i]}" metric "${route_metrics[i]}" dev "$dev"
        fi
    done
}

update_hosts() {
    if remote_entries="$(getent -s dns hosts "${cnf_remote_domains[@]}"|grep -v :)"; then
        local -r beg="# VPNFAILSAFE BEGIN" end="# VPNFAILSAFE END"
        echo -e "$beg\\n$remote_entries\\n$end" >> /etc/hosts
    fi
}

update_firewall() {

    # $@ := "INPUT" | "OUTPUT" | "FORWARD"
    insert_chain() {
        if iptables -C "$*" -j "VPNFAILSAFE_$*" 2>/dev/null; then
            iptables -D "$*" -j "VPNFAILSAFE_$*"
            for opt in F X; do
                iptables -"$opt" "VPNFAILSAFE_$*"
            done
        fi
        iptables -N "VPNFAILSAFE_$*"
        iptables -I "$*" -j "VPNFAILSAFE_$*"
    }

    # $@ := "INPUT" | "OUTPUT"
    accept_remotes() {
        case "$@" in
            INPUT)  local -r icmp_type=reply   io=i sd=s states="";;
            OUTPUT) local -r icmp_type=request io=o sd=d states=NEW,;;
        esac
        local -r public_nic="$(ip route show "$cur_remote_ip"|cut -d' ' -f5)"
        local -ar suf=(-m conntrack --ctstate "$states"RELATED,ESTABLISHED -"$io" "${public_nic:?}" -j ACCEPT)
        icmp_rule() {
            iptables "$1" "$2" -p icmp --icmp-type "echo-$icmp_type" -"$sd" "$3" "${suf[@]/%ACCEPT/RETURN}"
        }
        for ((i=1; i <= ${#remotes[*]}; ++i)); do
            local port="remote_port_$i"
            local proto="proto_$i"
            iptables -A "VPNFAILSAFE_$*" -p "${!proto%-client}" -"$sd" "${remotes[i-1]}" --"$sd"port "${!port}" "${suf[@]}"
            if ! icmp_rule -C "VPNFAILSAFE_$*" "${remotes[i-1]}" 2>/dev/null; then
                icmp_rule -A "VPNFAILSAFE_$*" "${remotes[i-1]}"
            fi
        done
        if ! iptables -S|grep -q "^-A VPNFAILSAFE_$* .*-$sd $cur_remote_ip/32 .*-j ACCEPT$"; then
            for p in tcp udp; do
                iptables -A "VPNFAILSAFE_$*" -p "$p" -"$sd" "$cur_remote_ip" --"$sd"port "${cur_port}" "${suf[@]}"
            done
            icmp_rule -A "VPNFAILSAFE_$*" "$cur_remote_ip"
        fi
    }

    # $@ := "OUTPUT" | "FORWARD"
    reject_dns() {
        for proto in udp tcp; do
            iptables -A "VPNFAILSAFE_$*" -p "$proto" --dport 53 ! -o "$dev" -j REJECT
        done
    }

    # $@ := "INPUT" | "OUTPUT" | "FORWARD"
    pass_private_nets() { 
        case "$@" in
            INPUT) local -r io=i sd=s;;&
            OUTPUT|FORWARD) local -r io=o sd=d;;&
            INPUT) local -r vpn="${ifconfig_remote:-$ifconfig_local}/${ifconfig_netmask:-32}"
               iptables -A "VPNFAILSAFE_$*" -"$sd" "$vpn" -"$io" "$dev" -j RETURN
               for i in $(seq 1 "${#route_networks[@]}"); do
                   iptables -A "VPNFAILSAFE_$*" -"$sd" "${route_networks[i]}/${route_netmasks[i]}" -"$io" "$dev" -j RETURN
               done;;&
            *) iptables -A "VPNFAILSAFE_$*" -"$sd" "$private_nets" ! -"$io" "$dev" -j RETURN;;&
            INPUT) iptables -A "VPNFAILSAFE_$*" -s "$private_nets" -i "$dev" -j DROP;;&
            *) for iface in "$dev" lo+; do
                   iptables -A "VPNFAILSAFE_$*" -"$io" "$iface" -j RETURN
               done;;
        esac
    }

    # $@ := "INPUT" | "OUTPUT" | "FORWARD"
    drop_other() {
        iptables -A "VPNFAILSAFE_$*" -j DROP
    }

    add_app() {
        local -r public_nic="$(ip route show "$cur_remote_ip"|cut -d' ' -f5)"
        iptables -I VPNFAILSAFE_INPUT 1 -s "$LAN_NETWORK" -i "$public_nic" -p tcp --dport 8080 -j ACCEPT
        iptables -I VPNFAILSAFE_OUTPUT 1 -d "$LAN_NETWORK" -o "$public_nic" -p tcp --sport 8080 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
    }

    for chain in INPUT OUTPUT FORWARD; do
        insert_chain "$chain"
        [[ $chain == FORWARD ]] || accept_remotes "$chain"
        [[ $chain == INPUT ]] || reject_dns "$chain"
        pass_private_nets "$chain"
        drop_other "$chain"
    done

    add_app
}

# $@ := line_number exit_code
err_msg() {
    echo "$0:$1: \`$(sed -n "$1,+0{s/^\\s*//;p}" "$0")' returned $2" >&2
}
trap 'err_msg "$LINENO" "$?"' ERR

main() {
    block_ipv6
    update_hosts
    update_routes
    update_firewall
    /etc/openvpn/healthcheck.sh &
    /etc/qBittorrent/start.sh &
}

main