#/usr/bin/env bash

_eftg_completion() {
    COMPREPLY=($(compgen -W "setup install_docker install_dependencies install dlblocks replay start stop status restart witness disable_witness enable_witness publish_feed wallet remote_wallet rpcnode enter logs change_password cleanup info optimize" "${COMP_WORDS[1]}"))
}

complete -F _eftg_completion eftg-cli.sh
