#!/bin/bash
# This script connects to the vm and install all the packages needed to run LXC

debug() { echo "$1" >&2 ; }
# default group
[ $# != 1 ] && grp=0 || grp="$1"
h=vmBaseAdminSysgrp$grp-0

debug "install packages"
ssh root@$h apt install -y bridge-utils lxc lxc-templates debootstrap gnupg tmux traceroute iputils-ping traceroute tcpdump netcat curl wget dnsutils less ca-certificates nmap

