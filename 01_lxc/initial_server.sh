#!/bin/bash -eu
# initial_server.sh : cree le conteneur "srv", modele de tous les clones.
# A LANCER SUR LA VM, en root.
# Repris de exemples_script_vm/01_lxc/initial_server.md, corrige :
#   - "lxc-stop || lxc-destroy" ne detruisait jamais un conteneur deja arrete
#     proprement -> lxc-destroy -f systematique
#   - echo > .bashrc ECRASAIT le .bashrc d'Ubuntu -> >> (ajout)
#   - apt-get update avant l'install (l'image n'a pas de liste de paquets)
#   - netcat -> netcat-openbsd ; man -> man-db ; ajout strace, psmisc, iproute2
#   - attente reseau limitee a 60 s (sinon boucle infinie si lxcbr0 est casse)

. "$(dirname "$0")/../02_reseau/reseau.conf"

name="$TEMPLATE"
distrib="ubuntu"
rel="jammy"
arch="amd64"
lxcpath="$LXCPATH/"
keyserver="hkp://keyserver.ubuntu.com"
pkg="locales procps psmisc iproute2 iputils-ping traceroute tcpdump net-tools lsof strace \
netcat-openbsd vim curl wget dnsutils less ca-certificates iptables \
openssh-server openssh-client nmap man-db"

# Supprimer puis recreer le conteneur
lxc-stop -n "$name" 2>/dev/null || true
lxc-destroy -f -n "$name" 2>/dev/null || true
rm -rf "${lxcpath:?}$name"
lxc-create -n "$name" -t download -- -d "$distrib" -r "$rel" -a "$arch" --keyserver "$keyserver"
localfs="$lxcpath$name/rootfs"

# Config vim + alias shell (on AJOUTE au .bashrc)
printf 'set mouse=\nset background=dark\nsyntax on\n' > "$localfs/root/.vimrc"
echo "alias ll='ls -la'" >> "$localfs/root/.bashrc"

# Demarrer (sur lxcbr0, le reseau par defaut de LXC, pour avoir Internet pendant l'install)
lxc-start -n "$name"

run() { lxc-attach -n "$name" -- "$@" ; }

echo -n "attente reseau $name "
for _ in $(seq 60) ; do
    run ping -c1 -W1 1.1.1.1 >/dev/null 2>&1 && { echo OK ; break ; }
    sleep 1
done
run ping -c1 -W1 1.1.1.1 >/dev/null 2>&1 || { echo "KO : pas de reseau dans $name" >&2 ; exit 1 ; }

# Paquets
run env DEBIAN_FRONTEND=noninteractive apt-get update -q
run env DEBIAN_FRONTEND=noninteractive apt-get install -y -q $pkg

# Locales (apres l'install de "locales", sinon locale.gen n'existe pas)
sed -i '/fr_FR.UTF-8/s/^# *//' "$localfs/etc/locale.gen"
run locale-gen

# Arreter : un conteneur doit etre arrete pour etre clone
lxc-stop -n "$name"
echo "modele $name pret"
