#!/bin/bash -eu
# bridge.sh : cree le bridge du projet sur la VM et lui donne l'IP passerelle
# (a lancer sur la VM, en root). Idempotent.

. "$(dirname "$0")/reseau.conf"

if ! ip link show "$BRIDGE" >/dev/null 2>&1 ; then
    echo "creation du bridge $BRIDGE"
    ip link add name "$BRIDGE" type bridge
fi

ip addr replace "$GATEWAY/$PREFIX" dev "$BRIDGE"
ip link set "$BRIDGE" up

ip -br addr show "$BRIDGE"
