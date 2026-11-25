#!/bin/bash
# This scripts connects to the vm and allow direct root access with ssh
# This script MUST BE RUN on your host, NOT on the VM

debug() { echo "$1" >&2 ; }
# default group
[ $# != 1 ] && grp=0 || grp="$1"
h=vmBaseAdminSysgrp$grp-0

debug host=$h

debug "Allow root login in sshd configuration"
ssh $h "sudo sed -i '/#PermitRootLogin prohibit-password/s/#//' /etc/ssh/sshd_config"
ssh $h "grep '^PermitRootLogin' /etc/ssh/sshd_config"
debug "Reload ssh"
ssh $h sudo systemctl reload ssh
debug "Fix authorized keys"
ssh $h "sudo sed -i '/Generated-by-Nova/s/.* ssh-rsa /ssh-rsa /' /root/.ssh/authorized_keys"
# no-port-forwarding,no-agent-forwarding,no-X11-forwarding,command="echo 'Please login as the user \"ubuntu\" rather than the user \"root\".';echo;sleep 10;exit 142" ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDKFQRUHUDr0W6oHBF2IslNMFBuhK7eUsmwpeRHzNxGthWHxZ1puWybPEvEyguD6aM7q0i6v30ltuSFC5pXDFlmTcPJdqmAPahY+/6Nd/1NxSy2U/ZgikqWZuEUJluTU0xZnpoRl3rVKlVVZbvHSlzTIZF3sgixe1bDKIXI950vuvbl3qcy9G58dbKTlkR+wQtHjyzmPM5+5pxfhvndW+VKqFHaAicnzbCSOgQSJQDrheMdO+EhV5djLAnv04wolsD4I1IIs5PtMMn1sRS07bEpRhZ2XsZLvlOfcSXCjPqgcnmRW2MMm9UA7GJj1ONhFnoRzpRgJ2yA1aBd9rFi5bpb Generated-by-Nova

# TEST
debug "Test connection as root"
ssh root@$h whoami
