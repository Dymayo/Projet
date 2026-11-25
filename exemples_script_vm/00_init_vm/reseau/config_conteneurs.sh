

. "$(dirname "$0")/reseau.conf"

# Dossier ou ecrire les fichiers du conteneur.
# Clone overlay : on ecrit dans la couche haute (delta), pas dans srv.
rootfs_of() {
    local p
    p=$(sed -n 's/^lxc.rootfs.path *= *//p' "$LXCPATH/$1/config")
    case "$p" in
        overlay:*|overlayfs:*) echo "${p##*:}" ;;
        dir:*)                 echo "${p#dir:}" ;;
        *)                     echo "$p" ;;
    esac
}

# Lignes /etc/hosts pour tous les serveurs a IP fixe
hosts_lines() {
    local m nom ip
    for m in $MACHINES ; do
        nom=${m%%:*} ; ip=${m#*:}
        [ "$ip" = "dhcp" ] || echo "$ip $nom.$DOMAIN $nom"
    done
}

netplan_static() { cat <<EOF
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: false
      addresses: [$1/$PREFIX]
      routes:
        - to: default
          via: $GATEWAY
      nameservers:
        addresses: [$DNS_IP, $DNS_FALLBACK]
        search: [$DOMAIN]
EOF
}

netplan_dhcp() { cat <<EOF
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: true
EOF
}

for m in $MACHINES ; do
    nom=${m%%:*} ; ip=${m#*:}
    conf="$LXCPATH/$nom/config"
    if [ ! -f "$conf" ] ; then
        echo "!! conteneur $nom absent, ignore" >&2
        continue
    fi
    echo "== $nom ($ip)"

    lxc-stop -n "$nom" 2>/dev/null || true

    # 1. Brancher sur le bridge du projet
    sed -i "s/^lxc.net.0.link *=.*/lxc.net.0.link = $BRIDGE/" "$conf"

    root=$(rootfs_of "$nom")
    mkdir -p "$root/etc/netplan"

    # 2. Config reseau (on remplace le 10-lxc.yaml en DHCP de l'image Ubuntu)
    if [ "$ip" = "dhcp" ] ; then
        netplan_dhcp > "$root/etc/netplan/10-lxc.yaml"
    else
        netplan_static "$ip" > "$root/etc/netplan/10-lxc.yaml"
    fi
    chmod 600 "$root/etc/netplan/10-lxc.yaml"

    # 3. /etc/hosts
    {
        echo "127.0.0.1 localhost"
        echo "127.0.1.1 $nom.$DOMAIN $nom"
        hosts_lines
    } > "$root/etc/hosts"

    lxc-start -n "$nom"
done

# /etc/hosts de la VM : on remplace les anciennes IP 10.0.3.x
for m in $MACHINES ; do
    sed -i "/ ${m%%:*}\$/d; / ${m%%:*}\.$DOMAIN /d" /etc/hosts
done
hosts_lines >> /etc/hosts

# Attendre que chaque serveur joigne la passerelle (30 s max chacun)
for m in $MACHINES ; do
    nom=${m%%:*} ; ip=${m#*:}
    [ "$ip" = "dhcp" ] && continue
    printf "attente reseau %-10s " "$nom"
    for _ in $(seq 30) ; do
        if lxc-attach -n "$nom" -- ping -c1 -W1 "$GATEWAY" >/dev/null 2>&1 ; then
            echo OK ; continue 2
        fi
        sleep 1
    done
    echo "KO" ; exit 1
done

lxc-ls -f
