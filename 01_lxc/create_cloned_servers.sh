#!/bin/bash -eu
# create_cloned_servers.sh : clone "srv" en tous les serveurs du projet.
# A LANCER SUR LA VM, en root, apres initial_server.sh.
# Repris de exemples_script_vm/01_lxc/create_cloned_servers.md, corrige :
#   - liste des machines lue dans reseau.conf (une seule source de verite)
#   - "ping 1.1.1.1" sans -c1 ne s'arretait jamais -> boucle infinie
#   - "lxc-stop $host || copylxc" ne reclonait pas un conteneur arrete
#   - on ne demarre plus les clones ici : 02_reseau/config_conteneurs.sh les
#     configure (IP fixe sur br-infra) puis les demarre. Plus d'IP 10.0.3.x
#     ecrites dans /etc/hosts.

. "$(dirname "$0")/../02_reseau/reseau.conf"

orig="$TEMPLATE"
[ -d "$LXCPATH/$orig" ] || { echo "modele $orig absent : lancer initial_server.sh" >&2 ; exit 1 ; }

# srv doit etre arrete pour etre clone
lxc-stop -n "$orig" 2>/dev/null || true

for host in $HOSTS ; do
    echo "clonage $orig -> $host"
    lxc-stop -n "$host" 2>/dev/null || true
    lxc-destroy -f -n "$host" 2>/dev/null || true
    rm -rf "${LXCPATH:?}/$host"
    # -s -B overlay : snapshot, seules les differences sont stockees (delta0)
    lxc-copy -n "$orig" -N "$host" -s -B overlay
done

lxc-ls -f
