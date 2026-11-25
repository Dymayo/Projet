
* script to run on your hosts:

00_init_vm/00_gain_root_access_on_vm : first script to run, to allow root access with ssh
00_init_vm/01_install_packages_on_vm : second script to run, to initialize the VM and install packages needed for lxc

* script to run on the VM:

01_lxc/initial_server : create first lxc container
01_lxc/create_cloned_servers : create other containers, cloning the first container
