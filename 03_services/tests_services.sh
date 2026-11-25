#!/bin/bash -u
# tests_services.sh : verifie qu'on sait demarrer/arreter des services et que
# l'infra revient apres un redemarrage. (a lancer sur la VM, en root)
# Test choisi : sshd, present dans tous les conteneurs (clones de srv).
# Code retour = nombre de tests KO.

. "$(dirname "$0")/../02_reseau/reseau.conf"

ko=0
test_ok() { local desc="$1" ; shift
    if "$@" >/dev/null 2>&1 ; then echo "  OK  $desc"
    else echo "  KO  $desc" ; ko=$((ko + 1)) ; fi
}
pas() { ! "$@" ; }
c="ssh"          # conteneur de test

echo "### VM : infrared-reseau.service"
test_ok "unit active"            systemctl is-active infrared-reseau
test_ok "unit activee au boot"   systemctl is-enabled infrared-reseau
test_ok "conteneurs en autostart" sh -c "lxc-ls --filter '^$c\$' -f -F AUTOSTART | grep -q 1"

echo "### $c : cycle stop / start de sshd"
test_ok "sshd actif au depart"   lxc-attach -n "$c" -- systemctl is-active ssh
test_ok "port 22 en ecoute"      lxc-attach -n "$c" -- sh -c "ss -ltn | grep -q ':22 '"
lxc-attach -n "$c" -- systemctl stop ssh
test_ok "apres stop : inactif"   pas lxc-attach -n "$c" -- systemctl is-active ssh
test_ok "apres stop : port ferme vu de la VM" pas nc -z -w2 "$c" 22
lxc-attach -n "$c" -- systemctl start ssh
test_ok "apres start : actif"    lxc-attach -n "$c" -- systemctl is-active ssh
test_ok "apres start : port ouvert vu de la VM" nc -z -w2 "$c" 22

echo "### $c : signaux (kill -HUP = recharger la conf sans couper)"
pid_avant=$(lxc-attach -n "$c" -- pgrep -o sshd)
lxc-attach -n "$c" -- kill -HUP "$pid_avant"
sleep 1
test_ok "sshd toujours la apres SIGHUP" lxc-attach -n "$c" -- systemctl is-active ssh

echo "### $c : redemarrage du conteneur"
lxc-stop -n "$c" && lxc-start -n "$c"
for _ in $(seq 30) ; do nc -z -w1 "$c" 22 && break ; sleep 1 ; done
test_ok "sshd revenu tout seul (enabled)" nc -z -w2 "$c" 22

echo "### bilan : $ko test(s) KO"
exit "$ko"
