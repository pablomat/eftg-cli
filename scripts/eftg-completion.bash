#/usr/bin/env bash

_eftg_completion() {
    COMPREPLY=($(compgen -W "dlblocks install_docker install_dependencies install start stop status restart wallet remote_wallet enter logs cleanup optimize" "${COMP_WORDS[1]}"))
}

complete -F _eftg_completion eftg-cli.sh
