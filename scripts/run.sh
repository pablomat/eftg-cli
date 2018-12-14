#!/bin/bash
#set -xv
set -o pipefail
set -o errexit # exit on errors
set -o nounset # exit on use of uninitialized variable
set -o errtrace # inherits trap on ERR in function and subshell

install_dependencies() {
    local counter=0
    for pkg in python3 pip3 git jq wget curl beempy; do
        hash ${pkg} 2>/dev/null || { echo "Package ${pkg} doesn't seem to be installed, installing dependencies..."; counter=1; }
    done
    if [[ x"${counter}" == "x1" ]]; then
        while true; do
            echo "In order to run eftg-cli, the packages python3, python3-pip, git & jq needs to be installed"
            read -r -p "Do you wish to install these packages? (yes/no) " yn
            case $yn in
                [Yy]* ) sudo apt update; sudo apt install -y python3 python3-pip git jq; pip3 install -U beem==0.20.9; break;;
                [Nn]* ) exit;;
                * ) echo "Please answer yes or no.";;
            esac
        done
    fi
}

install_dependencies
PD="${PWD}"
if [[ -d "${PD}/eftg-cli" ]]; then
    if ! cd "${PD}/eftg-cli"; then { echo "Critical error"; exit 1; } fi
    if ! /usr/bin/git checkout -q master; then { echo "Critical error"; exit 1; } fi
    if ! /usr/bin/git pull -q; then { echo "Critical error"; exit 1; } fi
    hash="$(/usr/bin/git rev-list --parents HEAD | /usr/bin/tail -1)"
    if [[ x"${hash}" != "x9c035091ce1249666ec08555a122b96414e679b8" ]]; then { echo "Critical error"; exit 1; } fi
else
	if ! /usr/bin/git clone https://github.com/pablomat/eftg-cli.git; then { echo "Critical error"; exit 1; } fi
fi
if ! cd "${PD}/eftg-cli"; then { echo "Critical error"; exit 1; } fi
./eftg-cli.sh setup

# vim: set filetype=sh ts=4 sw=4 tw=0 wrap et:
