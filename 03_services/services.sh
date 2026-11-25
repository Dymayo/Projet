#!/bin/bash -u
# services.sh : gerer un service systemd dans un ou plusieurs conteneurs depuis la VM.
# (a lancer sur la VM, en root)
#
#   ./services.sh <action> <service> [conteneur ...|all]
#     action  : start | stop | restart | reload | status | enable | disable | logs | is-active
#     service : nom de l'unit (ssh, postgresql, apache2, ...)
#     defaut  : all = tous les conteneurs de reseau.conf
#
# Exemples :
#   ./services.sh status ssh all
#   ./services.sh stop ssh web nfs
#   ./services.sh logs postgresql annuaire
#
# Tout passe par lxc-attach : rien n'est fait a la main dans les conteneurs.

. "$(dirname "$0")/../02_reseau/reseau.conf"

[ $# -ge 2 ] || { sed -n '3,14p' "$0" >&2 ; exit 1 ; }
action="$1" ; service="$2" ; shift 2
cibles="${*:-all}"
[ "$cibles" = "all" ] && cibles="$HOSTS"

ko=0
for c in $cibles ; do
    if [ "$(lxc-info -n "$c" -sH 2>/dev/null)" != "RUNNING" ] ; then
        echo "## $c : conteneur arrete ou absent" ; ko=$((ko + 1)) ; continue
    fi
    echo "## $c : $action $service"
    case "$action" in
        start|stop|restart|reload|enable|disable)
            lxc-attach -n "$c" -- systemctl "$action" "$service" || ko=$((ko + 1))
            lxc-attach -n "$c" -- systemctl is-active "$service" ;;
        is-active)
            lxc-attach -n "$c" -- systemctl is-active "$service" || ko=$((ko + 1)) ;;
        status)
            lxc-attach -n "$c" -- systemctl --no-pager status "$service" || ko=$((ko + 1)) ;;
        logs)
            lxc-attach -n "$c" -- journalctl --no-pager -u "$service" -n 30 ;;
        *)
            echo "action inconnue : $action" >&2 ; exit 1 ;;
    esac
done
exit "$ko"
