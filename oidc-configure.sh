#!/bin/bash

# Install dependencies for building mod_auth_openidc
yum install httpd24-httpd-devel openssl-devel curl-devel jansson-devel pcre-devel autoconf automake

# Install cjose
cd /opt
sudo curl -o cjose-0.5.1.tar.gz  https://github.com/zmartzone/mod_auth_openidc/releases/download/v2.3.0/cjose-0.5.1.tar.gz
sudo tar xzf cjose-0.5.1.tar.gz
cd cjose-0.5.1
./configure
make
sudo make install

# Install mod_auth_openidc
cd /opt
sudo curl -o mod_auth_openidc-2.3.2.tar.gz https://github.com/zmartzone/mod_auth_openidc/releases/download/v2.3.2/mod_auth_openidc-2.3.2.tar.gz
tar xzf mod_auth_openidc-2.3.2.tar.gz
cd mod_auth_openidc-2.3.2

export MODULES_DIR=/opt/rh/httpd24/root/usr/lib64/httpd/modules
export APXS2_OPTS="-S LIBEXECDIR=${MODULES_DIR}"
export APXS2=/opt/rh/httpd24/root/usr/bin/apxs
export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig
./autogen.sh
./configure --prefix=/opt/rh/httpd24/root/usr --exec-prefix=/opt/rh/httpd24/root/usr --bindir=/opt/rh/httpd24/root/usr/bin --sbindir=/opt/rh/httpd24/root/usr/sbin --sysconfdir=/opt/rh/httpd24/root/etc --datadir=/opt/rh/httpd24/root/usr/share --includedir=/opt/rh/httpd24/root/usr/include --libdir=/opt/rh/httpd24/root/usr/lib64 --libexecdir=/opt/rh/httpd24/root/usr/libexec --localstatedir=/opt/rh/httpd24/root/var --sharedstatedir=/opt/rh/httpd24/root/var/lib --mandir=/opt/rh/httpd24/root/usr/share/man --infodir=/opt/rh/httpd24/root/usr/share/info --without-hiredis
make
sudo make install


# Add openid config file
sudo cat > /opt/rh/httpd24/root/etc/httpd/conf.modules.d/auth_openidc.conf <<EOF
LoadModule auth_openidc_module modules/mod_auth_openidc.so
EOF


sudo cat > /etc/ood/config/ood_portal.yml  <<EOF
# /etc/ood/config/ood_portal.yml
---
# List of Apache authentication directives
# NB: Be sure the appropriate Apache module is installed for this
# Default: (see below, uses basic auth with an htpasswd file)
auth:
  - 'AuthType openid-connect'
  - 'Require valid-user'

# Redirect user to the following URI when accessing logout URI
# Example:
#     logout_redirect: '/oidc?logout=https%3A%2F%2Fwww.example.com'
# Default: '/pun/sys/dashboard/logout' (the Dashboard app provides a simple
# HTML page explaining logout to the user)
logout_redirect: '/oidc?logout=http%3A%2F%2Flocalhost%3A8080'

# Sub-uri used by mod_auth_openidc for authentication
# Example:
#     oidc_uri: '/oidc'
# Default: null (disable OpenID Connect support)
oidc_uri: '/oidc'
EOF

# Then build and install the new Apache configuration file with:
sudo /opt/ood/ood-portal-generator/sbin/update_ood_portal

# Update openid config file
sudo cat > /opt/rh/httpd24/root/etc/httpd/conf.modules.d/auth_openidc.conf <<EOF
OIDCProviderMetadataURL https://localhost:8080/auth/realms/ondemand/.well-known/openid-configuration
OIDCClientID        "localhost"
OIDCClientSecret    "1111111-1111-1111-1111-111111111111"
OIDCRedirectURI      https://localhost:8080/oidc
OIDCCryptoPassphrase "4444444444444444444444444444444444444444"

# Keep sessions alive for 8 hours
OIDCSessionInactivityTimeout 28800
OIDCSessionMaxDuration 28800

# Set REMOTE_USER
OIDCRemoteUserClaim preferred_username

# Don't pass claims to backend servers
OIDCPassClaimsAs environment

# Strip out session cookies before passing to backend
OIDCStripCookies mod_auth_openidc_session mod_auth_openidc_session_chunks mod_auth_openidc_session_0 mod_auth_openidc_session_1
EOF

# TODO:
# OIDCClientID: replace with the client id specified when installing the client in Keycloak admin interface
# OIDCClientSecret: replace 1111111-1111-1111-1111-1111111111111 with client secret specified from the Install tab of the client in Keycloak admin interface
# OIDCCryptoPassphrase: replace 4444444444444444444444444444444444444444 with random generated password. I used openssl rand -hex 20.
# Verify the OIDCProviderMetadataURL uses the correct realm and the port Apache exposes to the world for Keycloak by accessing the URL.


# Change permission on file to be readable by apache and no one else:
sudo chgrp apache /opt/rh/httpd24/root/etc/httpd/conf.d/auth_openidc.conf
sudo chmod 640 /opt/rh/httpd24/root/etc/httpd/conf.d/auth_openidc.conf
