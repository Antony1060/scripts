#!/bin/bash

source <(curl -sL https://raw.githubusercontent.com/Antony1060/.bashpreset/master/.bashcolors.sh)
source <(curl -sL https://raw.githubusercontent.com/Antony1060/.bashpreset/master/.bashpreset.sh)

AP_EXIT_ON_FAIL=1

if ! is_user 0; then
    log_info "Not running under root, aborting!"
    exit 1
fi

NEW_ADMIN=$(ask "Enter the admin account username:")
AUTO_LOGIN=$(prompt_autoyes "Do you want to enable auto-login")

log_info "Installing OpenVPN..."
run_command "yum -y install https://as-repository.openvpn.net/as-repo-centos7.rpm"
run_command "yum -y install openvpn-as"

log_info "Updating firewall..."
run_command "yum install -y firewalld"
run_command "systemctl enable firewalld"
run_command "systemctl start firewalld"
run_command "firewall-cmd --permanent --add-port=80/tcp"
run_command "firewall-cmd --permanent --add-port=443/tcp"
run_command "firewall-cmd --permanent --add-port=943/tcp"
run_command "firewall-cmd --permanent --add-port=1194/tcp"
run_command "firewall-cmd --reload"

log_info "Waiting 10 seconds for OpenVPN to start..."
run_command "sleep 10"

log_info "Updating DNS..."
run_command '/usr/local/openvpn_as/scripts/sacli --key "vpn.client.routing.reroute_dns" --value "custom" ConfigPu't
run_command '/usr/local/openvpn_as/scripts/sacli --key "vpn.server.dhcp_option.dns.0" --value "1.1.1.1" ConfigPut'
run_command '/usr/local/openvpn_as/scripts/sacli --key "vpn.server.dhcp_option.dns.1" --value "1.0.0.1" ConfigPut'

log_info "Adding '$NEW_ADMIN' user..."
run_command "/usr/local/openvpn_as/scripts/sacli --user $NEW_ADMIN --key type --value user_connect UserPropPut"

log_info "Generating random password(32 chars)..."
PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9_\-*\/\.,:;@!#$\()=?+~<>|\\[]' | fold -w 32 | head -n 1)
run_command "/usr/local/openvpn_as/scripts/sacli --user $NEW_ADMIN --new_pass '$PASSWORD' SetLocalPassword"

log_info "Enabling admin privileges..."
run_command "/usr/local/openvpn_as/scripts/sacli --user $NEW_ADMIN --key prop_superuser --value true UserPropPut"
run_command '/usr/local/openvpn_as/scripts/sacli --user openvpn --key prop_superuser --value false UserPropPut'
run_command '/usr/local/openvpn_as/scripts/sacli --user openvpn --key prop_deny --value true UserPropPut'

if [[ $AUTO_LOGIN == "y" ]]; then
    log_info "Enabling auto-login..."
    run_command "/usr/local/openvpn_as/scripts/sacli --user $NEW_ADMIN --key prop_autologin --value true UserPropPut"
fi

log_info "Generating login profiles..."
run_command "/usr/local/openvpn_as/scripts/sacli --user $NEW_ADMIN GetUserLogin > ~/$NEW_ADMIN.ovpn"
if [[ $AUTO_LOGIN == "y" ]]; then
    run_command "/usr/local/openvpn_as/scripts/sacli --user $NEW_ADMIN GetAutoLogin > ~/${NEW_ADMIN}_autologin.ovpn"
fi
run_command '/usr/local/openvpn_as/scripts/sacli start'

WANT_SSL=$(prompt "Do you want to setup ssl for the web interface")
if [[ $WANT_SSL != "y" ]]
then
    log_info "Installation done. User profiles stored in home directory(~). Generated password for '$NEW_ADMIN' is $PASSWORD"
    exit 1
fi

CERT_DOMAIN=$(ask "Enter the domain:")

run_command '/usr/local/openvpn_as/scripts/sacli stop'

log_info "Installing certbot..."
run_command 'yum install -y epel-release'
run_command 'yum install -y certbot'

log_info "Running certbot... You're gonna have to interact a bit"
run_command_normal "certbot certonly -d $CERT_DOMAIN"

log_info "Updating OpenVPN..."
run_command "/usr/local/openvpn_as/scripts/sacli -k 'cs.ca_bundle' --value_file=/etc/letsencrypt/live/$CERT_DOMAIN/chain.pem ConfigPut"
run_command "/usr/local/openvpn_as/scripts/sacli -k 'cs.cert' --value_file=/etc/letsencrypt/live/$CERT_DOMAIN/cert.pem ConfigPut"
run_command "/usr/local/openvpn_as/scripts/sacli -k 'cs.priv_key' --value_file=/etc/letsencrypt/live/$CERT_DOMAIN/privkey.pem ConfigPut"
run_command "/usr/local/openvpn_as/scripts/sacli start"

log_info "Installation done. User profiles stored in home directory(~). Generated password for '$NEW_ADMIN' is $PASSWORD"