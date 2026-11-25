#!/bin/bash -u
# diag.sh : diagnostic processus / services d'un conteneur (ou de la VM).
# (a lancer sur la VM, en root)
#
#   ./diag.sh <conteneur|vm>                 vue d'ensemble
#   ./diag.sh <conteneur|vm> <processus>     + detail du processus + strace 5 s
#
# Exemples :
#   ./diag.sh ssh sshd
#   ./diag.sh annuaire postgres
#   ./diag.sh vm dnsmasq
#
# Outils du cours (demarche "debugger") : ps, pstree, ss/lsof, systemctl,
# journalctl, strace.

[ $# -ge 1 ] || { sed -n '3,14p' "$0" >&2 ; exit 1 ; }
cible="$1" ; motif="${2:-}"
DUREE_STRACE="${DUREE_STRACE:-5}"

if [ "$cible" = "vm" ] ; then
    run() { "$@" ; }
else
    [ "$(lxc-info -n "$cible" -sH 2>/dev/null)" = "RUNNING" ] || { echo "$cible n'est pas demarre" >&2 ; exit 1 ; }
    run() { lxc-attach -n "$cible" -- "$@" ; }
fi
titre() { echo ; echo "### $*" ; }

titre "arbre des processus (ps -eo ... --forest)"
run ps -eo pid,ppid,user,stat,%cpu,%mem,etime,args --forest

titre "les 5 plus gourmands en CPU"
run ps -eo pid,user,%cpu,%mem,comm --sort=-%cpu | head -6

titre "ports en ecoute (ss -ltnup)"
run ss -ltnup

titre "services en echec (systemctl --failed)"
run systemctl --no-pager --failed

titre "dernieres erreurs du journal (journalctl -p err -b)"
run journalctl --no-pager -p err -b -n 15

[ -n "$motif" ] || exit 0

pid=$(run pgrep -o "$motif")
[ -n "$pid" ] || { titre "aucun processus '$motif'" ; exit 1 ; }

titre "processus '$motif' (pgrep -a)"
run pgrep -a "$motif"

titre "PID $pid : etat (/proc/$pid/status)"
run grep -E '^(Name|State|PPid|Uid|Gid|Threads|VmRSS)' "/proc/$pid/status"

titre "PID $pid : fichiers et sockets ouverts (lsof -p)"
run lsof -nP -p "$pid" | head -30

titre "PID $pid : appels systeme pendant ${DUREE_STRACE}s (strace -f -tt)"
echo "(rien n'apparait si le processus dort : provoque de l'activite, ex. une connexion ssh/nc)"
run timeout "$DUREE_STRACE" strace -f -tt -e trace=%network,%file,%process -p "$pid" 2>&1 | head -60
