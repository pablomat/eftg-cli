#!/bin/bash
# Usage: ./eftg-cli.sh
#
# Author : Pablo M. Staiano (pablo at xdevit dot com)
#
# This script facilitates the operation of an EFTG node
#
#
# Release v0.2
#
# Changelog :
#               v0.1 : First release (2018/10/15) - Adapted from previous code.
#               v0.2 : Second release (2019/01/11) - Tested with a few witnesses
#               v0.3 : Third release
#
#
#set -xv
set -o pipefail
set -o errexit # exit on errors
set -o nounset # exit on use of uninitialized variable
set -o errtrace # inherits trap on ERR in function and subshell

DIR="$( cd "$( realpath "${BASH_SOURCE[0]}" | xargs dirname )" && pwd )"
DATADIR="$DIR/data"
DOCKER_NAME="eftg-dev"

RED="$(tput setaf 1)"
GREEN="$(tput setaf 2)"
BLUE="$(tput setaf 4)"
RESET="$(tput sgr0)"
: "${DK_TAG="eftg/main:acceptance"}"
#SHM_DIR=/dev/shm
: "${REMOTE_WS="ws://kapteyn.westeurope.cloudapp.azure.com:8086"}"
EFTG_DEF="/usr/local/eftgd-default/bin"
LOGOPT=("--log-opt" "max-size=100m" "--log-opt" "max-file=50")
PORTS="2001,8090"
BADGER_API="https://api.microbadger.com/v1/images/"
RPC_NODE="https://api.blkcc.xyz"
BEEM_VER="0.20.18"

IFS=","
DPORTS=()
for i in $PORTS; do
    if [[ $i != "" ]]; then
        DPORTS+=("-p0.0.0.0:$i:$i")
    fi
done

help() {
    echo "### DEV BRANCH ###"
    echo
    echo "Usage: $0 COMMAND [DATA]"
    echo
    echo "Commands: "
    echo "    install_dependencies - install dependencies (Python3 / PIP3 / JQ)"
    echo "    install_docker - install docker"
    echo "    setup - initializes script with all requirements"
    echo "    install - pulls latest docker image from server (no compiling)"
    #echo "    dlblocks - download the blockchain to speed up your first start"
    #echo "    replay - starts EFTG container (in replay mode)"
    echo "    start - starts EFTG container"
    echo "    stop - stops EFTG container"
    echo "    status - show status of EFTG container"
    echo "    restart - restarts EFTG container"
    echo "    witness - witness node setup"
    echo "    disable_witness - disable a witness"
    echo "    enable_witness - re-enable a witness"
    echo "    publish_feed - publish a new feed base price as a witness"
    echo "    wallet - open cli_wallet in the container"
    echo "    remote_wallet - open cli_wallet in the container connecting to a remote seed"
    echo "    enter - enter a bash session in the container"
    echo "    logs - show all logs inc. docker logs, and EFTG logs"
    echo "    change_password - change the password of an EFTG account"
    echo "    cleanup - remove block_log & shared_memory file"
    echo "    info - query information about the blockchain, a block, an account, a post/comment and/or public keys"
    echo "    optimize - modify kernel parameters for better disk caching"
    echo
    exit
}

optimize() {
    echo    75 | sudo tee /proc/sys/vm/dirty_background_ratio
    echo  1000 | sudo tee /proc/sys/vm/dirty_expire_centisecs
    echo    80 | sudo tee /proc/sys/vm/dirty_ratio
    echo 30000 | sudo tee /proc/sys/vm/dirty_writeback_centisecs
}

spin() {
    spinner="/|\\-/|\\-"
    while :
    do
        for X in 0 1 2 3 4 5 6 7
        do
            echo -n "${spinner:${X}:1}"
            echo -en "\\010"
            sleep 1
        done
    done
}

check_beem() {
    local beem_installed="True"
    if ! pip3 show beem &>/dev/null; then
        beem_installed="False"
    else
        if ! version="$(python3 -c 'from beem.version import version; print(version)' 2>/dev/null)"; then
            beem_installed="False"
        else
            if [[ x"${version}" != "x${BEEM_VER}" ]]; then
                beem_installed="False"
            fi
        fi
    fi
    if [[ x"${beem_installed}" == "xTrue" ]]; then { return 0; } else { return 1; } fi
}

install_beem() {
    if pip3 -q install -U beem=="${BEEM_VER}"; then { return 0; } else { return 1; } fi
}

dlblocks() {
    if [[ ! -d "${DATADIR}/witness/blockchain" ]]; then
        /bin/mkdir -p "${DATADIR}/witness/blockchain"
    fi
    echo "${RED}Removing old block log${RESET}"
    /usr/bin/sudo rm -f "${DATADIR}/witness/blockchain/block_log"
    /usr/bin/sudo rm -f "${DATADIR}/witness/blockchain/block_log.index"
    echo "Downloading EFTG block logs..."
    /usr/bin/wget --quiet "https://seed.blkcc.xyz/block_log" -O "${DATADIR}/witness/blockchain/block_log"
    /usr/bin/wget --quiet "https://seed.blkcc.xyz/MD5SUM" -O "${DATADIR}/witness/blockchain/MD5SUM"
    echo "Verifying MD5 checksum... this may take a while..."
    cd "${DATADIR}/witness/blockchain" ; md5sum -c MD5SUM ; cd -
    echo "${GREEN}FINISHED. Blockchain downloaded and verified${RESET}"
    echo "$ eftg-cli.sh replay"
}

getkeys() {
    read -r -p "Please enter your EFTG account name (without the @): " user
    read -r -p "Please enter your EFTG master password: " pass
    [[ -f "${DIR}/.credentials.json" ]] && { rm "${DIR}/.credentials.json"; }
    "${DIR}/scripts/python/get_user_keys.py" "${user}" "${pass}" > "${DIR}/.credentials.json"
}

getinfo() {
    if [[ -e "${HOME}"/.local/bin/beempy ]]; then
        local_version="$("${HOME}"/.local/bin/beempy --version)"
        if [[ x"${local_version}" == "xbeempy, version ${BEEM_VER}" ]]; then
            if [[ "${#}" -gt 0 ]]; then
                "${HOME}"/.local/bin/beempy -n "${RPC_NODE}" info "${@}"
            else
                "${HOME}"/.local/bin/beempy -n "${RPC_NODE}" info
            fi
        fi
    fi
}

initwit() {
    printf "%s\\n" "A new configuration will be initialized for a witness node"
    read -r -p "Are you sure you want to proceed? (yes/no) " yn
    case ${yn} in [Yy]* ) [[ -f "${DATADIR}/witness/config.ini" ]] && { sudo rm "${DATADIR}/witness/config.ini"; } ;; [Nn]* ) exit ;; * ) echo "Please answer yes or no.";; esac
    getkeys
    if [[ -f "${DATADIR}/witness/config.ini.example" ]]; then { cp "${DATADIR}/witness/config.ini.example" "${DATADIR}/witness/config.ini"; } else { printf "%s\\n" "Error. ${DATADIR}/witness/config.ini.example doesn't exist"; exit 1; } fi
    [[ ! -s "${DIR}/.credentials.json" ]] && { printf "%s\\n" "Error. ${DIR}/.credentials.json doesn't exist or is empty"; exit 1; }
    witness="$(/usr/bin/jq -r '.name' "${DIR}/.credentials.json")"
    owner_privkey="$(/usr/bin/jq -r '.owner[] | select(.type == "private") | .value' "${DIR}/.credentials.json")"
    /bin/sed -i -e s"/^#witness.*/witness = \"${witness}\"/"g -e s"/^#private-key.*/private-key = ${owner_privkey}/"g "${DATADIR}/witness/config.ini"
    printf "%s\\n" "Configuration updated."
    read -r -p "Do you want to keep a copy of your credentials in ${DIR}/.credentials.json ? (yes/no) " yn
    case ${yn} in [Yy]* ) return;; [Nn]* ) rm "${DIR}/.credentials.json" ;; * ) echo "Please answer yes or no.";; esac
}

updatewit() {
    printf "%s\\n" "The properties of the witness account will be updated and broadcasted to the network"
    read -r -p "Are you sure you want to proceed? (yes/no) " yn
    case ${yn} in [Yy]* ) ;; [Nn]* ) exit ;; * ) echo "Please answer yes or no.";; esac
    if [[ ! -s "${DIR}/.credentials.json" ]]; then
        getkeys
        [[ ! -s "${DIR}/.credentials.json" ]] && { printf "%s\\n" "Error. ${DIR}/.credentials.json doesn't exist or is empty"; exit 1; }
    fi
    user="$(/usr/bin/jq -r '.name' "${DIR}/.credentials.json")"
    owner_pubkey="$(/usr/bin/jq -r '.owner[] | select(.type == "public") | .value' "${DIR}/.credentials.json")"
    active_privkey="$(/usr/bin/jq -r '.active[] | select(.type == "private") | .value' "${DIR}/.credentials.json")"
    "${DIR}/scripts/python/update_witness.py" update "${user}" "${active_privkey}" --publicownerkey "${owner_pubkey}" --blocksize 131072 --url "https://condenser.eftg.eu/@${user}" --creationfee "0.100 EFTG" --interestrate 0
}

disablewit() {
    printf "%s\\n" "This operation will disable your witness"
    read -r -p "Are you sure you want to proceed? (yes/no) " yn
    case ${yn} in [Yy]* ) ;; [Nn]* ) exit ;; * ) echo "Please answer yes or no.";; esac
    if [[ ! -s "${DIR}/.credentials.json" ]]; then
        getkeys
        [[ ! -s "${DIR}/.credentials.json" ]] && { printf "%s\\n" "Error. ${DIR}/.credentials.json doesn't exist or is empty"; exit 1; }
    fi
    user="$(/usr/bin/jq -r '.name' "${DIR}/.credentials.json")"
    active_privkey="$(/usr/bin/jq -r '.active[] | select(.type == "private") | .value' "${DIR}/.credentials.json")"
    "${DIR}/scripts/python/update_witness.py" disable "${user}" "${active_privkey}"
}

updatefeed() {
    printf "%s\\n" "This operation will publish a new feed base price for your witness"
    read -r -p "Are you sure you want to proceed? (yes/no) " yn
    case ${yn} in [Yy]* ) ;; [Nn]* ) exit ;; * ) echo "Please answer yes or no.";; esac
    if [[ ! -s "${DIR}/.credentials.json" ]]; then
        getkeys
        [[ ! -s "${DIR}/.credentials.json" ]] && { printf "%s\\n" "Error. ${DIR}/.credentials.json doesn't exist or is empty"; exit 1; }
    fi
    read -r -p "Do you want to publish the standard feed price of 1.000 EUR for 1.000 EFTG? (yes/no) " yn
    case ${yn} in
        [Yy]* ) my_feed="1.000" ;;
        [Nn]* ) read -r -p "What feed price would you like to publish ? (Provide a value with three decimals without the EUR symbol, e.g.: 1.000) : " my_feed ;;
        * ) echo "Please answer yes or no.";;
    esac
    user="$(/usr/bin/jq -r '.name' "${DIR}/.credentials.json")"
    active_privkey="$(/usr/bin/jq -r '.active[] | select(.type == "private") | .value' "${DIR}/.credentials.json")"
    "${DIR}/scripts/python/pricefeed_update.py" "${user}" "${active_privkey}" "${my_feed}"
}

chgpass() {
    printf "%s\\n" "This operation will change the password of your EFTG account"
    read -r -p "Would you like to keep a copy of your new credentials in ${DIR}/.credentials.json ? (yes/no) " yn
    case ${yn} in
        [Yy]* )
            read -r -p "Please enter your EFTG account name (without the @): " user
            "${DIR}/scripts/python/change_password.py" "${user}" --store-credentials "${DIR}/.credentials.json"
            ;;
        [Nn]* )
            read -r -p "Please enter your EFTG account name (without the @): " user
            "${DIR}/scripts/python/change_password.py" "${user}"
            ;;
        * ) echo "Please answer yes or no.";;
    esac
}

cleanup() {
    do_it() {
        echo "Removing block log"
        /usr/bin/sudo /bin/rm -f "${DATADIR}/witness/blockchain/block_log"
        /usr/bin/sudo /bin/rm -f "${DATADIR}/witness/blockchain/block_log.index"
        /usr/bin/sudo /bin/rm -f "${DATADIR}/witness/blockchain/MD5SUM"
        echo "Removing shared_memory"
        /usr/bin/sudo /bin/rm -f "${DATADIR}/witness/blockchain/shared_memory.bin"
        /usr/bin/sudo /bin/rm -f "${DATADIR}/witness/blockchain/shared_memory.meta"
    }
    if seed_running; then
        while true; do
            echo "${RED}In order to safely delete block_log & shared_memory the container needs to be stopped & removed${RESET}"
            read -r -p "Do you wish to proceed? (yes/no) " yn
            case $yn in
                [Yy]* )
                    stop
                    do_it
                    break;;
                [Nn]* ) exit;;
                * ) echo "Please answer yes or no.";;
            esac
        done
    else
        if seed_exists; then
            docker rm ${DOCKER_NAME}
            do_it
        else
            do_it
        fi
    fi
    if (( $# == 1 )); then
        if [[ x${1} == "xnuke" ]]; then
            if [[ -f /usr/local/bin/eftg-cli.sh ]]; then { my_path="$(/usr/bin/realpath /usr/local/bin/eftg-cli.sh | /usr/bin/xargs /usr/bin/dirname)"; } else { exit; } fi
            read -r -p "Say the magic words : " my_pass
            sechash="$(/usr/bin/sha512sum <<< "${my_pass}" | /usr/bin/cut -d" " -f1)"
            if [[ x"${sechash}" == "x94e1a949448415100a1bddaeff98c70870a60343a6ce487839e733433205a05dd3f8293a1a595aeb44742dcc5a5b43fc26d1d61b6cd377d4cc90c0345cef8626" ]]; then
                sudo /bin/rm /usr/local/bin/eftg-cli.sh
                sudo /bin/rm /etc/bash_completion.d/eftg-completion.bash
                if [[ -d "${my_path}" ]]; then
                    if ! cd "${my_path}"; then { echo "Cannot cd to ${my_path}"; exit 1; } fi
                    if ! /usr/bin/git checkout -q master; then { echo "Cannot switch to master branch in this GIT repository"; exit 1; } fi
                    if ! /usr/bin/git pull -q; then { echo "Error while doing git pull in ${PD}/eftg-cli"; exit 1; } fi
                    hash="$(/usr/bin/git rev-list --parents HEAD | /usr/bin/tail -1)"
                    if [[ x"${hash}" != "x9c035091ce1249666ec08555a122b96414e679b8" ]]; then { echo "Repository in ${my_path} doesn't match github.com/pablomat/eftg-cli"; exit 1; } fi
                    /bin/rm -rf "${my_path}"
                fi
            fi
        fi
    fi
}

setup() {
    do_it() {
        [[ -f /usr/local/bin/eftg-cli.sh ]] && { sudo rm /usr/local/bin/eftg-cli.sh; }
        [[ -f /etc/bash_completion.d/eftg-completion.bash ]] && { sudo rm /etc/bash_completion.d/eftg-completion.bash; }
        sudo ln -s "${DIR}/eftg-cli.sh" /usr/local/bin/
        sudo ln -s "${DIR}/scripts/eftg-completion.bash" /etc/bash_completion.d/
        echo "${RED}IMPORTANT${RESET}: Please re-login (or close and re-connect SSH) to finish setup."
        echo "After login, you can run eftg-cli.sh directly (if /usr/local/bin is in your \$PATH variable)"
        echo "or using the full path located at /usr/local/bin/eftg-cli.sh"
        echo
    }

    hash docker 2>/dev/null || { echo "${RED}Docker is required for this script to work, proceeding to installation.${RESET}"; install_docker; }

    if [[ -f /usr/local/bin/eftg-cli.sh && -f /etc/bash_completion.d/eftg-completion.bash ]]; then
        printf "\\n%s" "${BLUE}Proceeding with eftg-cli environment setup.${RESET}" "${BLUE}===========================================${RESET}" "" ""
        while true; do
            read -r -p "It looks like this setup was already executed, would you like to re-run it ? (yes/no) " yn
            case $yn in
                [Yy]* ) echo; do_it; break;;
                [Nn]* ) exit;;
                * ) echo "Please answer yes or no.";;
            esac
        done
    else
        printf "\\n%s" "${BLUE}Proceeding with eftg-cli environment setup.${RESET}" "${BLUE}===========================================${RESET}" "" ""
        do_it
    fi
}

install_docker() {
    install_dependencies
    printf "\\n%s" "${BLUE}Proceeding with docker installation.${RESET}" "${BLUE}====================================${RESET}" "" ""
    if [[ -x "$(command -v docker)" ]]; then { printf "%s\\n" "${GREEN}Docker is already installed${RESET}"; return 0; } fi

    spin &
    SPIN_PID=$!
    disown
    trap '/bin/kill -9 ${SPIN_PID}' SIGHUP SIGINT SIGQUIT SIGILL SIGTRAP SIGABRT SIGBUS SIGFPE SIGUSR1 SIGSEGV SIGUSR2 SIGPIPE SIGALRM SIGTERM

    OUTF=$(/bin/mktemp) || { echo "Failed to create temp file"; exit 1; }

    /usr/bin/curl -fsSL https://get.docker.com | CHANNEL=stable sh &>"${OUTF}"

    /bin/kill -9 $SPIN_PID
    trap - SIGHUP SIGINT SIGQUIT SIGILL SIGTRAP SIGABRT SIGBUS SIGFPE SIGUSR1 SIGSEGV SIGUSR2 SIGPIPE SIGALRM SIGTERM

    /bin/grep -Ev "^\\+|^Warning|^WARNING|^If you|^adding your|^Remember that|^.*sudo|^.*containers|^.*docker host.|^.*Refer to|^.*for more" "${OUTF}" | /bin/sed -e :a -e '/^\n*$/{$d;N;};/\n$/ba'

    if ! /bin/rm "${OUTF}"; then { echo "Cannot remove temp file ${OUTF}"; exit 1; } fi

    if [ "${EUID}" -ne 0 ]; then
        my_text="Adding user $(whoami) to docker group."
        COUNTER=1
        my_line="="
        while [[ ${COUNTER} -lt "${#my_text}" ]]; do
            my_line="${my_line}="
            (( COUNTER++ ))
        done
        #my_line="$(printf '=%.0s' $(/usr/bin/seq 1 ${#my_text}))"
        printf "\\n%s" "${BLUE}${my_text}${RESET}" "${BLUE}${my_line}${RESET}" "" ""
        if ! /usr/bin/sudo usermod -aG docker "$(whoami)"; then { echo "Unable to add user $(whoami) into group docker"; exit 1; } fi
        echo "IMPORTANT: In order for docker to function correctly, please re-login (or close and re-connect SSH) if connected remotely or reboot."
        echo "After login, please verify that your user $(whoami) is part of the docker group with the command \"id -a\""
    fi
}

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

    printf "\\n%s" "${BLUE}Checking software dependencies.${RESET}" "${BLUE}===============================${RESET}" "" ""

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
                    sudo apt-get install -y -o Dpkg::Progress-Fancy="1" "${count[@]}" -qq;
                    if ! check_beem; then
                        if ! install_beem; then { printf "%s\\n" "${RED}Unable to install beem, please report this error - $(date)${RESET}"; } fi
                    fi
                    break;;
                [Nn]* ) exit;;
                * ) echo "Please answer yes or no.";;
            esac
        done
        else
        if ! check_beem; then
            if ! install_beem; then { printf "%s\\n" "${RED}Unable to install beem, please report this error - $(date)${RESET}"; } fi
        else
            printf "%s\\n" "${GREEN}All pre-requisites are already installed${RESET}";
        fi
    fi
    set -u
}

