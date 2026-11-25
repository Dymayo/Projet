#!/bin/bash -eu
# deploy.sh : deploiement COMPLET de l'infra, de zero, depuis TON PC.
# La VM peut etre reinitialisee a tout moment : ce script refait tout.
#   usage : ./deploy.sh [numero_groupe]      (defaut : 1)
# Prerequis : ~/.ssh/config + ~/private.pem en place (voir README.md, etape 1).

grp="${1:-1}"
vm="vmBaseAdminSysgrp$grp-0"
dest="/root/infrared"
cd "$(dirname "$0")"

echo "===== 0. init VM ($vm)"
./00_init_vm/00_gain_root_access.sh "$grp"
./00_init_vm/01_install_packages.sh "$grp"

echo "===== copie des scripts dans $vm:$dest"
ssh "root@$vm" "rm -rf $dest && mkdir -p $dest"
scp -q -r 01_lxc 02_reseau 03_services "root@$vm:$dest/"
ssh "root@$vm" "find $dest -name '.DS_Store' -delete ; chmod +x $dest/*/*.sh"

echo "===== 1. conteneurs"
ssh "root@$vm" "$dest/01_lxc/initial_server.sh && $dest/01_lxc/create_cloned_servers.sh"

echo "===== 2. reseau"
ssh "root@$vm" "$dest/02_reseau/deploy_reseau.sh"

echo "===== 3. services (bridge/NAT au boot + tests stop/start)"
ssh "root@$vm" "$dest/03_services/install_service_reseau.sh && $dest/03_services/tests_services.sh"

echo "===== deploiement termine"
