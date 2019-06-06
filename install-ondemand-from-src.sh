#!/bin/bash
set -euo pipefail  # Strict mode
set -x

function add_sudoers_rules() {
  cat >> /etc/sudoers.d/ood << EOF
Defaults:apache !requiretty, !authenticate
apache ALL=(ALL) NOPASSWD: /opt/ood/nginx_stage/sbin/nginx_stage
EOF
    chmod 440 /etc/sudoers.d/ood
    mkdir -p /etc/cron.d
    cat >> /etc/cron.d/ood << EOF
#!/bin/bash
PATH=/sbin:/bin:/usr/sbin:/usr/bin
0 */2 * * * root [ -f /opt/ood/nginx_stage/sbin/nginx_stage ] && /opt/ood/nginx_stage/sbin/nginx_stage nginx_clean 2>&1 | logger -t nginx_clean
EOF
}

function add_ood_service() {
  cat >> /etc/systemd/system/httpd24-httpd.service.d/ood.conf << EOF
[Service]
KillSignal=SIGTERM
KillMode=process
PrivateTmp=false
EOF
  chmod 444 /etc/systemd/system/httpd24-httpd.service.d/ood.conf
}


function update_service_environment() {
  sed -i 's/^HTTPD24_HTTPD_SCLS_ENABLED=.*/HTTPD24_HTTPD_SCLS_ENABLED="httpd24 rh-ruby24"/' \
    /opt/rh/httpd24/service-environment
  /bin/systemctl daemon-reload &>/dev/null || :
}

function ensure_conf_files() {
  touch /opt/rh/httpd24/root/etc/httpd/conf.d/ood-portal.conf
  touch /var/lib/ondemand-nginx/config/apps/sys/activejobs.conf
  touch /var/lib/ondemand-nginx/config/apps/sys/dashboard.conf
  touch /var/lib/ondemand-nginx/config/apps/sys/file-editor.conf
  touch /var/lib/ondemand-nginx/config/apps/sys/files.conf
  touch /var/lib/ondemand-nginx/config/apps/sys/myjobs.conf
  touch /var/lib/ondemand-nginx/config/apps/sys/shell.conf
}

function ensure_dirs() {
  mkdir -p /var/lib/ondemand-nginx/config/apps/dev
  mkdir -p /var/lib/ondemand-nginx/config/apps/sys
  mkdir -p /var/lib/ondemand-nginx/config/apps/usr
  mkdir -p /var/lib/ondemand-nginx/config/puns
  mkdir -p /etc/cron.d
  mkdir -p /etc/sudoers.d
  mkdir -p /etc/systemd/system/httpd24-httpd.service.d
  mkdir -p /var/tmp/ondemand-nginx
  mkdir -p /opt/rh/httpd24/root/etc/httpd/conf.d
  mkdir -p /var/www/ood/apps/sys
  mkdir -p /var/www/ood/apps/usr
  mkdir -p /var/www/ood/discover
  mkdir -p /var/www/ood/public
  mkdir -p /var/www/ood/register
}

function install_system_dependencies() {
  # Install infrastructure
  # yum install -y https://yum.osc.edu/ondemand/latest/ondemand-release-web-latest-1-2.el7.noarch.rpm
  # yum install -y ondemand

  # Need to ensure that the version of mod_passenger installed works with installed Apache
  # - mod_passenger.x86_64 : Apache Module for Phusion Passenger
  # - rh-passenger40-mod_passenger.x86_64 : Apache Module for Phusion Passenger
  # - ruby193-mod_passenger40.x86_64 : Apache Module for Phusion Passenger

  yum install -y \
      httpd24 \
      httpd24-httpd-devel \
      httpd24-mod_ldap \
      httpd24-mod_ssl \
      httpd24-runtime \
      mod_passenger \
      rh-git29 \
      rh-git29-runtime \
      rh-nginx114-nginx \
      rh-nodejs6 \
      rh-nodejs6-runtime \
      rh-ruby24 \
      rh-ruby24-ruby-devel \
      rh-ruby24-rubygem-bundler \
      rh-ruby24-rubygem-rake \
      rh-ruby24-rubygems \
      rh-ruby24-rubygems-devel \
      rh-ruby24-runtime \
      scl-utils \
      scl-utils-build\
      sqlite-devel

  # Will need build-essentials, if they are not already provided
  yum install -y gcc gcc-c++ make

  yum install -y vim htop the_silver_searcher mlocate  # Debugging only
}

function install_ondemand() {
  ensure_dirs
  ensure_conf_files
  download_apps
  download_ood_infrastucture
  install_version_file
  install_config
  build_apps
  add_sudoers_rules
  add_ood_service
}

function install_config() {
  install -D -m 644 /opt/ood/ood-portal-generator/share/ood_portal_example.yml \
        /etc/ood/config/ood_portal.yml
  install -D -m 644 /opt/ood/nginx_stage/share/nginx_stage_example.yml \
        /etc/ood/config/nginx_stage.yml
}

function download_apps() {
# Here everything is spelled out without jq or loops for clarity
(
  cd /var/www/ood/apps/sys
  # Clone the main app repos and immediately check out the 
  scl enable rh-git29 -- git clone https://github.com/OSC/ood-dashboard.git dashboard --branch v1.33.4
  scl enable rh-git29 -- git clone https://github.com/OSC/ood-shell.git shell --branch v1.4.3
  scl enable rh-git29 -- git clone https://github.com/OSC/ood-fileexplorer.git files --branch v1.5.2
  scl enable rh-git29 -- git clone https://github.com/OSC/ood-fileeditor.git file-editor --branch v1.4.3
  scl enable rh-git29 -- git clone https://github.com/OSC/ood-activejobs.git activejobs --branch v1.9.1
  scl enable rh-git29 -- git clone https://github.com/OSC/ood-myjobs.git myjobs --branch v2.14.0
  scl enable rh-git29 -- git clone https://github.com/OSC/bc_desktop.git bc_desktop --branch v0.2.1
)
}

function download_ood_infrastucture() {
(
  cd /opt/
  scl enable rh-git29 -- git clone https://github.com/OSC/ondemand.git ood --branch v1.6.3
)
}

function build_app() {
(
  cd "$1"
  if [[ -f "bin/setup" ]]; then
    RAILS_ENV=production scl enable rh-ruby24 rh-git29 rh-nodejs6 -- ./bin/setup
  fi
)
}

function build_apps() {
(
  cd /var/www/ood/apps/sys
  build_app dashboard
  build_app shell
  build_app files
  build_app file-editor
  build_app activejobs
  build_app myjobs
  build_app bc_desktop
)
}

function install_version_file() {
  echo "1.6.3" > /opt/ood/VERSION
}

function main() {
  echo 'Installing OnDemand 1.6.3 from source'
  install_system_dependencies
  install_ondemand
  update_service_environment

  updatedb  # Debugging only

  echo 'Finished installing OnDemand'
}

main