installme() {
    if (( $# == 1 )); then
        DK_TAG="${1}"
    fi
    if ! RAW_OUT="$(/usr/bin/curl -s --max-time 10 "${BADGER_API}${DK_TAG%:*}")"; then { printf "%s\\n" "Error quering ${BADGER_API}, please report this issue - $(date)"; printf "%s\\n" "Continuing .."; } fi
    if ! IMG_VER="$(/usr/bin/jq -re '.LatestVersion' <<< "${RAW_OUT}")"; then { printf "%s\\n" "Error retrieving latest version from ${BADGER_API} output, please report this issue - $(date)"; IMG_VER=""; printf "%s\\n" "Continuing .."; } fi
    #if ! [[ -z "${IMG_VER}" ]]; then { echo "${BLUE}NOTE: You are installing image ${DK_TAG} ${IMG_VER} - please make sure this is correct.${RESET}"; } fi
    if ! [[ -z "${IMG_VER}" ]]; then { echo "${BLUE}NOTE: You are installing image ${DK_TAG} - please make sure this is correct.${RESET}"; } fi
    sleep 2
    docker pull "${DK_TAG}"
    echo "Tagging as eftg_img"
    docker tag "${DK_TAG}" eftg_img
    echo "Installation completed. You may now configure or run the server"
}

seed_exists() {
    seedcount=$(docker ps -a -f name="^/${DOCKER_NAME}$" | wc -l)
    if [[ $seedcount -eq 2 ]]; then
        return 0
    else
        return 1
    fi
}

seed_running() {
    seedcount=$(docker ps -f 'status=running' -f name=$DOCKER_NAME | wc -l)
    if [[ $seedcount -eq 2 ]]; then
        return 0
    else
        return 1
    fi
}

replay() {
    if seed_running; then
        echo "${RED}WARNING: Your ($DOCKER_NAME) container is currently running${RESET}"
        read -r -p "Do you want to stop the container and replay the blockchain? (y/n) > " shouldstop
        if [[ "$shouldstop" == "y" ]]; then
                stop
        else
                echo "${GREEN}Did not say 'y'. Quitting.${RESET}"
                return
        fi
    fi
    if [[ ! -s "${DATADIR}/witness/blockchain/block_log" ]]; then { printf "%s\\n" "${RED}ERROR: There's no ledger available to replay.${RESET}" "$ eftg-cli.sh dlblocks"; return 1; } fi
    echo "Running container & replay..."
    docker run -u "$(id -u)" "${DPORTS[@]}" -v "${DATADIR}":/eftg "${LOGOPT[@]}" -d --name "${DOCKER_NAME}" -t eftg_img "${EFTG_DEF}"/steemd -d /eftg/witness --replay-blockchain
    echo "Started."
}

start() {
    echo "${GREEN}Starting container...${RESET}"
    if seed_exists; then
        docker start $DOCKER_NAME
    else
        docker run -u "$(id -u)" "${DPORTS[@]}" -v "${DATADIR}":/eftg "${LOGOPT[@]}" -d --name "${DOCKER_NAME}" -t eftg_img "${EFTG_DEF}"/steemd -d /eftg/witness
    fi
}

stop() {
    echo "${RED}Stopping container...${RESET}"
    docker stop ${DOCKER_NAME}
    echo "${RED}Removing old container...${RESET}"
    docker rm ${DOCKER_NAME}
}

enter() {
    docker exec -it --env COLUMNS="$(tput cols)" --env LINES="$(tput lines)" ${DOCKER_NAME} bash
}

wallet() {
    docker exec -it ${DOCKER_NAME} "${EFTG_DEF}"/cli_wallet -s ws://127.0.0.1:8090 -w /eftg/wallet.json
}

remote_wallet() {
    if (( $# == 1 )); then
	REMOTE_WS=$1
    fi
    docker run -u "$(id -u)" -v "${DATADIR}":/eftg --rm -it eftg_img "${EFTG_DEF}"/cli_wallet -s "$REMOTE_WS" -w /eftg/wallet.json
}

logs() {
    echo "${BLUE}DOCKER LOGS: (press ctrl-c to exit) ${RESET}"
    docker logs -f --tail=30 ${DOCKER_NAME}
}

status() {

    if seed_exists; then
        echo "Container exists?: ${GREEN}YES${RESET}"
    else
        echo "Container exists?: ${RED}NO (!)${RESET}"
        echo "Container doesn't exist, thus it is NOT running. Run '$0 install && $0 start'${RESET}"
        return
    fi

    if seed_running; then
        echo "Container running?: ${GREEN}YES${RESET}"
    else
        echo "Container running?: ${RED}NO (!)${RESET}"
        echo "Container isn't running. Start it with '$0 start' or '$0 replay'${RESET}"
        return
    fi
}

if [[ ! -f "${DATADIR}/witness/config.ini" ]]; then
    echo "config.ini not found. copying example (seed)";
    cp "${DATADIR}/witness/config.ini.example" "${DATADIR}/witness/config.ini"
fi

if [ "$#" -lt 1 ]; then
    help
fi

case $1 in
    install_docker)
        install_docker
        ;;
    install_dependencies)
        install_dependencies
        ;;
    install)
        installme "${@:2}"
        ;;
    witness_setup)
        initwit
        ;;
    enable_witness)
        updatewit
        ;;
    witness)
        initwit
        echo
        updatewit
        ;;
    disable_witness)
        disablewit
        ;;
    publish_feed)
        updatefeed
        ;;
    start)
        start
        ;;
    replay)
        replay
        ;;
    stop)
        stop
        ;;
    setup)
        setup
        ;;
    restart)
        stop
        sleep 5
        start
        ;;
    optimize)
        echo "Applying recommended dirty write settings..."
        optimize
        ;;
    status)
        status
        ;;
    wallet)
        wallet
        ;;
    remote_wallet)
        remote_wallet "${@:2}"
        ;;
    dlblocks)
        dlblocks 
        ;;
    enter)
        enter
        ;;
    logs)
        logs
        ;;
    info)
        getinfo "${@:2}"
        ;;
    change_password)
        chgpass
        ;;
    cleanup)
        cleanup "${@:2}"
        ;;
    *)
        echo "Invalid cmd"
        help
        ;;
esac

# vim: set filetype=sh ts=4 sw=4 tw=0 wrap et:
