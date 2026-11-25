

. "$(dirname "$0")/reseau.conf"

if ! ip link show "$BRIDGE" >/dev/null 2>&1 ; then
    echo "creation du bridge $BRIDGE"
    ip link add name "$BRIDGE" type bridge
fi


ip addr replace "$GATEWAY/$PREFIX" dev "$BRIDGE"
ip link set "$BRIDGE" up

ip -br addr show "$BRIDGE"
