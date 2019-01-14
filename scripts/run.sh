#!/bin/bash
#set -xv
set -o pipefail
set -o errexit # exit on errors
set -o nounset # exit on use of uninitialized variable
set -o errtrace # inherits trap on ERR in function and subshell

#RED="$(tput setaf 1)"
GREEN="$(tput setaf 2)"
BLUE="$(tput setaf 4)"
RESET="$(tput sgr0)"

install_dependencies() {
    set +u
    local count=()

    for pkg in build-essential libssl-dev python-dev python3 pip3 git jq wget curl; do
	if [[ "${pkg}" == "build-essential" ]]; then
		if ! /usr/bin/dpkg -s build-essential &>/dev/null; then count=("${count[@]}" 'build-essential'); fi
	fi
	if [[ "${pkg}" == "libssl-dev" ]]; then
		if ! /usr/bin/dpkg -s libssl-dev &>/dev/null; then count=("${count[@]}" 'libssl-dev'); fi
	fi
	if [[ "${pkg}" == "python-dev" ]]; then
		if ! /usr/bin/dpkg -s python-dev &>/dev/null; then count=("${count[@]}" 'python-dev'); fi
	fi
	if [[ "${pkg}" == "python3" ]]; then
		if ! hash "${pkg}" 2>/dev/null; then { count=("${count[@]}" "${pkg}"); } fi
	fi
	if [[ "${pkg}" == "pip3" ]]; then
		if ! hash "${pkg}" 2>/dev/null; then { count=("${count[@]}" 'python3-pip'); } fi
	fi
	if [[ "${pkg}" == "git" ]]; then
		if ! hash "${pkg}" 2>/dev/null; then { count=("${count[@]}" "${pkg}"); } fi
	fi
	if [[ "${pkg}" == "jq" ]]; then
		if ! hash "${pkg}" 2>/dev/null; then { count=("${count[@]}" "${pkg}"); } fi
	fi
	if [[ "${pkg}" == "wget" ]]; then
		if ! hash "${pkg}" 2>/dev/null; then { count=("${count[@]}" "${pkg}"); } fi
	fi
	if [[ "${pkg}" == "curl" ]]; then
		if ! hash "${pkg}" 2>/dev/null; then { count=("${count[@]}" "${pkg}"); } fi
	fi
    done

    printf "\n%s" "${BLUE}Checking software dependencies.${RESET}" "${BLUE}===============================${RESET}" "" ""

    if [[ ${#count[@]} -ne 0 ]]; then
        echo "In order to run eftg-cli, the following packages need to be installed : ${count[*]}"
        while true; do
            read -r -p "Do you wish to install these packages? (yes/no) " yn
            echo
            case $yn in
                [Yy]* )
                    if [[ -e /etc/apt/sources.list ]]; then
                        if ! /bin/grep -q universe /etc/apt/sources.list; then { /usr/bin/sudo /usr/bin/add-apt-repository universe &>/dev/null; } fi
                    else
                        echo "/etc/apt/sources.list doesn't exist"
                        exit 1
                    fi
                    sudo apt -qq update &>/dev/null;
                    sudo apt -qq install -y "${count[@]}";
                    if ! pip3 show beem &>/dev/null; then { pip3 -q install -U beem==0.20.9; } fi;
                    break;;
                [Nn]* ) exit;;
                * ) echo "Please answer yes or no.";;
            esac
        done
	else
	    if ! pip3 show beem &>/dev/null; then { pip3 -q install -U beem==0.20.9; } else { printf "%s\n" "${GREEN}All pre-requisites are already installed${RESET}"; } fi
    fi
    set -u
}

install_dependencies
PD="${PWD}"
if [[ -d "${PD}/eftg-cli" ]]; then
    if ! cd "${PD}/eftg-cli"; then { echo "Cannot cd to ${PD}/eftg-cli"; exit 1; } fi
    if ! /usr/bin/git checkout -q master; then { echo "Cannot switch to master branch in this GIT repository"; exit 1; } fi
    if ! /usr/bin/git pull -q; then { echo "Error while doing git pull in ${PD}/eftg-cli"; exit 1; } fi
    hash="$(/usr/bin/git rev-list --parents HEAD | /usr/bin/tail -1)"
    if [[ x"${hash}" != "x9c035091ce1249666ec08555a122b96414e679b8" ]]; then { echo "Repository in ${PD}/eftg-cli doesn't match github.com/pablomat/eftg-cli"; exit 1; } fi
else
	if ! /usr/bin/git clone --quiet https://github.com/pablomat/eftg-cli.git; then { echo "Critical error"; exit 1; } fi
fi
if ! cd "${PD}/eftg-cli"; then { echo "Cannot cd to ${PD}/eftg-cli"; exit 1; } fi
"${PD}"/eftg-cli/eftg-cli.sh setup

# vim: set filetype=sh ts=4 sw=4 tw=0 wrap et:
