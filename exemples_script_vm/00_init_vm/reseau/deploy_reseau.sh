#!/bin/bash -eu
# deploy_reseau.sh : deploie toute la partie reseau, dans l'ordre (sur la VM, en root)
# Ordre complet du projet :
#   initial_server -> create_cloned_servers -> deploy_reseau.sh

[ "$(id -u)" -eq 0 ] || { echo "a lancer en root" >&2 ; exit 1 ; }
cd "$(dirname "$0")"

./bridge.sh
./nat.sh
./config_conteneurs.sh
./tests_reseau.sh
