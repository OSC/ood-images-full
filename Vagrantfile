# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure(2) do |config|
  config.vm.box = "centos/7"
  config.vm.synced_folder ".", "/vagrant", type: "virtualbox"
  config.vm.synced_folder "./ood-home", "/home/ood", type: "virtualbox", mount_options: ["uid=1001","gid=1001"]

  config.vm.define "ood", primary: true, autostart: true do |ood|
    ood.vm.network "forwarded_port", guest: 80, host: 8080
    ood.vm.network "private_network", ip: "10.0.0.100"
    ood.vm.provision "shell", inline: <<-SHELL
      yum install -y centos-release-scl lsof sudo
      yum install -y https://yum.osc.edu/ondemand/1.3/ondemand-release-web-1.3-1.el7.noarch.rpm
      yum install -y ondemand
    SHELL
    ood.vm.provision "shell", path: "ood-setup.sh"
    ood.vm.provision "shell", inline: "systemctl enable httpd24-httpd"
    ood.vm.provision "shell", inline: "systemctl start httpd24-httpd"
    ood.vm.provision "shell", inline: "hostnamectl set-hostname ood"
    ood.vm.provision "shell", inline: "cp -f /vagrant/hosts /etc/hosts"
    ood.vm.provision "shell", inline: "cp -f /vagrant/example.yml /etc/ood/config/clusters.d/example.yml"
    ood.vm.provision "shell", path: "slurm-setup.sh"
  end
  config.vm.define "head", primary: false, autostart: true do |head|
    head.vm.network "private_network", ip: "10.0.0.101"
    head.vm.provision "shell", path: "head-setup.sh"
    head.vm.provision "shell", inline: "hostnamectl set-hostname head"
    head.vm.provision "shell", inline: "cp -f /vagrant/hosts /etc/hosts"
    head.vm.provision "shell", path: "slurm-setup.sh"
    head.vm.provision "shell", inline: "systemctl enable slurmd"
    head.vm.provision "shell", inline: "systemctl start slurmd"
    head.vm.provision "shell", inline: "systemctl enable slurmctld"
    head.vm.provision "shell", inline: "systemctl start slurmctld"
  end
  config.vm.define "auth", primary: false, autostart: true do |auth|
    auth.vm.network "private_network", ip: "10.0.0.102"
    auth.vm.provision "shell", inline: "hostnamectl set-hostname auth"
    auth.vm.provision "shell", inline: "cp -f /vagrant/hosts /etc/hosts"
    auth.vm.provision "shell", inline: "systemctl enable httpd24-httpd"
    auth.vm.provision "shell", inline: "systemctl start httpd24-httpd"
    auth.vm.provision "shell", path: "keycloak-setup.sh"
    auth.vm.provision "shell", inline: "systemctl daemon-reload"
    auth.vm.provision "shell", inline: "systemctl enable keycloak"
    auth.vm.provision "shell", inline: "systemctl start keycloak"
    auth.vm.provision "shell", path: "oidc-configure.sh"
    auth.vm.provision "shell", inline: "systemctl stop keycloak"
    auth.vm.provision "shell", inline: "systemctl stop httpd24-httpd"
    auth.vm.provision "shell", inline: "systemctl start httpd24-httpd"
    auth.vm.provision "shell", inline: "systemctl start keycloak"
  end
end
