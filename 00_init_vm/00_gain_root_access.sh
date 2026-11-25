#!/bin/bash -eu
# 00_gain_root_access.sh : autorise la connexion ssh directe en root sur la VM.
# A LANCER SUR TON PC (pas sur la VM). Necessite ~/.ssh/config (voir README).
# Repris de exemples_script_vm/00_init_vm/00_gain_root_access_on_vm.md
#   usage : ./00_gain_root_access.sh [numero_groupe]   (defaut : 1)

debug() { echo "$1" >&2 ; }
grp="${1:-1}"
h="vmBaseAdminSysgrp$grp-0"
debug "host=$h"

debug "Autoriser PermitRootLogin dans sshd_config"
ssh "$h" "sudo sed -i '/^#PermitRootLogin prohibit-password/s/^#//' /etc/ssh/sshd_config"
ssh "$h" "grep '^PermitRootLogin' /etc/ssh/sshd_config"

debug "Recharger sshd"
ssh "$h" "sudo systemctl reload ssh"

debug "Nettoyer authorized_keys de root (retire le 'command=... Please login as ubuntu')"
ssh "$h" "sudo sed -i '/Generated-by-Nova/s/.* ssh-rsa /ssh-rsa /' /root/.ssh/authorized_keys"

debug "Test connexion root"
ssh "root@$h" whoami
