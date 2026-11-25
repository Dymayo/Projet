#!/bin/bash -eu
# 02_nat.sh : routage + NAT pour que les conteneurs sortent sur Internet
# (a lancer sur la VM, en root). Idempotent.

. "$(dirname "$0")/reseau.conf"

# Interface de sortie de la VM = celle de la route par defaut
UPLINK=$(ip route show default | awk '{print $5; exit}')
[ -n "$UPLINK" ] || { echo "pas de route par defaut sur la VM" >&2 ; exit 1 ; }
echo "interface de sortie : $UPLINK"

# La VM doit router entre le bridge et l'uplink
sysctl -w net.ipv4.ip_forward=1 >/dev/null

# Ajoute une regle iptables seulement si elle n'existe pas deja
regle() { local table="$1" ; shift
    iptables -t "$table" -C "$@" 2>/dev/null || iptables -t "$table" -A "$@"
}

# NAT : IP source privee 10.10.0.x -> IP de la VM
regle nat POSTROUTING -s "$SUBNET" -o "$UPLINK" -j MASQUERADE

# Autoriser la sortie et les reponses
regle filter FORWARD -i "$BRIDGE" -o "$UPLINK" -j ACCEPT
regle filter FORWARD -i "$UPLINK" -o "$BRIDGE" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

iptables -t nat -S POSTROUTING | grep "$SUBNET"
