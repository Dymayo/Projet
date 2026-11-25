#!/bin/bash

# Recuperation des parametres
nom=$1
ip=$2

# Verification des parametres
if [ $# -ne 2 ]; then
    echo "Usage : ./configurer.sh nom ip"
    exit 1
fi

# Configuration du reseau
cat > /etc/network/interfaces <<EOF
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
    address $ip/24
    gateway 10.0.3.1
EOF

echo "Configuration reseau du conteneur $nom terminee."