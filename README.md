# Projet INFRARED — BASR L2 CMI (Unistra), groupe 1

Infrastructure de serveurs en conteneurs LXC sur une VM OpenStack.
Contrainte du sujet : **rien n'est configuré à la main**, tout le déploiement est scripté
et rejouable sur une VM réinitialisée.

## Déploiement complet (une commande)

Depuis ton PC, à la racine du dépôt :

```bash
./deploy.sh 1        # 1 = numéro de groupe -> vmBaseAdminSysgrp1-0
```

## Arborescence

| Dossier | Où ça tourne | Rôle |
|---|---|---|
| `deploy.sh` | PC | enchaîne toutes les étapes |
| `00_init_vm/` | PC (via ssh) | accès root direct, paquets de la VM |
| `01_lxc/` | VM (root) | modèle `srv` + clones |
| `02_reseau/` | VM (root) | bridge, NAT, IP fixes, tests réseau |
| `03_services/` | VM (root) | service systemd du réseau, gestion des services, diagnostic processus |
| `exemples_script_vm/` | — | scripts d'exemple du prof (référence, non modifiés) |

## Plan d'adressage (`02_reseau/reseau.conf`)

Réseau `10.10.0.0/24` sur le bridge `br-infra`, passerelle = VM `10.10.0.1`, domaine `infrared.lan`.

| Conteneur | IP | Service prévu |
|---|---|---|
| annuaire | 10.10.0.10 | PostgreSQL (NSS/PAM) |
| dns | 10.10.0.11 | DNS |
| dhcp | 10.10.0.12 | DHCP (plage .100–.200) |
| nfs | 10.10.0.13 | NFSv3 (home par login) |
| ssh | 10.10.0.14 | SSH |
| web | 10.10.0.15 | web public + partie authentifiée |
| client1, client2 | DHCP | postes banalisés |

```
           Internet
               |
        [ VM grp1-0 ]  uplink (route par défaut) --NAT/MASQUERADE--
               | 10.10.0.1
        ====== br-infra ======================================
         |       |      |      |      |      |       |      |
     annuaire   dns   dhcp    nfs    ssh    web   client1 client2
       .10      .11    .12    .13    .14    .15    (dhcp)  (dhcp)
```

## Planning

| # | Étape | Date | État |
|---|---|---|---|
| 1 | mise en place : clés, groupes, VM, conteneurs, repo git | 30/09 | fait |
| 2 | paquets, accès root direct, base d'automatisation | 30/09 | fait |
| 3 | réseau entre conteneurs, bridge, config des conteneurs, NAT | 14/10 | fait |
| 4 | gestion des processus, strace, arrêter/démarrer des services | 14/10 | fait |
| 5 | utilisateurs, NSS et PAM sur PostgreSQL | 14/10 | à faire |
| 6 | 1ère présentation, point projet | 04/11 | |
| 7 | debug, logs, capture | 18/11 | |
| 8 | web | 13/11 | |
| 9 | NFS | 18/11 | |
| 10 | sécurité, ssh, tunnels | 25/11 | |
| 11 | présentation finale | 02/12 | |

---

## Étape 1 — Mise en place

Accès à la VM par le bastion (fichiers fournis dans `Groupe1/`, **hors du dépôt**) :

```bash
cat Groupe1/config >> ~/.ssh/config
cp Groupe1/private.pem ~/private.pem && chmod 600 ~/private.pem
ssh vmBaseAdminSysgrp1-0          # doit marcher sans mot de passe
```

`*.pem` est dans `.gitignore` : la clé privée ne doit **jamais** être commitée.

## Étape 2 — Paquets et accès root

- `00_init_vm/00_gain_root_access.sh` : active `PermitRootLogin prohibit-password`
  (clé uniquement, pas de mot de passe) et nettoie `/root/.ssh/authorized_keys`.
- `00_init_vm/01_install_packages.sh` : `apt-get update` puis LXC, bridge-utils, outils réseau
  et de diagnostic (`tcpdump`, `strace`, `lsof`, `psmisc`…).

## Étape 3 — Conteneurs et réseau

1. `01_lxc/initial_server.sh` : crée `srv` (Ubuntu jammy) sur `lxcbr0` pour avoir Internet,
   installe les paquets communs, puis l'arrête.
2. `01_lxc/create_cloned_servers.sh` : clones overlay (`lxc-copy -s -B overlay`) : seules
   les différences sont stockées dans `delta0/`.
3. `02_reseau/deploy_reseau.sh` :
   - `bridge.sh` : crée `br-infra` avec `10.10.0.1/24`,
   - `nat.sh` : `ip_forward=1` + `MASQUERADE` vers l'interface de sortie + règles `FORWARD`,
   - `config_conteneurs.sh` : `lxc.net.0.link = br-infra`, netplan en IP fixe écrit dans
     le `delta0` de chaque clone, `/etc/hosts`, `lxc.start.auto = 1`,
   - `tests_reseau.sh` : passerelle, Internet, DNS externe, ping entre serveurs.

## Étape 4 — Processus et services

### Ce qui est automatisé

- **`infrared-reseau.service`** : le bridge et les règles iptables créés avec `ip`/`iptables`
  disparaissent au reboot. Cette unit systemd `oneshot` relance `bridge.sh` et `nat.sh start`
  au boot, **avant `lxc.service`**, donc les conteneurs en autostart retrouvent leur réseau.
  `systemctl stop infrared-reseau` retire le NAT (`nat.sh stop`).
- **`services.sh <action> <service> [conteneurs|all]`** : `systemctl` / `journalctl` dans les
  conteneurs via `lxc-attach`.
- **`diag.sh <conteneur|vm> [processus]`** : arbre des processus, ports en écoute, units en
  échec, erreurs du journal ; avec un nom de processus : `/proc/PID/status`, `lsof -p`, et
  `strace` pendant 5 s.
- **`tests_services.sh`** : cycle stop/start de `sshd` vérifié de l'intérieur
  (`systemctl is-active`, `ss`) et de l'extérieur (`nc -z`), `SIGHUP`, retour après
  redémarrage du conteneur.

### Mémo commandes (cours)

| Besoin | Commande |
|---|---|
| lister les processus | `ps auxww`, `ps -eo pid,ppid,user,stat,args --forest`, `pstree -p` |
| temps réel | `top` / `htop` |
| trouver un PID | `pgrep -a sshd`, `pidof sshd` |
| signaux | `kill -TERM pid` (15, propre), `kill -KILL pid` (9, brutal), `kill -HUP pid` (relire la conf) |
| fichiers / ports ouverts | `lsof -p pid`, `lsof -iTCP:5432 -nP`, `ss -ltnp` |
| qui bloque un démontage | `fuser -cv /mnt` |
| services (systemd) | `systemctl start / stop / restart / reload / status / enable / disable unit` |
| logs | `journalctl -u unit -n 50`, `journalctl -p err -b` |
| appels système | `strace -f -p pid`, `strace -f -e trace=%network,%file commande`, `strace -c commande` (résumé) |

⚠ `sysctl` ≠ `systemctl` : `sysctl` règle des paramètres du noyau (ex. `net.ipv4.ip_forward`).

Exemple de debug avec strace (pourquoi un client n'atteint pas la base) :

```bash
lxc-attach -n ssh -- strace -f -e trace=%network nc -zv annuaire 5432
# connect(... sin_port=htons(5432), sin_addr=inet_addr("10.10.0.10")) = -1 ECONNREFUSED
# -> le réseau marche, mais rien n'écoute : postgres écoute sur 127.0.0.1 (listen_addresses)
```
