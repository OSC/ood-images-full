#!/bin/bash
# Add a new realm
cd /opt/keycloak-4.5.0.Final/bin/
./kcadm.sh config credentials --server http://localhost:8080/auth --realm master --user admin  --password KEYCLOAKPASS
./kcadm.sh create realms -s realm=ondemand -s enabled=true -s loginWithEmailAllowed=false -s rememberMe=true

# Configure LDAP
REALMID=$(./kcadm.sh get realms/ondemand --fields id | egrep -v '{|}' | sed 's/.*id".*:\s*"//g; s/"//g')
./kcadm.sh create components -r ondemand -s name=ldap -s providerId=ldap -s providerType=org.keycloak.storage.UserStorageProvider -s parentId=$REALMID  -s 'config.importUsers=["false"]'   -s 'config.priority=["1"]' -s 'config.fullSyncPeriod=["-1"]' -s 'config.changedSyncPeriod=["-1"]' -s 'config.cachePolicy=["DEFAULT"]' -s config.evictionDay=[] -s config.evictionHour=[] -s config.evictionMinute=[] -s config.maxLifespan=[] -s 'config.batchSizeForSync=["1000"]'  -s 'config.editMode=["READ_ONLY"]'  -s 'config.syncRegistrations=["false"]'  -s 'config.vendor=["other"]'  -s 'config.usernameLDAPAttribute=["uid"]' -s 'config.rdnLDAPAttribute=["uid"]' -s 'config.uuidLDAPAttribute=["entryUUID"]'  -s 'config.userObjectClasses=["posixAccount"]' -s 'config.connectionUrl=["ldaps://openldap1.infra.osc.edu:636 ldaps://openldap2.infra.osc.edu:636"]' -s 'config.usersDn=["ou=People,ou=hpc,o=osc"]'  -s 'config.authType=["simple"]'  -s 'config.bindDn=["uid=admin,ou=system"]' -s 'config.bindCredential=["secret"]'  -s 'config.useTruststoreSpi=["never"]'  -s 'config.connectionPooling=["true"]' -s 'config.pagination=["true"]'

# Add OnDemand as a client
CID=$(./kcadm.sh create clients -r ondemand -f /vagrant/ondemand-clients.json -s clientId=localhost  -s enabled=true -s fullScopeAllowed=true -s accessType=confidential -s directAccessGrantsEnabled=false -i)

# Add Custom Theme
cd ../themes
curl -LOk  https://github.com/OSC/keycloak-theme/archive/v0.0.1.zip
unzip v0.0.1.zip
../bin/kcadm.sh update realms/ondemand -s "loginTheme=keycloak-theme-0.0.1"

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
cd /opt/keycloak-4.5.0.Final/bin/
RAND=$(openssl rand -hex 20)
ID=$(./kcadm.sh get clients -r ondemand --fields id -q clientId=localhost | egrep -v '{|}' | sed 's/.*id".*:\s*"//g; s/"//g')
SECRET=$(./kcadm.sh get clients/$ID/client-secret -r ondemand | egrep -v '{|,|}' | sed 's/.*value".*:\s*"//g; s/"//g')
sudo cat > /opt/rh/httpd24/root/etc/httpd/conf.modules.d/auth_openidc.conf <<EOF
OIDCProviderMetadataURL https://localhost:8080/auth/realms/ondemand/.well-known/openid-configuration
OIDCClientID        "localhost"
OIDCClientSecret    "1111111-1111-1111-1111-1111111111111"
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
sudo sed -i -e"s/^OIDCClientSecret.*/OIDCClientSecret    \"$SECRET\"/"  /opt/rh/httpd24/root/etc/httpd/conf.modules.d/auth_openidc.conf
sudo sed -i -e"s/^OIDCCryptoPassphrase.*/OIDCCryptoPassphrase   \"$RAND\"/"  /opt/rh/httpd24/root/etc/httpd/conf.modules.d/auth_openidc.conf

# Change permission on file to be readable by apache and no one else:
sudo chgrp apache /opt/rh/httpd24/root/etc/httpd/conf.d/auth_openidc.conf
sudo chmod 640 /opt/rh/httpd24/root/etc/httpd/conf.d/auth_openidc.conf
