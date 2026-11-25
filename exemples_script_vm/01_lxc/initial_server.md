#!/bin/bash -eu
# This script MUST be run on the VM!
# Create a server named "srv" as a template for cloning
# This server should contained common packages and configuration
#

name="srv"
distrib="ubuntu"
rel="jammy"
arch="amd64"
lxcpath="/var/lib/lxc/"
keyserver="hkp://keyserver.ubuntu.com"
pkg="procps iputils-ping traceroute tcpdump net-tools lsof netcat vim curl wget dnsutils less ca-certificates iptables openssh-server openssh-client nmap man"
# Remove and create container
if [ -d "$lxcpath$name" ] ; then
	lxc-stop "$name" || lxc-destroy "$name" || true
fi
rm -fr "$lxcpath$name"
lxc-create -t download -n "$name" -- -d "$distrib" -r "$rel" -a "$arch" --keyserver "$keyserver"
localfs="$lxcpath$name/rootfs"

# Fix vim config and shell aliases
echo >$localfs/root/.vimrc '
set mouse=
set background=dark
syntax on'
echo >$localfs/root/.bashrc "alias ll='ls -la'" 


# Start container
lxc-start "$name"

# Wait for network connectivity
network_ok="no"
while [ "$network_ok" != "yes" ] ; do
  network_ok=$(lxc-attach $name -- ping -c1 1.1.1.1 | \
	grep -q "1 packets transmitted, 1 received" \
		&& echo yes || ( sleep 1 ; echo "no" ) )
done

run() { lxc-attach "$name" -- $@ ; }

# Fix locales 
sed -i '/fr_FR.UTF-8/s/^#//' $localfs/etc/locale.gen
run locale-gen

# Install packages
run apt install -y $pkg

# Stop container
lxc-stop "$name"
