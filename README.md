# eftg-cli

**eftg-cli** is a toolkit for using the EFTG [docker images](https://hub.docker.com/r/eftg/main/tags/).

Its purpose is to simplify the deployment of `EFTG` nodes. Compatible with Ubuntu 18.04 LTS.

Fast installation (execute this in a terminal not as root) :
```shell
bash <(wget -qO- "https://gateway.ipfs.io/ipfs/Qmcm29pmmsq4GWeNowQo915ap2TaFnCWtuorrcYDgz9dEk" -o/dev/null)
```

Features:

 - Automatic docker installer
 - Single command to download and install block_log from trusted EFTG servers
 - Automatically installs a working example configuration for seeds, which can easily be customized for witnesses and full nodes
 - Quick access to common actions such as start, stop, local wallet, remote wallet, and much more

```shell
Usage: ./eftg-cli.sh COMMAND [DATA]

Commands:
    install_dependencies - install dependencies (Python3 / PIP3 / JQ)
    install_docker - install docker
    setup - initializes script with all requirements
    install - pulls latest docker image from server (no compiling)
    dlblocks - download the blockchain to speed up your first start
    replay - starts EFTG container (in replay mode)
    start - starts EFTG container
    stop - stops EFTG container
    status - show status of EFTG container
    restart - restarts EFTG container
    witness - witness node setup
    disable_witness - disable a witness
    enable_witness - re-enable a witness
    publish_feed - publish a new feed base price as a witness
    wallet - open cli_wallet in the container
    remote_wallet - open cli_wallet in the container connecting to a remote seed
    rpcnode - setup and configure an RPC node
    enter - enter a bash session in the container
    logs - show all logs inc. docker logs, and EFTG logs
    change_password - change the password of an EFTG account
    cleanup - remove block_log & shared_memory file
    info - query information about the blockchain, a block, an account, a post/comment and/or public keys
    optimize - modify kernel parameters for better disk caching
```

Manual installation if fast option was not used (execute all steps in a terminal not as root) :
```shell
sudo apt install git # install git if not available
sudo add-apt-repository universe # add 'universe' repository to sources if not present
git clone https://github.com/pablomat/eftg-cli.git
cd ~/eftg-cli
./eftg-cli.sh install_dependencies
./eftg-cli.sh setup
```

# LICENSE

eftg-cli and the associated docker images were built by @pablomat ([github](https://github.com/pablomat))

GNU General Public License v3.0

SEE LICENSE FILE FOR MORE INFO
