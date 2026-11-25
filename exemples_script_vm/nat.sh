#!/bin/bash
set -x

source_subnet="10.0.3.0/24"

/sbin/iptables -P FORWARD ACCEPT
/sbin/iptables -t nat -F POSTROUTING
/sbin/iptables -t nat -A POSTROUTING -s "$source_subnet" -j MASQUERADE

echo "1">/proc/sys/net/ipv4/ip_forward

