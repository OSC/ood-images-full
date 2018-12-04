# -*- mode: ruby -*-
# vi: set ft=ruby :

# Get the list of edge OOD versions
# @return Array<String>
def get_latest_ood_versions
  `curl -s https://yum.osc.edu/ondemand/latest/web/el7/x86_64/ | grep -Eo 'ondemand-[0-9][^"]+rpm' | sort | uniq`.split("\n")
end

def get_public_major_minor_version
  `curl -s https://yum.osc.edu/ondemand/ | grep -Eo '([1-9]\.[0-9])/' | sed 's|/||g' | sort | uniq | tail -n1`.strip
end

def get_all_valid_versions(latest_vers, public_vers)
  (latest_vers | public_vers).sort
end

def get_public_ood_versions(ood_public_version)
  `curl -s https://yum.osc.edu/ondemand/#{ood_public_version}/web/el7/x86_64/ | grep -Eo 'ondemand-[0-9][^"]+rpm' | sort | uniq`.split("\n")
end

def get_rpm_url(directory, version)
  return nil unless version

  "https://yum.osc.edu/ondemand/#{directory}/web/el7/x86_64/ondemand-#{version}.el7.x86_64.rpm"
end

def get_ood_selected_version
  default = 'https://yum.osc.edu/ondemand/1.3/web/el7/x86_64/ondemand-1.3.7-2.el7.x86_64.rpm'
  env_selected = ENV['OOD_VERSION']

  begin
    current = get_public_major_minor_version
    released = get_public_ood_versions(current)

    default = "https://yum.osc.edu/ondemand/#{current}/web/el7/x86_64/#{released.last}"

    return default if env_selected.nil?

    latest = get_latest_ood_versions
  rescue StandardError => e

    puts "An error occurred while trying to get the configured version of OOD: defaulting to #{default}"
    puts "#{e.message}"
    return default
  end

  case env_selected
  when 'latest'
    selected = "https://yum.osc.edu/ondemand/latest/web/el7/x86_64/#{latest.last}"
  when 'public'
    selected = "https://yum.osc.edu/ondemand/#{current}/web/el7/x86_64/#{released.last}"
  when /[1-9][0-9]*(\.[0-9]+){1,2}(-[0-9]+)?/  # e.g. 1.3.6-1
    selected = get_rpm_url(current, released.find {|rpm| rpm.include?(env_selected)}) || get_rpm_url(current, latest.find {|rpm| rpm.include?(env_selected)})
  end

  if selected.nil?
    puts "Unable to locate RPM for selected OOD_VERSION: #{env_selected}"
    exit(1)
  end

  selected
end

Vagrant.configure(2) do |config|
  config.vm.box = "centos/7"
  config.vm.synced_folder ".", "/vagrant", type: "virtualbox"
  config.vm.synced_folder "./ood-home", "/home/ood", type: "virtualbox", mount_options: ["uid=1001","gid=1001"]

  config.vm.define "ood", primary: true, autostart: true do |ood|
    ood.vm.network "forwarded_port", guest: 80, host: 8080
    ood.vm.network "private_network", ip: "10.0.0.100"
    ood.vm.provision "shell", inline: <<-SHELL
      yum install -y centos-release-scl lsof sudo
      yum install -y "#{get_ood_selected_version}"
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
end

