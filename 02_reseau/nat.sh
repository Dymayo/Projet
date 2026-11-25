#!/bin/bash -eu
# nat.sh : routage + NAT pour que les conteneurs sortent sur Internet
# (a lancer sur la VM, en root). Idempotent.
#   ./nat.sh         -> met en place (defaut)
#   ./nat.sh stop    -> retire les regles (utilise par infrared-reseau.service)
# Base : exemples_script_vm/nat.sh, mais sans flusher toute la table nat
# (le flush cassait le NAT de lxcbr0 que LXC a mis en place).

. "$(dirname "$0")/reseau.conf"
action="${1:-start}"

# Interface de sortie de la VM = celle de la route par defaut
UPLINK=$(ip route show default | awk '{print $5; exit}')
[ -n "$UPLINK" ] || { echo "pas de route par defaut sur la VM" >&2 ; exit 1 ; }

# Ajoute une regle seulement si elle n'existe pas deja / la retire si elle existe
ajoute() { local t="$1" ; shift ; iptables -t "$t" -C "$@" 2>/dev/null || iptables -t "$t" -A "$@" ; }
retire() { local t="$1" ; shift ; while iptables -t "$t" -C "$@" 2>/dev/null ; do iptables -t "$t" -D "$@" ; done ; }

case "$action" in
  start)
    echo "interface de sortie : $UPLINK"
    sysctl -w net.ipv4.ip_forward=1 >/dev/null
    op=ajoute ;;
  stop)
    op=retire ;;
  *)
    echo "usage : $0 [start|stop]" >&2 ; exit 1 ;;
esac

# NAT : IP source privee 10.10.0.x -> IP de la VM
$op nat POSTROUTING -s "$SUBNET" -o "$UPLINK" -j MASQUERADE
# Autoriser la sortie et les reponses
$op filter FORWARD -i "$BRIDGE" -o "$UPLINK" -j ACCEPT
$op filter FORWARD -i "$UPLINK" -o "$BRIDGE" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
# Trafic entre conteneurs du bridge
$op filter FORWARD -i "$BRIDGE" -o "$BRIDGE" -j ACCEPT

iptables -t nat -S POSTROUTING | grep -F "$SUBNET" || echo "(aucune regle NAT pour $SUBNET)"
