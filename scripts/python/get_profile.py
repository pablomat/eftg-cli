#!/usr/bin/env python3
import json, sys
from beem import Steem
from beem.account import Account
from beemgraphenebase.account import PrivateKey, PublicKey 
from argparse import ArgumentParser
from beem.instance import set_shared_steem_instance

stmf = Steem(node=["https://api.blkcc.xyz"])

def checkacc(username):
    try:
        acc = Account(username, steem_instance=stmf)
    except Exception as exception:
        assert type(exception).__name__ == 'AccountDoesNotExistsException'
        assert exception.__class__.__name__ == 'AccountDoesNotExistsException'
        return False
    else:
        return True

parser = ArgumentParser()
parser.add_argument('account', help="Name of the EFTG account", type=str, nargs=1)
parser.add_argument('--all', help="If used, all information regarding the account will be displayed", action='store_true')
args = parser.parse_args()

if checkacc(args.account[0]):

    acc = Account(args.account[0], steem_instance=stmf)

    if args.all:
        print(json.dumps(acc.json(), indent=4))
    else:
        print(json.dumps(acc.profile, indent=4))

else:
    sys.exit("The account provided is not a valid account in the EFTG Blockchain. Wrong account " + args.account[0])

# vim: set filetype=sh ts=4 sw=4 tw=0 wrap et:
