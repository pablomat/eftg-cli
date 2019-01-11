#/usr/bin/env bash

_eftg_completion() {
    COMPREPLY=($(compgen -W "setup install_docker install_dependencies install start stop status restart witness disable_witness publish_feed wallet remote_wallet enter logs cleanup optimize" "${COMP_WORDS[1]}"))
}

complete -F _eftg_completion eftg-cli.sh
