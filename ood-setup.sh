#!/bin/bash

# Install new OOD Portal config
cp -f /vagrant/ood_portal.yml /etc/ood/config/ood_portal.yml
/opt/ood/ood-portal-generator/sbin/update_ood_portal

# Disable SELinux
setenforce 0
sed -i 's/^SELINUX=.*/SELINUX=disabled/g' /etc/sysconfig/selinux
sed -i 's/^SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config

# Add user to system and apache basic auth
groupadd ood
useradd --create-home --gid ood ood
echo -n "ood" | passwd --stdin ood
scl enable httpd24 -- htdbm -bc /opt/rh/httpd24/root/etc/httpd/.htpasswd.dbm ood ood

# Misc
mkdir -p /etc/ood/config/clusters.d
mkdir -p /etc/ood/config/apps/shell