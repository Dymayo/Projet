#!/bin/bash -eu
# This script MUST be run on the VM !
# This creates creates all the servers as clone of "srv"
# (see "initial_server" script for the "srv" container
# used as a template for cloning)

# Hosts
hosts="db ssh nfs1 bdd2 web test"

lxcpath="/var/lib/lxc/"
orig="srv"
rootfsref="${lxcpath}$orig"

# lxc container cloning function
copylxc() { local name="$1"
  if [ -d "$lxcpath$name" ] ; then lxc-destroy -n "$name" 2>/dev/null ; fi
  rm -fr "$lxcpath$name"
  lxc-copy -n "$orig" -N "$name" -s -B overlay -o /tmp/copy.out
}

# Create lxc
for host in $hosts ; do
	echo creating $host
	lxc-stop $host || copylxc $host || true
	lxc-start $host
done

# Wait for network connectivity
for host in $hosts ; do
	network_ok="no"
	echo testing for host $host
	while [ "$network_ok" != "yes" ] ; do
	  network_ok=$(lxc-attach $host -- ping 1.1.1.1 | \
        	grep -q "1 packets transmitted, 1 received" \
               	 && echo yes || ( sleep 1 ; echo "no" ) )
	done
done

# write IP address in /etc/hosts
for host in $hosts ; do
	# get ip
	ip=$(lxc-attach $host ip a |sed -n '/.*inet \(10.0.3.[0-9]*\).*/s//\1/p')
	# declare in /etc/hosts
	echo $ip $host >>/etc/hosts
done
