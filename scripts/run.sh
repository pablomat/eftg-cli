#!/bin/bash
#set -xv
set -o pipefail
set -o errexit # exit on errors
set -o nounset # exit on use of uninitialized variable
set -o errtrace # inherits trap on ERR in function and subshell

install_dependencies() {
    local counter=0
    for pkg in python3 pip3 git jq wget curl; do
        hash ${pkg} 2>/dev/null || { echo "Package ${pkg} doesn't seem to be installed, installing dependencies..."; counter=1; }
    done
    if [[ x"${counter}" == "x1" ]]; then
        while true; do
            echo "In order to run eftg-cli, the packages python3, python3-pip, git & jq needs to be installed"
            read -r -p "Do you wish to install these packages? (yes/no) " yn
            case $yn in
                [Yy]* ) sudo apt update; sudo apt install python3 python3-pip git jq; break;;
                [Nn]* ) exit;;
                * ) echo "Please answer yes or no.";;
            esac
        done
    fi
}

install_dependencies
git clone https://github.com/pablomat/eftg-cli.git
cd eftg-cli
./eftg-cli.sh setup

# vim: set filetype=sh ts=4 sw=4 tw=0 wrap et:
