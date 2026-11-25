#!/bin/bash -eu
# deploy_reseau.sh : deploie toute la partie reseau, dans l'ordre (sur la VM, en root)
# Ordre complet : 01_lxc/initial_server.sh -> 01_lxc/create_cloned_servers.sh -> ici

[ "$(id -u)" -eq 0 ] || { echo "a lancer en root" >&2 ; exit 1 ; }
cd "$(dirname "$0")"

./bridge.sh
./nat.sh
./config_conteneurs.sh
./tests_reseau.sh
