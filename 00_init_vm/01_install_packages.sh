#!/bin/bash -eu
# 01_install_packages.sh : installe sur la VM tout ce qu'il faut pour LXC + diagnostic.
# A LANCER SUR TON PC (pas sur la VM), apres 00_gain_root_access.sh.
# Repris de exemples_script_vm/00_init_vm/01_install_packages_on_vm.md, corrige :
#   - apt-get update avant l'install (sinon "Unable to locate package" sur VM neuve)
#   - netcat -> netcat-openbsd (netcat est un paquet virtuel, apt refuse de choisir)
#   - traceroute en double retire ; ajout strace, psmisc, lsof (partie processus/services)
#   usage : ./01_install_packages.sh [numero_groupe]   (defaut : 1)

grp="${1:-1}"
h="vmBaseAdminSysgrp$grp-0"

pkg="bridge-utils lxc lxc-templates debootstrap gnupg tmux traceroute iputils-ping \
tcpdump netcat-openbsd curl wget dnsutils less ca-certificates nmap \
strace psmisc lsof iptables"

echo "install packages sur $h" >&2
ssh "root@$h" "export DEBIAN_FRONTEND=noninteractive ; apt-get update -q && apt-get install -y -q $pkg"
ssh "root@$h" "lxc-checkconfig | grep -E 'Namespaces|Cgroup v2' ; systemctl is-active lxc-net"
