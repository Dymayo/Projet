#!/bin/bash -eu
# install_service_reseau.sh : installe et active infrared-reseau.service sur la VM
# (a lancer sur la VM, en root, depuis /root/infrared). Idempotent.
# Sans ca, apres un reboot de la VM le bridge et le NAT (crees avec ip/iptables,
# non persistants) disparaissent et les conteneurs n'ont plus de reseau.

[ "$(id -u)" -eq 0 ] || { echo "a lancer en root" >&2 ; exit 1 ; }
cd "$(dirname "$0")"

[ "$(realpath ..)" = "/root/infrared" ] || \
    echo "!! attention : l'unit appelle /root/infrared/02_reseau/*.sh, or le projet est dans $(realpath ..)" >&2

install -m 644 infrared-reseau.service /etc/systemd/system/infrared-reseau.service
# ip_forward persistant (sinon remis a 0 au reboot)
echo "net.ipv4.ip_forward = 1" > /etc/sysctl.d/60-infrared.conf

systemctl daemon-reload
systemctl enable infrared-reseau.service
systemctl restart infrared-reseau.service
systemctl --no-pager status infrared-reseau.service
