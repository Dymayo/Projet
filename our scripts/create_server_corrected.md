cat > ~/create_cloned_servers.sh <<'EOF'
#!/bin/bash -eu
# Clone "srv" into all the project servers (run on the VM, as root)

hosts="annuaire dns dhcp nfs ssh web client1 client2"

lxcpath="/var/lib/lxc/"
orig="srv"

# srv must be stopped to be cloned
lxc-stop -n "$orig" 2>/dev/null || true

# Clone function: destroy the old copy, then make an overlay snapshot of srv
copylxc() { local name="$1"
  lxc-destroy -f -n "$name" 2>/dev/null || true
  rm -fr "$lxcpath$name"
  lxc-copy -n "$orig" -N "$name" -s -B overlay
}

# Create and start each clone
for host in $hosts ; do
  echo "creating $host"
  copylxc "$host"
  lxc-start -n "$host"
done

# Wait until each clone has network
for host in $hosts ; do
  echo "waiting for network on $host"
  until lxc-attach -n "$host" -- ping -c1 -W1 1.1.1.1 >/dev/null 2>&1 ; do
    sleep 1
  done
done

# Write the IPs to /etc/hosts, without duplicates
for host in $hosts ; do
  ip=$(lxc-attach -n "$host" -- ip -4 a | sed -n 's/.*inet \(10\.0\.3\.[0-9]*\).*/\1/p')
  sed -i "/ $host\$/d" /etc/hosts
  echo "$ip $host" >> /etc/hosts
done

lxc-ls -f
EOF
chmod +x ~/create_cloned_servers.sh