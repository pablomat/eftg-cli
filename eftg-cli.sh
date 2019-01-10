#!/bin/bash
# Usage: ./eftg-cli.sh
#
# Author : Pablo M. Staiano (pablo at xdevit dot com)
#
# This script facilitates the usage of EFTG
#
#
# Release v0.1
#
# Changelog :
#               v0.1 : First release (2018/10/15) - Adapted from previous code.
#               v0.2 : Second release
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
DOCKER_NAME="eftg"

RED="$(tput setaf 1)"
GREEN="$(tput setaf 2)"
BLUE="$(tput setaf 4)"
RESET="$(tput sgr0)"
: ${DK_TAG="eftg/main:latest"}
#SHM_DIR=/dev/shm
: ${REMOTE_WS="wss://kapteyn.westeurope.cloudapp.azure.com:8089"}
LOGOPT=("--log-opt" "max-size=100m" "--log-opt" "max-file=50")
PORTS="2001,8090"

IFS=","
DPORTS=()
for i in $PORTS; do
    if [[ $i != "" ]]; then
            DPORTS+=("-p0.0.0.0:$i:$i")
    fi
done

help() {
    echo "Usage: $0 COMMAND [DATA]"
    echo
    echo "Commands: "
    echo "    setup - initializes script with all requirements"
    #echo "    dlblocks - download the blockchain to speed up your first start"
    echo "    install_docker - install docker"
    echo "    install_dependencies - install dependencies (Python3 / PIP3 / JQ)"
    echo "    install - pulls latest docker image from server (no compiling)"
    echo "    start - starts EFTG container"
    echo "    stop - stops EFTG container"
    echo "    status - show status of EFTG container"
    echo "    restart - restarts EFTG container"
    echo "    witness - witness node setup"
    echo "    wallet - open cli_wallet in the container"
    echo "    remote_wallet - open cli_wallet in the container connecting to a remote seed"
    echo "    enter - enter a bash session in the container"
    echo "    logs - show all logs inc. docker logs, and EFTG logs"
    echo "    cleanup - remove block_log & shared_memory file"
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

dlblocks() {
    if [[ ! -d "${DATADIR}/blockchain" ]]; then
        mkdir "${DATADIR}/blockchain"
    fi
    echo "${RED}Removing old block log${RESET}"
    sudo rm -f "${DATADIR}/witness/blockchain/block_log"
    sudo rm -f "${DATADIR}/witness/blockchain/block_log.index"
    echo "Downloading EFTG block logs..."
    wget --quiet "https://seed.blkcc.xyz/block_log" -O "${DATADIR}/witness/blockchain/block_log"
    wget --quiet "https://seed.blkcc.xyz/MD5SUM" -O "${DATADIR}/witness/blockchain/MD5SUM"
    echo "Verifying MD5 checksum... this may take a while..."
    cd "${DATADIR}/witness/blockchain" ; md5sum -c MD5SUM ; cd -
    echo "${GREEN}FINISHED. Blockchain downloaded and verified${RESET}"
    echo "$ ./eftg-cli.sh replay"
}

getkeys() {
    read -r -p "Please enter your EFTG account name (without the @): " user
    read -r -p "Please enter your EFTG master password: " pass
    [[ -f "${DIR}/.credentials.json" ]] && { rm "${DIR}/.credentials.json"; }
    "${DIR}/scripts/python/get_user_keys.py" "${user}" "${pass}" > "${DIR}/.credentials.json" 
}

initwit() {
    printf "%s\n" "A new configuration will be initialized for a witness node"
    read -r -p "Are you sure you want to proceed? (yes/no) " yn
    case ${yn} in [Yy]* ) [[ -f "${DATADIR}/witness/config.ini" ]] && { sudo rm "${DATADIR}/witness/config.ini"; } ;; [Nn]* ) exit ;; * ) echo "Please answer yes or no.";; esac
    getkeys
    if [[ -f "${DATADIR}/witness/config.ini.example" ]]; then { cp "${DATADIR}/witness/config.ini.example" "${DATADIR}/witness/config.ini"; } else { printf "%s\n" "Error. ${DATADIR}/witness/config.ini.example doesn't exist"; exit 1; } fi
    [[ ! -s "${DIR}/.credentials.json" ]] && { printf "%s\n" "Error. ${DIR}/.credentials.json doesn't exist or is empty"; exit 1; }
    witness="$(/usr/bin/jq -r '.name' "${DIR}/.credentials.json")"
    owner_privkey="$(/usr/bin/jq -r '.owner[] | select(.type == "private") | .value' "${DIR}/.credentials.json")"
    /bin/sed -i -e s"/^#witness.*/witness = \"${witness}\"/"g -e s"/^#private-key.*/private-key = ${owner_privkey}/"g "${DATADIR}/witness/config.ini"
    printf "%s\n" "Configuration updated."
    read -r -p "Do you want to keep a copy of your credentials in ${DIR}/.credentials.json ? (yes/no) " yn
    case ${yn} in [Yy]* ) return;; [Nn]* ) rm "${DIR}/.credentials.json" ;; * ) echo "Please answer yes or no.";; esac
}

updatewit() {
    printf "%s\n" "The properties of the witness account will be updated and broadcasted to the network"
    read -r -p "Are you sure you want to proceed? (yes/no) " yn
    case ${yn} in [Yy]* ) ;; [Nn]* ) exit ;; * ) echo "Please answer yes or no.";; esac
    if [[ ! -s "${DIR}/.credentials.json" ]]; then
	    getkeys
	    [[ ! -s "${DIR}/.credentials.json" ]] && { printf "%s\n" "Error. ${DIR}/.credentials.json doesn't exist or is empty"; exit 1; }
    fi
    user="$(/usr/bin/jq -r '.name' "${DIR}/.credentials.json")"
    owner_pubkey="$(/usr/bin/jq -r '.owner[] | select(.type == "public") | .value' "${DIR}/.credentials.json")"
    active_privkey="$(/usr/bin/jq -r '.active[] | select(.type == "private") | .value' "${DIR}/.credentials.json")"
    "${DIR}/scripts/python/update_witness.py" update "${user}" "${active_privkey}" --publicownerkey "${owner_pubkey}" --blocksize 131072 --url "https://eftg.blkcc.xyz/@${user}" --creationfee "0.100 EFTG" --interestrate 0
}

cleanup() {
    do_it() {
        echo "Removing block log"
        sudo rm -f "${DATADIR}/witness/blockchain/block_log"
        sudo rm -f "${DATADIR}/witness/blockchain/block_log.index"
        sudo rm -f "${DATADIR}/witness/blockchain/MD5SUM"
        echo "Removing shared_memory"
        sudo rm -f "${DATADIR}/witness/blockchain/shared_memory.bin"
        sudo rm -f "${DATADIR}/witness/blockchain/shared_memory.meta"
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
}

setup() {
    do_it() {
        [[ -f /usr/local/bin/eftg-cli.sh ]] && { sudo rm /usr/local/bin/eftg-cli.sh; }
        [[ -f /etc/bash_completion.d/eftg-completion.bash ]] && { sudo rm /etc/bash_completion.d/eftg-completion.bash; }
        sudo ln -s "${DIR}/eftg-cli.sh" /usr/local/bin/
        sudo ln -s "${DIR}/scripts/eftg-completion.bash" /etc/bash_completion.d/
        echo
        echo "${RED}IMPORTANT${RESET}: Please re-login (or close and re-connect SSH) to finish setup."
        echo "After login, you can run eftg-cli.sh directly (if /usr/local/bin is in your \$PATH variable)"
        echo "or using the full path located at /usr/local/bin/eftg-cli.sh"
        echo
    }
    hash docker 2>/dev/null || { echo "${RED}Docker is required for this script to work, proceeding to installation.${RESET}"; install_docker; }

    if [[ -f /usr/local/bin/eftg-cli.sh && -f /etc/bash_completion.d/eftg-completion.bash ]]; then
        while true; do
            read -r -p "It looks like this setup was already executed, would you like to re-run it ? (yes/no) " yn
            case $yn in
                [Yy]* ) do_it; break;;
                [Nn]* ) exit;;
                * ) echo "Please answer yes or no.";;
            esac
        done
    else
        do_it
    fi
}

install_docker() {
    install_dependencies
    curl https://get.docker.com | sh
    if [ "${EUID}" -ne 0 ]; then 
        echo "Adding user $(whoami) to docker group"
        sudo usermod -aG docker "$(whoami)"
        echo "IMPORTANT: Please re-login (or close and re-connect SSH) for docker to function correctly"
        echo
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

    if [[ ${#count[@]} -ne 0 ]]; then
        echo "In order to run eftg-cli, the following packages need to be installed : ${count[*]}"
        while true; do
            read -r -p "Do you wish to install these packages? (yes/no) " yn
            case $yn in
                [Yy]* )
                        sudo apt update;
                        sudo apt install "${count[@]}";
                        if ! pip3 show beem &>/dev/null; then { pip3 install -U beem==0.20.9; } fi;
                        break;;
                [Nn]* ) exit;;
                * ) echo "Please answer yes or no.";;
            esac
        done
        else
            if ! pip3 show beem &>/dev/null; then { pip3 install -U beem==0.20.9; } fi
    fi
    set -u
}

installme() {
    if (( $# == 1 )); then
	DK_TAG=$1
    fi
    echo "${BLUE}NOTE: You are installing image ${DK_TAG}. Please make sure this is correct.${RESET}"
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

start() {
    echo "${GREEN}Starting container...${RESET}"
    if seed_exists; then
        docker start $DOCKER_NAME
    else
        docker run ${DPORTS[@]} -v "${DATADIR}":/eftg "${LOGOPT[@]}" -d --name "${DOCKER_NAME}" -t eftg_img /usr/local/eftgd-default/bin/steemd -d /eftg/witness
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
    docker exec -it ${DOCKER_NAME} /usr/local/eftgd-default/bin/cli_wallet -s ws://127.0.0.1:8090 -w /eftg/wallet.json
}

remote_wallet() {
    if (( $# == 1 )); then
	REMOTE_WS=$1
    fi
    docker run -v "${DATADIR}":/eftg --rm -it eftg_img /usr/local/eftgd-default/bin/cli_wallet -s "$REMOTE_WS" -w /eftg/wallet.json
}

logs() {
    echo "${BLUE}DOCKER LOGS: (press ctrl-c to exit) ${RESET}"
    docker logs -f --tail=30 ${DOCKER_NAME}
    #echo $RED"INFO AND DEBUG LOGS: "$RESET
    #tail -n 30 $DATADIR/{info.log,debug.log}
}

#pclogs() {
#    if [[ ! $(command -v jq) ]]; then
#        echo "${RED}jq not found. Attempting to install...${RESET}"
#        sleep 3
#        sudo apt update
#        sudo apt install -y jq
#    fi
#    local LOG_PATH=$(docker inspect $DOCKER_NAME | jq -r .[0].LogPath)
#    local pipe=/tmp/dkpipepc.fifo
#    trap "rm -f $pipe" EXIT
#    if [[ ! -p $pipe ]]; then
#        mkfifo $pipe
#    fi
#    # the sleep is a dirty hack to keep the pipe open
#
#    sleep 10000 < $pipe &
#    tail -n 5000 -f "$LOG_PATH" &> $pipe &
#    while true
#    do
#        if read -r line <$pipe; then
#            # first grep the data for "M free" to avoid
#            # needlessly processing the data
#            L=$(grep --colour=never "M free" <<< "$line")
#            if [[ $? -ne 0 ]]; then
#                continue
#            fi
#            # then, parse the line and print the time + log
#            L=$(jq -r ".time +\" \" + .log" <<< "$L")
#            # then, remove excessive \r's causing multiple line breaks
#            L=$(sed -e "s/\r//" <<< "$L")
#            # now remove the decimal time to make the logs cleaner
#            L=$(sed -e 's/\..*Z//' <<< "$L")
#            # and finally, strip off any duplicate new line characters
#            L=$(tr -s "\n" <<< "$L")
#            printf '%s\r\n' "$L"
#        fi
#    done
#}

#tslogs() {
#    if [[ ! $(command -v jq) ]]; then
#        echo "${RED}jq not found. Attempting to install...${RESET}"
#        sleep 3
#        sudo apt update
#        sudo apt install -y jq
#    fi
#    local LOG_PATH=$(docker inspect $DOCKER_NAME | jq -r .[0].LogPath)
#    local pipe=/tmp/dkpipe.fifo
#    trap "rm -f $pipe" EXIT
#    if [[ ! -p $pipe ]]; then
#        mkfifo $pipe
#    fi
#    # the sleep is a dirty hack to keep the pipe open
#
#    sleep 10000 < $pipe &
#    tail -n 100 -f "$LOG_PATH" &> $pipe &
#    while true
#    do
#        if read -r line <$pipe; then
#            # first, parse the line and print the time + log
#            L=$(jq -r ".time +\" \" + .log" <<<"$line")
#            # then, remove excessive \r's causing multiple line breaks
#            L=$(sed -e "s/\r//" <<< "$L")
#            # now remove the decimal time to make the logs cleaner
#            L=$(sed -e 's/\..*Z//' <<< "$L")
#            # remove the steem ms time because most people don't care
#            L=$(sed -e 's/[0-9]\+ms //' <<< "$L")
#            # and finally, strip off any duplicate new line characters
#            L=$(tr -s "\n" <<< "$L")
#            printf '%s\r\n' "$L"
#        fi
#    done
#}

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

#hash docker 2>/dev/null || { echo "${RED}Docker is required for this script to work, proceeding to installation.${RESET}"; install_docker; exit; }
#hash python3 2>/dev/null || { echo "${RED}Python3 is required for this script to work, proceeding to installation.${RESET}"; install_dependencies; exit; }
#hash pip3 2>/dev/null || { echo "${RED}Python3-pip is required for this script to work, proceeding to installation.${RESET}"; install_dependencies; exit; }
#hash git 2>/dev/null || { echo "${RED}Git is required for this script to work, proceeding to installation.${RESET}"; install_dependencies; exit; }
#hash jq 2>/dev/null || { echo "${RED}jq is required for this script to work, proceeding to installation.${RESET}"; install_dependencies; exit; }
#hash beempy 2>/dev/null || { echo "${RED}Beem is required for this script to work, proceeding to installation.${RESET}"; install_dependencies; exit; }

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
    witness_update)
        updatewit
        ;;
    witness)
	initwit
	echo
	updatewit
	;;
    start)
        start
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
    pclogs)
        pclogs
        ;;
    tslogs)
        tslogs
        ;;
    ver)
        ver
        ;;
    cleanup)
        cleanup
        ;;
    *)
        echo "Invalid cmd"
        help
        ;;
esac

# vim: set filetype=sh ts=4 sw=4 tw=0 wrap et:
