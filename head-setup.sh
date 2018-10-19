#!/bin/bash

# Disable SELinux unless running in docker container or it's disabled
getenforce | grep -q Disabled
if [ ! -f /.dockerenv -a $? -ne 0 ]; then
    setenforce 0
    sed -i 's/^SELINUX=.*/SELINUX=disabled/g' /etc/sysconfig/selinux
    sed -i 's/^SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config
fi

# Add user to system and apache basic auth
groupadd ood
useradd -u 1001 --create-home --gid ood ood
echo -n "ood" | passwd --stdin ood

sed -i 's/^PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config
# systemctl restart sshd
/etc/init.d/sshd restart
