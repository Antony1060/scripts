#!/bin/bash

source <(curl -sL https://raw.githubusercontent.com/Antony1060/.bashpreset/master/.bashcolors.sh)
source <(curl -sL https://raw.githubusercontent.com/Antony1060/.bashpreset/master/.bashpreset.sh)

AP_EXIT_ON_FAIL=1

if ! is_user 0; then
    log_info "Not running under root, aborting!"
    exit 1
fi

MAJOR_VERSION=$(ask "Enter major node version you want to install:")

run_command "curl -sL https://deb.nodesource.com/setup_$MAJOR_VERSION.x | bash -"
run_command "apt install nodejs"
log_info "NodeJS installed"
run_command_normal "node --version"