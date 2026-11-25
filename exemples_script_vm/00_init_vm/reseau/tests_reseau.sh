

. "$(dirname "$0")/reseau.conf"

ko=0
test_ok() { local desc="$1" ; shift
    if "$@" >/dev/null 2>&1 ; then echo "  OK  $desc"
    else echo "  KO  $desc" ; ko=$((ko + 1)) ; fi
}

echo "### VM"
echo "--- bridge (ip -br a show $BRIDGE)"     ; ip -br addr show "$BRIDGE"
echo "--- interfaces sur le bridge"            ; ip -br link show master "$BRIDGE"
echo "--- routes (ip r)"                       ; ip route
echo "--- NAT (iptables -t nat)"               ; iptables -t nat -S POSTROUTING
echo "--- ip_forward = $(sysctl -n net.ipv4.ip_forward)"

serveurs=""
for m in $MACHINES ; do
    [ "${m#*:}" = "dhcp" ] || serveurs="$serveurs ${m%%:*}"
done

for nom in $serveurs ; do
    echo "### $nom"
    lxc-attach -n "$nom" -- ip -br -4 addr show eth0
    lxc-attach -n "$nom" -- ip route
    test_ok "passerelle $GATEWAY"    lxc-attach -n "$nom" -- ping -c1 -W1 "$GATEWAY"
    test_ok "Internet 1.1.1.1 (NAT)" lxc-attach -n "$nom" -- ping -c1 -W2 1.1.1.1
    for autre in $serveurs ; do
        [ "$autre" = "$nom" ] && continue
        test_ok "-> $autre"          lxc-attach -n "$nom" -- ping -c1 -W1 "$autre"
    done
done

echo "### bilan : $ko test(s) KO"
exit "$ko"
